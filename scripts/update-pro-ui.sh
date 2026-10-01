#!/bin/bash
# Guarded app update. Default UI-only; --with-backend explicitly updates backend too.
set -Eeuo pipefail
cd "$(dirname "$0")/.."
host=${1:?verified Paper Pro SSH host/IP required}
mode=${2:-ui}
case "$mode" in ui|--with-backend) ;; *) echo 'Unknown update mode' >&2; exit 1 ;; esac
api=$(sed -n 's/.*"backendProtocol": *\([0-9]*\).*/\1/p' packaging/manifest.json)
api=${api:-1}
key=${RM_SSH_KEY:-$HOME/.ssh/id_ed25519_remarkable_new}
opts=(-i "$key" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=5)
id=wiki-ui-$(date -u +%Y%m%dT%H%M%SZ)
stage=/home/root/.codex-staging/$id
backup=/home/root/.codex-backups/$id
receipt=.cache/receipts/$id
mkdir -p "$receipt"
test -s dist/remarkable-wiki/resources.rcc
cmp packaging/manifest.json dist/remarkable-wiki/manifest.json

ssh "${opts[@]}" "root@$host" sh -s -- "$stage" "$backup" "$mode" "$api" <<'REMOTE'
set -eu
stage=$1; backup=$2; mode=$3; api=$4
target=/home/root/xovi/exthome/appload/remarkable-wiki
state=/home/root/.local/share/remarkable-wiki
test "$(tr -d '\000' </sys/firmware/devicetree/base/model)" = 'reMarkable Ferrari'
test "$(cat /etc/version)" = 20260911125116
test "$(sha256sum /usr/bin/xochitl | cut -d' ' -f1)" = 4f433281c71a29d07921665b4724420735f3c88aceb431067f3a432b3f89f6a4
systemctl is-active --quiet xochitl
test -d "$target"
test -f "$state/state.json"
installed_api=$(sed -n 's/.*"backendProtocol": *\([0-9]*\).*/\1/p' "$target/manifest.json")
installed_api=${installed_api:-1}
if [ "$mode" = ui ] && [ "$installed_api" != "$api" ]; then
    echo 'This release needs a matching backend. Use scripts/update-pro.sh.' >&2; exit 1
fi
if pgrep -f '[/]tmp/remarkable-wiki.sock' >/dev/null; then
    echo 'Close Wikipedia before updating.' >&2; exit 1
fi
pid=$(systemctl show xochitl -p MainPID --value)
if grep -F "$target/resources.rcc" "/proc/$pid/maps" >/dev/null; then
    echo 'Wikipedia resources are still mapped; close the app first.' >&2; exit 1
fi
mkdir -m 700 "$stage" "$backup"
(cd "$target" && sha256sum -c SHA256SUMS)
tar -C /home/root -czf "$backup/before.tar.gz" xovi/exthome/appload/remarkable-wiki .local/share/remarkable-wiki
sha256sum "$backup/before.tar.gz" > "$backup/archive.sha256"
sha256sum "$state/state.json" > "$backup/state.sha256"
sha256sum "$target/icon.png" > "$backup/preserved.sha256"
if [ "$mode" = ui ]; then sha256sum "$target/backend/entry" >> "$backup/preserved.sha256"; fi
{ systemctl show xochitl -p MainPID -p DropInPaths -p NRestarts; findmnt -no OPTIONS /; } > "$backup/runtime-before.txt"
cp -a "$target" "$stage/remarkable-wiki"
REMOTE

# Verify a complete off-device rollback copy before changing the installed app.
scp -O "${opts[@]}" "root@$host:$backup/before.tar.gz" "root@$host:$backup/archive.sha256" "$receipt/"
expected=$(cut -d' ' -f1 "$receipt/archive.sha256")
actual=$(shasum -a 256 "$receipt/before.tar.gz" | cut -d' ' -f1)
test "$expected" = "$actual"
tar -tzf "$receipt/before.tar.gz" >/dev/null
scp -O "${opts[@]}" dist/remarkable-wiki/manifest.json dist/remarkable-wiki/resources.rcc "root@$host:$stage/remarkable-wiki/"
if [ "$mode" = --with-backend ]; then
    scp -O "${opts[@]}" dist/remarkable-wiki/backend/entry "root@$host:$stage/remarkable-wiki/backend/entry"
fi
resource_hash=$(shasum -a 256 dist/remarkable-wiki/resources.rcc | cut -d' ' -f1)
manifest_hash=$(shasum -a 256 dist/remarkable-wiki/manifest.json | cut -d' ' -f1)
backend_hash=$(shasum -a 256 dist/remarkable-wiki/backend/entry | cut -d' ' -f1)

ssh "${opts[@]}" "root@$host" sh -s -- "$stage" "$backup" "$resource_hash" "$manifest_hash" "$backend_hash" "$mode" <<'REMOTE'
set -eu
stage=$1; backup=$2
target=/home/root/xovi/exthome/appload/remarkable-wiki
test "$(sha256sum "$stage/remarkable-wiki/resources.rcc" | cut -d' ' -f1)" = "$3"
test "$(sha256sum "$stage/remarkable-wiki/manifest.json" | cut -d' ' -f1)" = "$4"
if [ "$6" = --with-backend ]; then
    test "$(sha256sum "$stage/remarkable-wiki/backend/entry" | cut -d' ' -f1)" = "$5"
    chmod 755 "$stage/remarkable-wiki/backend/entry"
    "$stage/remarkable-wiki/backend/entry" --check-folders
fi
if pgrep -f '[/]tmp/remarkable-wiki.sock' >/dev/null; then echo 'Close Wikipedia first.' >&2; exit 1; fi
pid=$(systemctl show xochitl -p MainPID --value)
if grep -F "$target/resources.rcc" "/proc/$pid/maps" >/dev/null; then exit 1; fi
sha256sum -c "$backup/state.sha256"
sha256sum -c "$backup/preserved.sha256"
{ systemctl show xochitl -p MainPID -p DropInPaths -p NRestarts; findmnt -no OPTIONS /; } > "$backup/runtime-staged.txt"
cmp "$backup/runtime-before.txt" "$backup/runtime-staged.txt"
(cd "$stage/remarkable-wiki" && sha256sum manifest.json resources.rcc backend/entry icon.png > SHA256SUMS)
rollback() {
    if [ -d "$backup/previous-app" ]; then
        [ ! -d "$target" ] || mv "$target" "$stage/failed-app"
        mv "$backup/previous-app" "$target"
    fi
}
trap rollback EXIT HUP INT TERM
mv "$target" "$backup/previous-app"
mv "$stage/remarkable-wiki" "$target"
(cd "$target" && sha256sum -c SHA256SUMS)
sha256sum -c "$backup/preserved.sha256"
sha256sum -c "$backup/state.sha256"
systemctl is-active --quiet xochitl
{ systemctl show xochitl -p MainPID -p DropInPaths -p NRestarts; findmnt -no OPTIONS /; } > "$backup/runtime-after.txt"
cmp "$backup/runtime-before.txt" "$backup/runtime-after.txt"
trap - EXIT HUP INT TERM
REMOTE
scp -O "${opts[@]}" "root@$host:$backup/runtime-before.txt" "root@$host:$backup/runtime-after.txt" "root@$host:$backup/state.sha256" "root@$host:$backup/preserved.sha256" "root@$host:/home/root/xovi/exthome/appload/remarkable-wiki/SHA256SUMS" "$receipt/"
printf 'App update installed (%s). Backup and receipts: %s\nRefresh AppLoad and reopen Wikipedia. No editor restart performed.\n' "$mode" "$receipt"
