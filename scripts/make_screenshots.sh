#!/bin/bash
# Renders App Store screenshots (2880x1800) from the real app views into ./screenshots.
# Offscreen only: nothing on your desktop is captured.
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
OUT="build/screenshots"
mkdir -p "$OUT"
# 1. CaffeineCore as a static library + module, exactly as the app imports it.
swiftc -O -parse-as-library -emit-library -static -module-name CaffeineCore \
  -emit-module -emit-module-path "$OUT/CaffeineCore.swiftmodule" \
  -o "$OUT/libCaffeineCore.a" CaffeineCore/Sources/CaffeineCore/*.swift
# 2. The app's view files plus the renderer.
swiftc -O -I "$OUT" -L "$OUT" -lCaffeineCore -framework IOKit -framework ServiceManagement \
  -o "$OUT/make_screenshots" \
  Caffeine/ContentView.swift Caffeine/SettingsStore.swift Caffeine/PrivacyWindow.swift \
  Caffeine/AppDelegate.swift Caffeine/MenuBarIcon.swift scripts/screenshots/main.swift
"$OUT/make_screenshots" screenshots
