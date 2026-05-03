# OpenGIS Hydro-Québec Mapping Lab

This project deploys an open-source GIS platform on AWS using Terraform, Docker, PostGIS, GeoServer, pg_tileserv, pg_featureserv, Caddy, MapLibre, and a Hydro-Québec outage data importer.

The goal is to provide an ArcGIS-style open-source lab environment for mapping live Hydro-Québec outage data, serving spatial data, and experimenting with GIS infrastructure patterns on AWS.

<img width="1677" height="910" alt="Image" src="https://github.com/user-attachments/assets/c8fb9eda-13f0-44b7-b434-2269197edff5" />

> Note: This is not ArcGIS Enterprise. It is an open-source GIS stack designed to provide similar mapping, spatial database, and web portal capabilities for lab and learning purposes.

---

## Current Architecture

The current version is a single-node AWS deployment.

```text
Internet
   |
   v
AWS Security Group
   |
   v
Ubuntu EC2 Instance
   |
   +-- Caddy Reverse Proxy
   |     +-- /
   |     +-- /geoserver
   |     +-- /tiles
   |     +-- /features
   |     +-- /pgadmin
   |
   +-- MapLibre Web Dashboard
   |
   +-- GeoServer
   |
   +-- pg_tileserv
   |
   +-- pg_featureserv
   |
   +-- pgAdmin
   |
   +-- Hydro-Québec Importer
   |
   +-- PostGIS Docker Container
