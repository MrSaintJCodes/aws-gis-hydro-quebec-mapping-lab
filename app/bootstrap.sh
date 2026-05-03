#!/usr/bin/env bash
set -euo pipefail

exec > >(tee /var/log/opengis-bootstrap.log | logger -t opengis-bootstrap -s 2>/dev/console) 2>&1

APP_DIR="/opt/opengis"

echo "=== OpenGIS bootstrap started ==="
date

if [[ ! -f "$APP_DIR/.env" ]]; then
  echo "ERROR: Missing $APP_DIR/.env"
  exit 1
fi

set -a
source "$APP_DIR/.env"
set +a

ENABLE_PGADMIN="${ENABLE_PGADMIN:-true}"

required_vars=(
  POSTGRES_DB POSTGRES_USER POSTGRES_PASSWORD GEOSERVER_ADMIN_PASSWORD
  PGADMIN_EMAIL PGADMIN_PASSWORD GEOSERVER_IMAGE POSTGIS_IMAGE
)

for var_name in "${required_vars[@]}"; do
  if [[ -z "${!var_name:-}" ]]; then
    echo "ERROR: Required environment variable $var_name is missing or empty in $APP_DIR/.env"
    exit 1
  fi
done

echo "=== Installing packages ==="

rm -f /etc/apt/sources.list.d/docker.sources /etc/apt/sources.list.d/docker.list
rm -f /etc/apt/keyrings/docker.gpg /etc/apt/keyrings/docker.asc

apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl gnupg lsb-release unzip jq awscli cron

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
UBUNTU_CODENAME="$(. /etc/os-release && echo "${UBUNTU_CODENAME:-${VERSION_CODENAME}}")"

cat > /etc/apt/sources.list.d/docker.sources <<EOF_DOCKER_REPO
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${UBUNTU_CODENAME}
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.gpg
EOF_DOCKER_REPO

apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
systemctl enable --now cron

echo "=== Validating app files ==="
required_files=(
  "$APP_DIR/docker-compose.yml"
  "$APP_DIR/Caddyfile"
  "$APP_DIR/www/index.html"
  "$APP_DIR/importers/hydro-quebec/Dockerfile"
  "$APP_DIR/importers/hydro-quebec/import_hydro_outages.py"
)
for file in "${required_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "ERROR: Missing required file: $file"
    exit 1
  fi
done

echo "=== Creating persistent directories ==="
mkdir -p "$APP_DIR/postgis-data" "$APP_DIR/geoserver-data" "$APP_DIR/pgadmin-data" "$APP_DIR/caddy-data" "$APP_DIR/caddy-config" "$APP_DIR/initdb"

if [[ ! -f "$APP_DIR/initdb/01-init-spatial.sql" ]]; then
  cat > "$APP_DIR/initdb/01-init-spatial.sql" <<'SQL'
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;

CREATE TABLE IF NOT EXISTS public.sample_points (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    geom geometry(Point, 4326)
);

INSERT INTO public.sample_points (name, description, geom)
VALUES
('Montreal', 'Sample point in Montreal', ST_SetSRID(ST_MakePoint(-73.5673, 45.5017), 4326)),
('Longueuil', 'Sample point in Longueuil', ST_SetSRID(ST_MakePoint(-73.5107, 45.5312), 4326))
ON CONFLICT DO NOTHING;

CREATE INDEX IF NOT EXISTS sample_points_geom_idx
ON public.sample_points
USING GIST (geom);
SQL
fi

echo "=== Setting permissions ==="
chown root:root "$APP_DIR"
chmod 755 "$APP_DIR"
chown root:root "$APP_DIR/.env"
chmod 600 "$APP_DIR/.env"
chown -R 999:999 "$APP_DIR/postgis-data"
chmod 700 "$APP_DIR/postgis-data"
chmod -R 777 "$APP_DIR/geoserver-data" "$APP_DIR/pgadmin-data" "$APP_DIR/caddy-data" "$APP_DIR/caddy-config"

echo "=== Starting Docker Compose stack ==="
cd "$APP_DIR"
if [[ "${ENABLE_PGADMIN:-true}" == "true" ]]; then
  docker compose --profile admin up -d --remove-orphans
else
  docker compose up -d --remove-orphans
fi

docker compose ps

echo "=== Waiting for PostGIS ==="
postgis_ready="false"
for i in $(seq 1 60); do
  if docker compose exec -T postgis pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" >/dev/null 2>&1; then
    echo "PostGIS is ready"
    postgis_ready="true"
    break
  fi
  echo "Waiting for PostGIS... attempt $i"
  sleep 5
done
if [[ "$postgis_ready" != "true" ]]; then
  echo "ERROR: PostGIS did not become ready in time"
  docker compose logs postgis --tail=100 || true
  exit 1
fi

echo "=== Running initial Hydro-Québec outage import ==="
docker compose --profile importer build hydro_importer
docker compose --profile importer run --rm hydro_importer || echo "WARNING: Initial Hydro-Québec import failed. Continuing deployment."

echo "=== Installing Hydro-Québec outage import cron job ==="
cat > /usr/local/bin/import-hydro-quebec-outages <<'IMPORTER_RUNNER'
#!/usr/bin/env bash
set -euo pipefail
cd /opt/opengis
/usr/bin/docker compose --profile importer run --rm hydro_importer >> /var/log/hydro-quebec-outages-import.log 2>&1
IMPORTER_RUNNER
chmod +x /usr/local/bin/import-hydro-quebec-outages
cat > /etc/cron.d/hydro-quebec-outages <<'CRON'
*/15 * * * * root /usr/local/bin/import-hydro-quebec-outages
CRON
chmod 644 /etc/cron.d/hydro-quebec-outages
systemctl restart cron

echo "=== Auto-publishing Hydro-Québec layer in GeoServer ==="
geoserver_ready="false"
for i in $(seq 1 60); do
  if curl -fsS -u "admin:$GEOSERVER_ADMIN_PASSWORD" "http://localhost/geoserver/rest/about/version.xml" >/dev/null 2>&1; then
    echo "GeoServer REST API is ready"
    geoserver_ready="true"
    break
  fi
  echo "Waiting for GeoServer REST API... attempt $i"
  sleep 10
done

if [[ "$geoserver_ready" == "true" ]]; then
  curl -fsS -o /dev/null -u "admin:$GEOSERVER_ADMIN_PASSWORD" -XPOST -H "Content-Type: application/json" -d '{"workspace":{"name":"hydro"}}' "http://localhost/geoserver/rest/workspaces" || true
  curl -fsS -o /dev/null -u "admin:$GEOSERVER_ADMIN_PASSWORD" -XPOST -H "Content-Type: application/json" -d "{\"dataStore\":{\"name\":\"postgis\",\"connectionParameters\":{\"host\":\"postgis\",\"port\":\"5432\",\"database\":\"$POSTGRES_DB\",\"schema\":\"public\",\"user\":\"$POSTGRES_USER\",\"passwd\":\"$POSTGRES_PASSWORD\",\"dbtype\":\"postgis\"}}}" "http://localhost/geoserver/rest/workspaces/hydro/datastores" || true
  curl -fsS -o /dev/null -u "admin:$GEOSERVER_ADMIN_PASSWORD" -XPOST -H "Content-Type: application/json" -d '{"featureType":{"name":"hydro_quebec_outages_current","nativeName":"hydro_quebec_outages_current","title":"Hydro-Québec Current Outages","srs":"EPSG:4326"}}' "http://localhost/geoserver/rest/workspaces/hydro/datastores/postgis/featuretypes" || true
else
  echo "WARNING: GeoServer REST API did not become ready. Skipping auto-publish."
fi

echo "=== Final health checks ==="
docker compose ps
curl -I http://localhost/ || true
curl -I http://localhost/geoserver || true
curl -I http://localhost/tiles || true
curl -I http://localhost/features || true
curl -s "http://localhost/features/collections/public.hydro_quebec_outages_current/items.json?limit=1000" | jq '.features | length' || true

PUBLIC_HOSTNAME="$(hostname -f)"
TOKEN="$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" || true)"
if [[ -n "$TOKEN" ]]; then
  METADATA_HOSTNAME="$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-hostname || true)"
  if [[ -n "$METADATA_HOSTNAME" ]]; then
    PUBLIC_HOSTNAME="$METADATA_HOSTNAME"
  fi
fi

cat > /etc/motd <<EOF
OpenGIS platform deployed.

App directory:
$APP_DIR

URLs:
http://$PUBLIC_HOSTNAME/
http://$PUBLIC_HOSTNAME/geoserver
http://$PUBLIC_HOSTNAME/tiles
http://$PUBLIC_HOSTNAME/features
http://$PUBLIC_HOSTNAME/pgadmin

Logs:
sudo tail -f /var/log/opengis-bootstrap.log
sudo tail -f /var/log/hydro-quebec-outages-import.log
cd /opt/opengis && sudo docker compose logs -f
EOF

echo "=== OpenGIS bootstrap completed ==="
date
