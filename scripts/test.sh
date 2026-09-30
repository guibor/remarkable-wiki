#!/bin/bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
export GOCACHE="${GOCACHE:-$PWD/.cache/go-build}"
mkdir -p .cache
if [ "$(uname -s)" = Darwin ]; then
  CGO_ENABLED=1 go test -race -ldflags=-linkmode=external ./...
else
  go test -race ./...
fi
go vet ./...
QT_QPA_PLATFORM=offscreen qmltestrunner -input tests -import tests/mocks
bash scripts/build.sh
