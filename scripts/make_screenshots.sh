#!/bin/bash
# Renders App Store screenshots (2880x1800) from the real app views into ./screenshots.
# Offscreen only: nothing on your desktop is captured.
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
OUT="build/screenshots"
mkdir -p "$OUT"
# 1. BeanCore as a static library + module, exactly as the app imports it.
swiftc -O -parse-as-library -emit-library -static -module-name BeanCore \
  -emit-module -emit-module-path "$OUT/BeanCore.swiftmodule" \
  -o "$OUT/libBeanCore.a" BeanCore/Sources/BeanCore/*.swift
# 2. The app's view files plus the renderer.
swiftc -O -I "$OUT" -L "$OUT" -lBeanCore -framework IOKit -framework ServiceManagement \
  -o "$OUT/make_screenshots" \
  Bean/ContentView.swift Bean/SettingsStore.swift Bean/PrivacyWindow.swift \
  Bean/AppDelegate.swift Bean/MenuBarIcon.swift Bean/BeanGlyph.swift scripts/screenshots/main.swift
"$OUT/make_screenshots" screenshots
