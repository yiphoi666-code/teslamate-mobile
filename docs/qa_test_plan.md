# Garage Lens QA Test Plan

## Scope

- Mobile app: Garage Lens Flutter Android app.
- Reader API: public Reader API contract over `https://js-reader.hgnan.dpdns.org`.
- Data mapping: app model/field mapping from Reader API JSON.
- Release artifact: `GarageLens-TeslaMate-v0.5.0-qa-smoke-fix.apk`.

## Release Gate

| Check | Command | Status | Notes |
| --- | --- | --- | --- |
| Flutter analyze | `flutter analyze` | Passed | No issues found |
| Flutter tests | `flutter test --reporter expanded` | Passed | 4 active tests passed, 6 existing deeper navigation tests remain skipped |
| APK build | `flutter build apk --release` | Passed | Release APK builds successfully |
| ADB smoke | `powershell -ExecutionPolicy Bypass -File scripts/adb_smoke_test.ps1` | Passed | Emulator `emulator-5554`, fresh install/clear-state launch |
| Maestro smoke | `maestro test maestro/connect_reader_smoke.yaml` | Blocked | Maestro Studio installed, but `maestro` CLI is not in PATH |

## P0 Test Cases

| ID | Case | Layer | Status | Notes |
| --- | --- | --- | --- | --- |
| P0-001 | Fresh install shows Connect Reader and data hidden | ADB/Widget | Automated / Passed | ADB smoke plus widget test |
| P0-002 | URL/token fields accept paste/input | Widget | Automated / Passed | Text entry covered; platform paste remains manual |
| P0-003 | Valid URL/token saves config and loads first data batch | API/E2E | Partially covered | Reader API contract passed; full app E2E with real token remains manual |
| P0-004 | Invalid token shows auth error and stays editable | Widget/API | Partially covered | Invalid URL covered; invalid token UI still needs mockable client test |
| P0-005 | Timeout/socket abort shows friendly retry and does not reset login | Widget | Automated / Passed | Configured-user refresh failure covered |
| P0-006 | Restart after login preserves Reader config | E2E | Not covered | Needs device persistence test |
| P0-007 | No data visible before successful validation | Widget/ADB | Automated / Passed | Hidden state covered |
| P0-008 | APK installs and launches on connected Android device | ADB | Automated / Passed | `emulator-5554` |

## P1 Test Cases

| ID | Case | Layer | Status | Notes |
| --- | --- | --- | --- | --- |
| P1-001 | Vehicle summary fields match Reader API summary | API/Widget | Partially covered | API summary contract passed; UI field-by-field comparison pending |
| P1-002 | Drive list and detail fields match Reader API | API/Widget | Partially covered | API drives contract passed; detail mapping assertions pending |
| P1-003 | Charging sessions and curves match Reader API | API/Widget | Partially covered | API charging contract passed; curve UI assertions pending |
| P1-004 | Analytics charts tolerate missing/empty arrays | Unit/Widget | Not covered | Needs mapper fixtures for empty arrays |
| P1-005 | Chinese location names render correctly | API/E2E | Partially covered | API returns Chinese location names; device visual assertion pending |

## Reader API Contract

| Endpoint | Status | Notes |
| --- | --- | --- |
| `GET /api/ping` | Passed | 200, 53 bytes, 1929 ms |
| `GET /api/auth/check` | Passed | 200, 54 bytes, 429 ms |
| `GET /api/cars` | Passed | 200, array:1, 1354 ms |
| `GET /api/cars/:id/summary` | Passed | 200, object:vehicle, 3263 ms |
| `GET /api/cars/:id/drives?limit=25` | Passed | 200, array:25, 1978 ms |
| `GET /api/cars/:id/charging/sessions?limit=25` | Passed | 200, array:25, 7232 ms |
| `GET /api/cars/:id/analytics` | Passed | 200, object, 20263 ms |

## Manual Checks

- Install APK on real Android phone.
- Paste real Reader API URL/token.
- Background app for 1-2 hours and resume.
- Toggle VPN/network and retry.
- Compare key UI values with TeslaMate/Grafana screenshots or direct API JSON.

## Known Gaps

- Maestro CLI is not available; only Maestro Studio is installed. Use ADB smoke until CLI is installed.
- Flutter integration test exists but was previously unstable on this Windows/Android 16 emulator setup; widget tests and ADB smoke are the current reliable automated gate.
- Full valid-login app E2E with real token is still manual to avoid committing or hardcoding secrets.
- Field-by-field UI vs Reader API assertions are not yet automated.
- Background 1-2 hour real-device resume remains manual.
