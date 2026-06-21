# TeslaMate Reader API

Reader API is a read-only middle layer between Garage Lens and a self-hosted TeslaMate PostgreSQL database.

```text
Garage Lens mobile app -> Reader API container -> TeslaMate PostgreSQL container
```

The mobile app only receives:

```text
Reader API URL
Access token
```

It never receives PostgreSQL credentials and never sends raw SQL.

## Deployment Model

Reader is designed as a TeslaMate add-on:

- It runs as a separate Docker Compose project.
- It joins the existing TeslaMate Docker network.
- It connects to the existing TeslaMate PostgreSQL service, usually named `database`.
- It does not modify the TeslaMate, Grafana, Mosquitto, PostgreSQL containers, or volumes.
- Uninstalling Reader only stops/removes the Reader container.

This matches the common TeslaMate Docker deployment shape documented by TeslaMate: `teslamate`, `database`, `grafana`, and `mosquitto` services on the Compose network.

Reader is currently distributed as source and built locally on the TeslaMate host. Do not run `docker compose pull reader` for this add-on unless you intentionally publish your own image. The provided Compose file builds the Reader image from the local `Dockerfile`, so the container includes its own production `node_modules`; it must not rely on `./node_modules` mounted from the host.

## Files

```text
Dockerfile
docker-compose.reader.yml
.env.reader.example
src/
```

## 1. Copy Reader To The Linux Server

Place this `reader-api` directory on the same Linux host that runs TeslaMate, or on another host that can reach the TeslaMate PostgreSQL container/network.

Example:

```bash
cd /opt
sudo mkdir -p garage-lens
sudo chown "$USER:$USER" garage-lens
cd /opt/garage-lens
```

Copy the `reader-api` folder here.

## 2. Find The TeslaMate Docker Network

On the TeslaMate server:

```bash
docker network ls
```

If TeslaMate was deployed from a directory named `teslamate`, the network is often:

```text
teslamate_default
```

If unsure:

```bash
docker compose ps
docker inspect teslamate --format '{{json .NetworkSettings.Networks}}'
```

Use the network name in `.env.reader`.

## 3. Configure Reader

```bash
cd /opt/garage-lens/reader-api
cp .env.reader.example .env.reader
nano .env.reader
```

Minimum config:

```env
READER_API_TOKEN=change-me-to-a-long-random-token
READER_API_PORT=8787
TESLAMATE_DOCKER_NETWORK=teslamate_default

DATABASE_HOST=database
DATABASE_PORT=5432
DATABASE_NAME=teslamate
DATABASE_USER=teslamate_readonly
DATABASE_PASSWORD=change-me
DATABASE_SSL=false
```

`DATABASE_HOST=database` works when Reader joins the same Docker network as the TeslaMate PostgreSQL container.

## 4. Create A Read-Only PostgreSQL User

Recommended: use a dedicated read-only user instead of TeslaMate's write user.

Find the PostgreSQL container:

```bash
docker compose ps
```

Enter the PostgreSQL container from the TeslaMate compose directory:

```bash
docker compose exec database psql -U teslamate -d teslamate
```

If your TeslaMate database user is not `teslamate`, use the database user from your TeslaMate `.env`.

Run:

```sql
create user teslamate_readonly with password 'change-me';
grant connect on database teslamate to teslamate_readonly;
grant usage on schema public to teslamate_readonly;
grant select on all tables in schema public to teslamate_readonly;
alter default privileges in schema public grant select on tables to teslamate_readonly;
```

Then put the same password in Reader's `.env.reader`.

This changes only PostgreSQL permissions. It does not stop or alter TeslaMate containers.

## 5. Start Reader

From the Reader directory:

```bash
docker compose --env-file .env.reader -f docker-compose.reader.yml up -d --build
```

Use `--build` when upgrading Reader so Docker rebuilds the local image:

```bash
docker compose --env-file .env.reader -f docker-compose.reader.yml build --no-cache reader
docker compose --env-file .env.reader -f docker-compose.reader.yml up -d reader
```

Do not use:

```bash
docker compose --env-file .env.reader -f docker-compose.reader.yml pull reader
```

Reader does not require a public `garage-lens/teslamate-reader-api:latest` image for this deployment flow.

Check logs:

```bash
docker compose --env-file .env.reader -f docker-compose.reader.yml logs -f reader
```

If the container name is `reader-api-reader-1`, you can also watch logs directly:

```bash
docker logs -f reader-api-reader-1
```

Reader prints one-line JSON logs to stdout/stderr, so Docker logs will include both API request logs and PostgreSQL query logs.

Example API logs:

```json
{"level":"info","event":"api_request_started","requestId":"...","method":"GET","path":"/api/cars/1/overview","query":{}}
{"level":"info","event":"api_request_completed","requestId":"...","method":"GET","path":"/api/cars/1/overview","statusCode":200,"durationMs":1842}
```

Example database logs:

```json
{"level":"info","event":"db_query_started","requestId":"...","queryId":"...","sql":"select * from cars where id = $1","params":[1]}
{"level":"info","event":"db_query_completed","requestId":"...","queryId":"...","durationMs":12,"rowCount":1}
```

Use the same `requestId` to connect a slow API request with the SQL queries that happened inside it. Reader does not log bearer tokens or database passwords.

## 6. Verify Reader

Health:

```bash
curl http://localhost:8787/api/health
```

Lightweight runtime check without a database query:

```bash
curl http://localhost:8787/api/ping
```

Token-only check without a database query:

```bash
curl -H "Authorization: Bearer change-me-to-a-long-random-token" \
  http://localhost:8787/api/auth/check
```

Schema diagnostics:

```bash
curl -H "Authorization: Bearer change-me-to-a-long-random-token" \
  http://localhost:8787/api/diagnostics/schema
```

Cars:

```bash
curl -H "Authorization: Bearer change-me-to-a-long-random-token" \
  http://localhost:8787/api/cars
```

Overview:

```bash
curl -H "Authorization: Bearer change-me-to-a-long-random-token" \
  http://localhost:8787/api/cars/1/overview
```

Vehicle-related raw database table catalog:

```bash
curl -H "Authorization: Bearer change-me-to-a-long-random-token" \
  http://localhost:8787/api/cars/1/database/tables
```

Paginated raw rows from a vehicle-related table:

```bash
curl -H "Authorization: Bearer change-me-to-a-long-random-token" \
  "http://localhost:8787/api/cars/1/database/tables/positions?limit=500&offset=0&order=desc"
```

Limited raw export across all detected vehicle-related tables:

```bash
curl -H "Authorization: Bearer change-me-to-a-long-random-token" \
  "http://localhost:8787/api/cars/1/database/export?limitPerTable=100"
```

TeslaMate global settings:

```bash
curl -H "Authorization: Bearer change-me-to-a-long-random-token" \
  http://localhost:8787/api/database/settings
```

Expected schema result:

```json
{
  "status": "ready",
  "connection": {
    "connected": true
  },
  "missingTables": [],
  "missingColumns": {}
}
```

## 7. Connect The App

In Garage Lens:

```text
Settings -> Reader API URL -> Access token -> Test & Save
```

For production, use HTTPS:

```text
https://reader.example.com
```

For private LAN testing:

```text
http://server-lan-ip:8787
```

## 8. Stop Or Uninstall Reader

Stop Reader only:

```bash
docker compose --env-file .env.reader -f docker-compose.reader.yml down
```

Remove Reader image too:

```bash
docker compose --env-file .env.reader -f docker-compose.reader.yml down --rmi local
```

This does not stop TeslaMate, Grafana, Mosquitto, PostgreSQL, or remove TeslaMate volumes.

## Security Notes

- Use HTTPS for public access.
- Do not expose PostgreSQL to the public internet.
- Use a long random `READER_API_TOKEN`.
- Use a PostgreSQL read-only user.
- Put Reader behind a reverse proxy such as Caddy, Nginx, or Traefik.
- Keep Reader on the same private Docker network as TeslaMate whenever possible.
- Raw table endpoints are read-only and paginated. They do not accept arbitrary SQL.

## Endpoints

For a shareable HTML reference, see `docs/reader_api_reference.html` in the Garage Lens project.

```text
GET /api/health
GET /api/diagnostics/schema
GET /api/cars
GET /api/cars/:carId/overview
GET /api/cars/:carId/drives
GET /api/cars/:carId/drives/:driveId
GET /api/cars/:carId/drives/:driveId/tracking
GET /api/cars/:carId/charging/sessions
GET /api/cars/:carId/charging/sessions/:chargeId
GET /api/cars/:carId/visited-map
GET /api/database/info
GET /api/database/settings
GET /api/cars/:carId/data-quality
GET /api/cars/:carId/database/tables
GET /api/cars/:carId/database/tables/:tableName
GET /api/cars/:carId/database/export
```

Raw vehicle database endpoints automatically expose:

- tables with a direct `car_id` column, such as `positions`, `drives`, `states`, `charging_processes`, and compatible future TeslaMate tables;
- `charges`, joined through `charging_processes.car_id`;
- referenced `addresses` and `geofences` when the TeslaMate schema contains the needed reference columns;
- the selected `cars` row.

Supported query parameters for `database/tables/:tableName`:

```text
limit   default 200, max 1000
offset  default 0
order   asc or desc, default desc
from    ISO date filter when the table has a date/start_date column
to      ISO date filter when the table has a date/start_date column
```
