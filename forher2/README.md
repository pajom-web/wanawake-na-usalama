# Gender-Sensitive Safety App Boilerplate

This directory contains the mobile client of a lightweight local stack for a
real-time safety app:

- `mobile/`: Flutter clean architecture scaffold using Riverpod and `flutter_map`.
- `../project6/backend/`: the only Django backend, shared with the police
  dashboard in `../project6/frontend/`.

Do not start a second backend from this mobile directory. The shared backend
intentionally uses standard relational fields for coordinates. It does not use
PostGIS, SpatiaLite, `django.contrib.gis`, Redis, Docker, or distributed caches.

## Backend Quick Start

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r ..\project6\backend\requirements.txt
python ..\project6\backend\manage.py migrate
python ..\project6\backend\manage.py runserver
```

REST API base URL: `http://127.0.0.1:8000/api/`

Public hotspot WebSocket URL:

```text
ws://127.0.0.1:8000/ws/citizen/hotspots/
```

Police dashboard compatibility:

- Public mobile/citizen incident submission: `POST /api/incidents/`
- Mobile/citizen status polling: `GET /api/incidents/status/<anonymous-token>/`
- Police dashboard login/session: `POST /api/police/login/`
- Police incident queue and updates: `GET /api/police/incidents/`, `PATCH /api/police/incidents/<id>/`
- Police dashboard alerts websocket: `ws://127.0.0.1:8000/ws/police/alerts/`

Create police users from Django admin under `Police officers`, then point the
`mdadaa`/police dashboard frontend at this backend with:

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000 --dart-define=WS_BASE_URL=ws://127.0.0.1:8000
```

## Flutter Quick Start

```powershell
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api --dart-define=WS_BASE_URL=ws://127.0.0.1:8000
```

For Android emulators, use `10.0.2.2` instead of `127.0.0.1`.
