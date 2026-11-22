#!/usr/bin/env bash
# Installs the Flutter SDK for cloud containers (Codex Cloud etc.) that don't
# have it. On a MacBook, install Flutter normally instead.
set -euo pipefail
FLUTTER_DIR="${FLUTTER_DIR:-$HOME/flutter}"
if ! command -v flutter >/dev/null 2>&1; then
  if [ ! -d "$FLUTTER_DIR" ]; then
    git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$FLUTTER_DIR"
  fi
  export PATH="$FLUTTER_DIR/bin:$PATH"
fi
flutter --disable-analytics >/dev/null 2>&1 || true
flutter --version
flutter pub get
echo "Add to PATH if needed: export PATH=\"$FLUTTER_DIR/bin:\$PATH\""
