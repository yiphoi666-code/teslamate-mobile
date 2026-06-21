# Real TeslaMate Data Connection Plan

The next milestone is to prove that Garage Lens can read real TeslaMate PostgreSQL data through the Reader API.

## Target Loop

```text
TeslaMate PostgreSQL container
    -> Reader API container
    -> Garage Lens mobile app
```

The mobile app must not connect directly to PostgreSQL and must not store database credentials.

## Deployment Principle

Reader is a Linux Docker add-on for an existing TeslaMate Docker deployment.

- Reader uses its own `docker-compose.reader.yml`.
- Reader joins the existing TeslaMate Docker network.
- Reader connects to the existing PostgreSQL service, usually `database`.
- Reader can be stopped or removed without stopping TeslaMate.
- Reader should use a PostgreSQL read-only account.

## Required Inputs

From the TeslaMate server owner:

```text
TESLAMATE_DOCKER_NETWORK=
DATABASE_HOST=database
DATABASE_PORT=5432
DATABASE_NAME=teslamate
DATABASE_USER=teslamate_readonly
DATABASE_PASSWORD=
DATABASE_SSL=false
READER_API_TOKEN=
```

The mobile app only needs:

```text
Reader API URL
Access token
```

## Success Criteria

1. Reader container is running.
2. `GET /api/health` returns `status: ok`.
3. `GET /api/diagnostics/schema` returns `status: ready`.
4. `GET /api/cars` returns at least one car.
5. `GET /api/cars/:carId/overview` returns vehicle, drives, charges, and database info.
6. Garage Lens `Settings -> Test & Save` succeeds.

## Linux Deployment Commands

On the TeslaMate Linux server:

```bash
cd /opt/garage-lens/reader-api
cp .env.reader.example .env.reader
nano .env.reader
docker compose --env-file .env.reader -f docker-compose.reader.yml up -d --build
```

Verify:

```bash
curl http://localhost:8787/api/health

curl -H "Authorization: Bearer <token>" \
  http://localhost:8787/api/diagnostics/schema

curl -H "Authorization: Bearer <token>" \
  http://localhost:8787/api/cars
```

Stop Reader only:

```bash
docker compose --env-file .env.reader -f docker-compose.reader.yml down
```

## First Real Pages To Prove

- Overview: car, battery, range, location, latest data time
- Drives: recent drive list and drive detail
- Charges: recent charging sessions and charge detail
- Settings: Reader API health check and saved URL/token

After those are real, expand to the full Grafana-equivalent charts.
