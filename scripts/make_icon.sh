#!/bin/bash
# Regenerates Bean/AppIcon.icon from the bean drawing in Bean/BeanGlyph.swift.
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
OUT="build/make_icon"
mkdir -p "$OUT"
swiftc -O -o "$OUT/make_icon" Bean/BeanGlyph.swift scripts/make_icon/main.swift
"$OUT/make_icon" Bean/AppIcon.icon
