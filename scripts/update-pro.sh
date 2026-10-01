#!/bin/bash
# Explicit UI + backend update; shares the same model, backup and runtime guards.
set -Eeuo pipefail
exec bash "$(dirname "$0")/update-pro-ui.sh" "${1:?verified Paper Pro SSH host/IP required}" --with-backend
