# Garage Lens

A Flutter Android app for viewing self-hosted TeslaMate data.

## Latest APK

Download the latest Android APK:

[GarageLens-TeslaMate-v0.5.18-tracking-drives-fix.apk](release-apk/GarageLens-TeslaMate-v0.5.18-tracking-drives-fix.apk)

The app can run with built-in mock data for UI review, or switch to a TeslaMate Reader API backed by the TeslaMate PostgreSQL database.

## Data Flow

```text
Tesla servers
    -> TeslaMate service
    -> TeslaMate PostgreSQL
    -> TeslaMate Reader API
    -> Garage Lens mobile app
```

Garage Lens does not collect Tesla data, connect to Tesla servers, or store PostgreSQL credentials on the phone. TeslaMate keeps running on the user's server and writes telemetry to PostgreSQL. A small Reader API service should run beside TeslaMate, query PostgreSQL with a read-only database account, and expose stable JSON endpoints to the app.

The mobile app should only need:

- Reader API URL
- Access token

The Reader backend owns:

- PostgreSQL host, port, database name, user, and password
- SQL queries against the TeslaMate schema
- API authentication, response shaping, and compatibility with future schema changes

See [TeslaMate Reader API Coverage](docs/reader_api_coverage.md) for the dashboard-derived API scope.

See [Real TeslaMate Data Connection Plan](docs/real_data_connection_plan.md) for the next milestone: connecting the Reader API to a real TeslaMate PostgreSQL database.

## Run The Flutter App Locally

```powershell
cd D:\Codex\teslamate_mobile
flutter run
```

The app can also be configured from `Settings` with a Reader API URL and access token, then saved locally.

## Reader API Deployment

Reader API is deployed as a Linux Docker add-on beside TeslaMate. It joins the existing TeslaMate Docker network and can be stopped or removed without touching TeslaMate.

```bash
cd /opt/garage-lens/reader-api
cp .env.reader.example .env.reader
nano .env.reader
docker compose --env-file .env.reader -f docker-compose.reader.yml up -d --build
```

See [Reader API deployment guide](reader-api/README.md).

## Screens

- Overview: vehicle status, battery, range, monthly stats
- Drives: recent drive history, detail pages, route tracking, Visited Lifetime Map
- Charges: charging sessions, detail pages, cost, kWh, power curves
- Insights: dashboard-derived analytics, charging costs, curves, degradation, speed and temperature efficiency, data quality
- Settings: TeslaMate Reader API URL/token health check
