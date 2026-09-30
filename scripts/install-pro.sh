#!/bin/bash
# Initial-only installation. No stock/UI/runtime/settings changes or restart.
set -Eeuo pipefail
cd "$(dirname "$0")/.."
host=${1:?verified Paper Pro SSH host/IP required}
key=${RM_SSH_KEY:-$HOME/.ssh/id_ed25519_remarkable_new}
opts=(-i "$key" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=5)
id=wiki-$(date -u +%Y%m%dT%H%M%SZ)
stage=/home/root/.codex-staging/$id
target=/home/root/xovi/exthome/appload/remarkable-wiki
mkdir -p .cache/receipts
ssh "${opts[@]}" "root@$host" 'set -e
test "$(tr -d "\000" </sys/firmware/devicetree/base/model)" = "reMarkable Ferrari"
test "$(cat /etc/version)" = 20260911125116
test "$(sha256sum /usr/bin/xochitl | cut -d" " -f1)" = 4f433281c71a29d07921665b4724420735f3c88aceb431067f3a432b3f89f6a4
test -d /home/root/xovi/exthome/appload
test ! -e /home/root/xovi/exthome/appload/remarkable-wiki
systemctl is-active --quiet xochitl
systemctl show xochitl -p MainPID -p DropInPaths -p NRestarts
findmnt -no OPTIONS /' > ".cache/receipts/$id-before.txt"
ssh "${opts[@]}" "root@$host" "mkdir -m 700 '$stage'"
scp -O -r "${opts[@]}" dist/remarkable-wiki "root@$host:$stage/"
ssh "${opts[@]}" "root@$host" "set -e
cd '$stage/remarkable-wiki'
sha256sum -c SHA256SUMS
test ! -e '$target'
mv '$stage/remarkable-wiki' '$target'
systemctl is-active --quiet xochitl
systemctl show xochitl -p MainPID -p DropInPaths -p NRestarts
findmnt -no OPTIONS /" > ".cache/receipts/$id-after.txt"
printf 'Installed new AppLoad directory only. Receipts: %s\nOpen AppLoad and tap its refresh icon, then Wikipedia.\n' "$id"
