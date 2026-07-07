# Flutter Clean Architecture Layout

```text
lib/
  core/
    config/
    network/
    session/
    theme/
  features/
    auth/
      data/
      domain/
      presentation/
    map/
      data/
      domain/
      presentation/
    report/
      data/
      domain/
      presentation/
    live_location/
      data/
      domain/
      presentation/
```

Each feature keeps transport and persistence code in `data`, pure app models in `domain`, and screens/controllers/widgets in `presentation`. Shared tokens, API configuration, session storage, and visual theme primitives live in `core`.
