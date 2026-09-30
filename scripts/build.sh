#!/bin/bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
export GOCACHE="${GOCACHE:-$PWD/.cache/go-build}"
out=dist/remarkable-wiki
mkdir -p "$out/backend"
CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -trimpath -o "$out/backend/entry" ./cmd/wiki-backend
"${RCC:-/opt/homebrew/share/qt/libexec/rcc}" --binary --format-version 2 --no-compress qml/application.qrc -o "$out/resources.rcc"
cp packaging/manifest.json "$out/manifest.json"
rsvg-convert assets/icon.svg -o "$out/icon.png"
(cd "$out" && shasum -a 256 manifest.json resources.rcc backend/entry icon.png > SHA256SUMS)
printf 'Built %s (not installed)\n' "$out"
