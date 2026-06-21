# TeslaMate Reader API Coverage

Garage Lens should display data already collected by TeslaMate. It must not connect to Tesla servers, poll vehicles, or store PostgreSQL credentials on the phone.

## Runtime Flow

```text
Tesla servers
    -> TeslaMate service
    -> TeslaMate PostgreSQL
    -> TeslaMate Reader API
    -> Garage Lens mobile app
```

TeslaMate keeps running on the user's own server and writes telemetry to PostgreSQL. The Reader API runs beside TeslaMate, queries PostgreSQL with a read-only account, and exposes stable JSON endpoints to the mobile app.

## Environment Variables

TeslaMate environment variables are runtime configuration for the TeslaMate service. They are not mobile display fields.

Examples:

- `DATABASE_USER`, `DATABASE_PASS`, `DATABASE_NAME`, `DATABASE_HOST`, `DATABASE_PORT`: how TeslaMate reaches PostgreSQL.
- `TESLA_API_HOST`, `TESLA_AUTH_HOST`, `TESLA_WSS_HOST`: how TeslaMate reaches Tesla services.
- `POLLING_*`: how often TeslaMate polls in each vehicle state.
- `MQTT_*`: optional MQTT integration.
- `TZ`, `VIRTUAL_HOST`, `URL_PATH`, `CHECK_ORIGIN`, `PORT`: deployment and web configuration.

Garage Lens should not ask for Tesla API values. The mobile app only needs:

- Reader API URL
- Access token

The Reader backend owns:

- PostgreSQL host, port, database, user, and password
- SQL queries against TeslaMate schema
- API authentication and response shaping

## Dashboard Coverage

The custom Grafana dashboards define the practical target coverage. If Grafana can render a panel from TeslaMate PostgreSQL, the Reader API can expose equivalent JSON for the app.

TeslaMate's official screenshot page also defines a product-level coverage target. The current mobile UI groups these 22 screenshot areas into second-level Insights modules instead of placing every chart on the first-level screen.

| Official screenshot area | Mobile destination |
| --- | --- |
| Web Interface | Not copied directly; replaced by native mobile navigation |
| Battery Health | Insights -> Battery and range |
| Charge Level | Insights -> Charging analytics |
| Charges | Charges tab and Insights -> Charging analytics |
| Charge Details | Insights -> Charging analytics |
| Charging Stats | Insights -> Charging analytics |
| Database Information | Insights -> System and ownership |
| Drive Stats | Insights -> Drives and trips |
| Drives | Drives tab and Insights -> Drives and trips |
| Drive Details | Insights -> Drives and trips |
| Efficiency | Insights -> Efficiency lab |
| Location (addresses) | Overview and Insights -> Vehicle live view |
| Mileage | Insights -> Drives and trips |
| Overview | Overview tab and Insights -> Vehicle live view |
| Projected Range | Insights -> Battery and range |
| States | Insights -> Vehicle live view |
| Statistics | Insights -> System and ownership |
| Timeline | Insights -> Vehicle live view |
| Trip | Insights -> Drives and trips |
| Updates | Insights -> Vehicle live view |
| Vampire Drain | Insights -> Battery and range |
| Visited (Lifetime driving map) | Drives -> Visited Lifetime Map |

| Dashboard | App/API capability |
| --- | --- |
| `CurrentState.json` | Current state, last state change, range, estimated range, battery level, tire pressure, driver/inside/outside temperature, location, states, odometer, firmware, timeline |
| `CurrentDriveView.json` | Live drive, efficiency, battery capacity, gross consumption, elapsed time, distance, average speed, current range, odometer |
| `CurrentChargeView.json` | Live charge added energy/range, odometer, range values |
| `TrackingDrives.json` | Drive tracking, net energy consumed, elevation |
| `ContinuousTrips.json` | Long trips |
| `ChargingCostsStats.json` | Total/free energy, kWh per distance, charge count, main locations, AC/DC/Supercharger energy and costs, cost per distance, cost per kWh, net/gross consumption, top stations, monthly stats |
| `ChargingCurveStats.json` | Supercharger curve, other DC curve, max power |
| `DCChargingCurvesByCarrier.json` | Carrier-filtered DC charging stats: average energy added/used, charging time, cost, cost per kWh |
| `MileageStats.json` | Mileage and drive counts per period |
| `RangeDegradation.json` | Range degradation, trips this period, battery stats this period |
| `SpeedRates.json` | Consumption by speed and terrain, logged distance, net/gross consumption, current efficiency, time spent by speed |
| `SpeedTemperature.json` | Consumption/range by speed and temperature, distance percentage by speed/temperature, short/long trip consumption, date trends |
| `IncompleteData.json` | Car information, incomplete drives, incomplete charges |
| `AmortizationTracker.json` | Break-even chart, depreciation over time, break-even table |

## Proposed Endpoint Groups

```text
GET /api/health
GET /api/cars
GET /api/cars/:carId/settings

GET /api/cars/:carId/current-state
GET /api/cars/:carId/current-drive
GET /api/cars/:carId/current-charge

GET /api/cars/:carId/drives
GET /api/cars/:carId/drives/:driveId/tracking
GET /api/cars/:carId/trips/continuous

GET /api/cars/:carId/charging/sessions
GET /api/cars/:carId/charging/costs
GET /api/cars/:carId/charging/curves
GET /api/cars/:carId/charging/carriers

GET /api/cars/:carId/mileage
GET /api/cars/:carId/range-degradation
GET /api/cars/:carId/efficiency/speed-rates
GET /api/cars/:carId/efficiency/speed-temperature

GET /api/cars/:carId/data-quality
GET /api/cars/:carId/amortization
```

## Query Parameters

Grafana dashboard variables should become explicit API query parameters:

- `car_id` -> path parameter `:carId`
- `length_unit`, `preferred_range`, `temp_unit`, `pressure_unit` -> read from TeslaMate `settings`, with optional API override
- `period` -> query parameter, e.g. `?period=month`
- `from`, `to` -> query parameters for time ranges
- `geofence`, `carrier`, `terrain_type` -> query parameters with allow-listed values

The app must never send raw SQL. The Reader API owns the SQL and validates all parameters.

## Implementation Rules

- Use a PostgreSQL read-only account.
- Do not expose PostgreSQL directly to the public internet for mobile access.
- Keep SQL in the Reader backend, not the Flutter app.
- Return stable JSON DTOs so TeslaMate schema changes can be handled server-side.
- Track TeslaMate version/schema compatibility in the Reader API.
- Prefer summarized mobile-friendly endpoints over copying Grafana panel layouts exactly.
