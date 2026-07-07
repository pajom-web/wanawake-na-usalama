#!/usr/bin/env bash
set -euo pipefail

app_dir="${1:?app directory is required}"
api_base_url="${2:?API base URL is required}"
ws_base_url="${3:?WebSocket base URL is required}"
flutter_dir="${HOME}/flutter"

if [ ! -x "${flutter_dir}/bin/flutter" ]; then
  git clone https://github.com/flutter/flutter.git --branch stable --depth 1 "${flutter_dir}"
fi

export PATH="${flutter_dir}/bin:${PATH}"
flutter --version

cd "${app_dir}"
flutter pub get
flutter build web --release \
  --dart-define=API_BASE_URL="${api_base_url}" \
  --dart-define=WS_BASE_URL="${ws_base_url}"
