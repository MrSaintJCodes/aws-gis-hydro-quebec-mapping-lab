#!/usr/bin/env python3
import hashlib
import json
import os
import re
from typing import Any, Optional, Tuple

import psycopg2
from psycopg2.extras import Json
import requests

BIS_VERSION_URL = "https://pannes.hydroquebec.com/pannes/donnees/v3_0/bisversion.json"
BIS_MARKERS_URL = "https://pannes.hydroquebec.com/pannes/donnees/v3_0/bismarkers{version}.json"

POSTGRES_HOST = os.getenv("POSTGRES_HOST", "postgis")
POSTGRES_PORT = int(os.getenv("POSTGRES_PORT", "5432"))
POSTGRES_DB = os.getenv("POSTGRES_DB", "gis")
POSTGRES_USER = os.getenv("POSTGRES_USER", "gisuser")
POSTGRES_PASSWORD = os.getenv("POSTGRES_PASSWORD")

STATUS_MAP = {"A": "Work assigned", "L": "Crew at work", "R": "Crew en route", "": "Unknown"}

CAUSE_MAP = {
    "11": "Equipment failure", "12": "Equipment failure", "13": "Equipment failure", "14": "Equipment failure",
    "15": "Equipment failure", "58": "Equipment failure", "70": "Equipment failure", "72": "Equipment failure",
    "73": "Equipment failure", "74": "Equipment failure", "79": "Equipment failure",
    "21": "Weather conditions", "22": "Weather conditions", "24": "Weather conditions", "25": "Weather conditions", "26": "Weather conditions",
    "31": "Accident or incident", "32": "Accident or incident", "33": "Accident or incident", "34": "Accident or incident",
    "41": "Accident or incident", "42": "Accident or incident", "43": "Accident or incident", "44": "Accident or incident",
    "54": "Accident or incident", "55": "Accident or incident", "56": "Accident or incident", "57": "Accident or incident",
    "51": "Vegetation damage", "52": "Animal damage", "53": "Animal damage",
}


def get_latest_bis_version() -> str:
    response = requests.get(BIS_VERSION_URL, timeout=30)
    response.raise_for_status()
    text = json.dumps(response.json())
    match = re.search(r"\d{14}", text)
    if not match:
        raise RuntimeError(f"Could not find BIS version in response: {text}")
    return match.group(0)


def fetch_outages(version: str) -> list:
    response = requests.get(BIS_MARKERS_URL.format(version=version), timeout=30)
    response.raise_for_status()
    return response.json().get("pannes", [])


def parse_point(value: Any) -> Optional[Tuple[float, float]]:
    if not value:
        return None
    try:
        lon, lat = json.loads(value)
        return float(lon), float(lat)
    except Exception:
        return None


def parse_int(value: Any) -> Optional[int]:
    if value is None or value == "":
        return None
    try:
        return int(value)
    except Exception:
        return None


def severity_label(customers: Optional[int]) -> str:
    customers = customers or 0
    if customers >= 200:
        return "Critical"
    if customers >= 50:
        return "High"
    if customers >= 10:
        return "Medium"
    if customers >= 1:
        return "Low"
    return "Unknown"


def stable_outage_uid(message_id, outage_start, lon, lat, affected_customers, municipality_code) -> str:
    if message_id:
        return f"message:{message_id}"
    material = json.dumps({
        "outage_start": outage_start,
        "lon": round(float(lon), 6) if lon is not None else None,
        "lat": round(float(lat), 6) if lat is not None else None,
        "affected_customers": affected_customers,
        "municipality_code": municipality_code,
    }, sort_keys=True, default=str)
    return "hash:" + hashlib.sha256(material.encode("utf-8")).hexdigest()[:32]


def connect():
    if not POSTGRES_PASSWORD:
        raise RuntimeError("POSTGRES_PASSWORD environment variable is required")
    return psycopg2.connect(host=POSTGRES_HOST, port=POSTGRES_PORT, dbname=POSTGRES_DB, user=POSTGRES_USER, password=POSTGRES_PASSWORD)


def init_schema(conn):
    with conn.cursor() as cur:
        cur.execute("CREATE EXTENSION IF NOT EXISTS postgis;")
        cur.execute("""
            CREATE TABLE IF NOT EXISTS public.hydro_quebec_outages_current (
                outage_uid TEXT PRIMARY KEY,
                source_version TEXT NOT NULL,
                source_index INTEGER NOT NULL,
                affected_customers INTEGER,
                severity_label TEXT,
                outage_start TIMESTAMP,
                estimated_restore TIMESTAMP,
                event_type TEXT,
                status_code TEXT,
                status_label TEXT,
                raw_cause_code TEXT,
                cause_label TEXT,
                municipality_code TEXT,
                message_id TEXT,
                raw_record JSONB NOT NULL,
                geom geometry(Point, 4326),
                imported_at TIMESTAMP NOT NULL DEFAULT now()
            );
        """)
        cur.execute("ALTER TABLE public.hydro_quebec_outages_current ADD COLUMN IF NOT EXISTS outage_uid TEXT;")
        cur.execute("ALTER TABLE public.hydro_quebec_outages_current ADD COLUMN IF NOT EXISTS severity_label TEXT;")
        cur.execute("ALTER TABLE public.hydro_quebec_outages_current DROP COLUMN IF EXISTS id CASCADE;")
        cur.execute("""
            CREATE TABLE IF NOT EXISTS public.hydro_quebec_import_runs (
                id BIGSERIAL PRIMARY KEY,
                source_version TEXT NOT NULL,
                fetched_at TIMESTAMP NOT NULL DEFAULT now(),
                records_found INTEGER NOT NULL,
                records_imported INTEGER NOT NULL DEFAULT 0,
                success BOOLEAN NOT NULL DEFAULT false,
                error_message TEXT
            );
        """)
        cur.execute("""
            CREATE TABLE IF NOT EXISTS public.hydro_quebec_outages_history (
                outage_uid TEXT PRIMARY KEY,
                first_seen TIMESTAMP NOT NULL DEFAULT now(),
                last_seen TIMESTAMP NOT NULL DEFAULT now(),
                cleared_at TIMESTAMP,
                seen_count INTEGER NOT NULL DEFAULT 1,
                latest_source_version TEXT,
                affected_customers INTEGER,
                severity_label TEXT,
                outage_start TIMESTAMP,
                estimated_restore TIMESTAMP,
                event_type TEXT,
                status_code TEXT,
                status_label TEXT,
                raw_cause_code TEXT,
                cause_label TEXT,
                municipality_code TEXT,
                message_id TEXT,
                raw_record JSONB NOT NULL,
                geom geometry(Point, 4326)
            );
        """)
        for table in ("hydro_quebec_outages_current", "hydro_quebec_outages_history"):
            cur.execute(f"CREATE INDEX IF NOT EXISTS {table}_geom_idx ON public.{table} USING GIST (geom);")
            cur.execute(f"CREATE INDEX IF NOT EXISTS {table}_status_idx ON public.{table} (status_label);")
            cur.execute(f"CREATE INDEX IF NOT EXISTS {table}_cause_idx ON public.{table} (cause_label);")
    conn.commit()


def parse_record(version: str, index: int, record: list) -> dict:
    affected_customers = parse_int(record[0] if len(record) > 0 else None)
    outage_start = record[1] if len(record) > 1 else None
    estimated_restore = record[2] if len(record) > 2 else None
    event_type = record[3] if len(record) > 3 else None
    point = parse_point(record[4]) if len(record) > 4 else None
    status_code = record[5] if len(record) > 5 else ""
    raw_cause_code = record[7] if len(record) > 7 else ""
    municipality_code = record[8] if len(record) > 8 else ""
    message_id = record[9] if len(record) > 9 else ""
    lon = point[0] if point else None
    lat = point[1] if point else None
    return {
        "outage_uid": stable_outage_uid(str(message_id or ""), outage_start, lon, lat, affected_customers, municipality_code),
        "source_version": version,
        "source_index": index,
        "affected_customers": affected_customers,
        "severity_label": severity_label(affected_customers),
        "outage_start": outage_start,
        "estimated_restore": estimated_restore,
        "event_type": event_type,
        "status_code": status_code,
        "status_label": STATUS_MAP.get(str(status_code), "Unknown"),
        "raw_cause_code": raw_cause_code,
        "cause_label": CAUSE_MAP.get(str(raw_cause_code), "Unknown"),
        "municipality_code": municipality_code,
        "message_id": message_id,
        "raw_record": record,
        "lon": lon,
        "lat": lat,
    }


def insert_current_outage(cur, row):
    cur.execute("""
        INSERT INTO public.hydro_quebec_outages_current (
            outage_uid, source_version, source_index, affected_customers, severity_label,
            outage_start, estimated_restore, event_type, status_code, status_label,
            raw_cause_code, cause_label, municipality_code, message_id, raw_record, geom, imported_at
        )
        VALUES (
            %s, %s, %s, %s, %s,
            NULLIF(%s, '')::timestamp,
            NULLIF(%s, '')::timestamp,
            %s, %s, %s, %s, %s, %s, %s, %s,
            CASE WHEN %s IS NOT NULL AND %s IS NOT NULL THEN ST_SetSRID(ST_MakePoint(%s, %s), 4326) ELSE NULL END,
            now()
        );
    """, (
        row["outage_uid"], row["source_version"], row["source_index"], row["affected_customers"], row["severity_label"],
        row["outage_start"], row["estimated_restore"], row["event_type"], row["status_code"], row["status_label"],
        row["raw_cause_code"], row["cause_label"], row["municipality_code"], row["message_id"], Json(row["raw_record"]),
        row["lon"], row["lat"], row["lon"], row["lat"],
    ))


def upsert_history_outage(cur, row):
    cur.execute("""
        INSERT INTO public.hydro_quebec_outages_history (
            outage_uid, first_seen, last_seen, cleared_at, seen_count, latest_source_version,
            affected_customers, severity_label, outage_start, estimated_restore, event_type,
            status_code, status_label, raw_cause_code, cause_label, municipality_code,
            message_id, raw_record, geom
        )
        VALUES (
            %s, now(), now(), NULL, 1, %s, %s, %s,
            NULLIF(%s, '')::timestamp,
            NULLIF(%s, '')::timestamp,
            %s, %s, %s, %s, %s, %s, %s, %s,
            CASE WHEN %s IS NOT NULL AND %s IS NOT NULL THEN ST_SetSRID(ST_MakePoint(%s, %s), 4326) ELSE NULL END
        )
        ON CONFLICT (outage_uid) DO UPDATE SET
            last_seen = now(),
            cleared_at = NULL,
            seen_count = public.hydro_quebec_outages_history.seen_count + 1,
            latest_source_version = EXCLUDED.latest_source_version,
            affected_customers = EXCLUDED.affected_customers,
            severity_label = EXCLUDED.severity_label,
            outage_start = EXCLUDED.outage_start,
            estimated_restore = EXCLUDED.estimated_restore,
            event_type = EXCLUDED.event_type,
            status_code = EXCLUDED.status_code,
            status_label = EXCLUDED.status_label,
            raw_cause_code = EXCLUDED.raw_cause_code,
            cause_label = EXCLUDED.cause_label,
            municipality_code = EXCLUDED.municipality_code,
            message_id = EXCLUDED.message_id,
            raw_record = EXCLUDED.raw_record,
            geom = EXCLUDED.geom;
    """, (
        row["outage_uid"], row["source_version"], row["affected_customers"], row["severity_label"],
        row["outage_start"], row["estimated_restore"], row["event_type"], row["status_code"], row["status_label"],
        row["raw_cause_code"], row["cause_label"], row["municipality_code"], row["message_id"], Json(row["raw_record"]),
        row["lon"], row["lat"], row["lon"], row["lat"],
    ))


def refresh_outages(conn, version: str, outages: list) -> int:
    parsed = [parse_record(version, index, record) for index, record in enumerate(outages)]
    with conn.cursor() as cur:
        cur.execute("""
            INSERT INTO public.hydro_quebec_import_runs (source_version, records_found, records_imported, success)
            VALUES (%s, %s, 0, false)
            RETURNING id;
        """, (version, len(outages)))
        run_id = cur.fetchone()[0]
        cur.execute("TRUNCATE TABLE public.hydro_quebec_outages_current;")
        cur.execute("CREATE TEMP TABLE current_outage_uids (outage_uid TEXT PRIMARY KEY) ON COMMIT DROP;")
        for row in parsed:
            cur.execute("INSERT INTO current_outage_uids (outage_uid) VALUES (%s) ON CONFLICT DO NOTHING;", (row["outage_uid"],))
            insert_current_outage(cur, row)
            upsert_history_outage(cur, row)
        cur.execute("""
            UPDATE public.hydro_quebec_outages_history
            SET cleared_at = now()
            WHERE cleared_at IS NULL
              AND outage_uid NOT IN (SELECT outage_uid FROM current_outage_uids);
        """)
        cur.execute("""
            UPDATE public.hydro_quebec_import_runs
            SET records_imported = %s, success = true
            WHERE id = %s;
        """, (len(parsed), run_id))
    conn.commit()
    return len(parsed)

def main():
    version = get_latest_bis_version()
    outages = fetch_outages(version)

    print(f"Hydro-Québec BIS version: {version}")
    print(f"Outage records found: {len(outages)}")

    conn = connect()
    lock_acquired = False

    try:
        # Prevent multiple ASG instances from running the importer at the same time.
        # This lock is tied to this PostgreSQL connection/session.
        with conn.cursor() as cur:
            cur.execute("SELECT pg_try_advisory_lock(%s);", (80707001,))
            lock_acquired = cur.fetchone()[0]

        if not lock_acquired:
            print("Another Hydro-Québec importer is already running. Exiting.")
            return

        init_schema(conn)

        count = refresh_outages(conn, version, outages)

        print(f"Imported {count} current outage records into PostGIS")

    except Exception as exc:
        conn.rollback()

        try:
            init_schema(conn)

            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO public.hydro_quebec_import_runs (
                        source_version,
                        records_found,
                        records_imported,
                        success,
                        error_message
                    )
                    VALUES (%s, %s, 0, false, %s);
                    """,
                    (version, len(outages), str(exc)),
                )

            conn.commit()

        except Exception as log_exc:
            conn.rollback()
            print(f"Could not write failed import run record: {log_exc}")

        raise

    finally:
        if lock_acquired:
            try:
                with conn.cursor() as cur:
                    cur.execute("SELECT pg_advisory_unlock(%s);", (80707001,))
                conn.commit()
            except Exception as unlock_exc:
                conn.rollback()
                print(f"Could not release advisory lock cleanly: {unlock_exc}")

        conn.close()

if __name__ == "__main__":
    main()
