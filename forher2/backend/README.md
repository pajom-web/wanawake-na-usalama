# Retired backend entry point

The active backend is `../../project6/backend`. Both the mobile app and police
dashboard use that service and its `db.sqlite3` database.

This directory is retained only to avoid destructively deleting the previous
mobile backend and its data. Running `python manage.py ...`, loading
`safety_backend.asgi`, or loading `safety_backend.wsgi` delegates to the shared
backend. Do not add new models, routes, or migrations here.
