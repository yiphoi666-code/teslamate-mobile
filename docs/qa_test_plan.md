# Garage Lens QA Test Plan

## Scope

- Mobile app:
- Reader API:
- Data mapping:
- Release artifact:

## Release Gate

| Check | Command | Status | Notes |
| --- | --- | --- | --- |
| Flutter analyze | `flutter analyze` | Not run | |
| Flutter tests | `flutter test --reporter expanded` | Not run | |
| APK build | `flutter build apk --release` | Not run | |
| ADB smoke | `powershell -ExecutionPolicy Bypass -File scripts/adb_smoke_test.ps1` | Not run | |
| Maestro smoke | `maestro test maestro/connect_reader_smoke.yaml` | Not run | Requires Maestro CLI |

## P0 Test Cases

| ID | Case | Layer | Status | Notes |
| --- | --- | --- | --- | --- |
| P0-001 | Fresh install shows Connect Reader and data hidden | ADB/Maestro | Not covered | |
| P0-002 | URL/token fields accept paste/input | Widget/E2E | Not covered | |
| P0-003 | Valid URL/token saves config and loads first data batch | E2E/API | Not covered | |
| P0-004 | Invalid token shows auth error and stays editable | Widget/API | Not covered | |
| P0-005 | Timeout/socket abort shows friendly retry and does not reset login | Widget/E2E | Not covered | |
| P0-006 | Restart after login preserves Reader config | E2E | Not covered | |
| P0-007 | No data visible before successful validation | Widget/E2E | Not covered | |
| P0-008 | APK installs and launches on connected Android device | ADB | Not covered | |

## P1 Test Cases

| ID | Case | Layer | Status | Notes |
| --- | --- | --- | --- | --- |
| P1-001 | Vehicle summary fields match Reader API summary | API/Widget | Not covered | |
| P1-002 | Drive list and detail fields match Reader API | API/Widget | Not covered | |
| P1-003 | Charging sessions and curves match Reader API | API/Widget | Not covered | |
| P1-004 | Analytics charts tolerate missing/empty arrays | Unit/Widget | Not covered | |
| P1-005 | Chinese location names render correctly | Widget/E2E | Not covered | |

## Reader API Contract

| Endpoint | Status | Notes |
| --- | --- | --- |
| `GET /api/ping` | Not run | |
| `GET /api/auth/check` | Not run | |
| `GET /api/cars` | Not run | |
| `GET /api/cars/:id/summary` | Not run | |
| `GET /api/cars/:id/drives?limit=25` | Not run | |
| `GET /api/cars/:id/charging/sessions?limit=25` | Not run | |
| `GET /api/cars/:id/analytics` | Not run | |

## Manual Checks

- Install APK on real Android phone.
- Paste real Reader API URL/token.
- Background app for 1-2 hours and resume.
- Toggle VPN/network and retry.
- Compare key UI values with TeslaMate/Grafana screenshots or direct API JSON.

## Known Gaps

- 
