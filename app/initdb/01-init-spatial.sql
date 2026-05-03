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
