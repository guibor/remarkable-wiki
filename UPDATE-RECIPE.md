# Update recipe

## Invariants

- App root: `/home/root/xovi/exthome/appload/remarkable-wiki/`.
- State: `/home/root/.local/share/remarkable-wiki/`; preserve independently per device.
- No QMD, editor shared library, system service, cloud credentials or md-server endpoint.
- Recheck model, firmware, SSH host key, stock hashes and installed AppLoad before
  every deployment. Pro evidence never qualifies Move automatically.
- Import calls must remain the native QML `DocumentImporter.importFromUrls`
  path. Never replace it with raw `.metadata`/`.content` writes on a live editor.

## First installation

Run tests and build. `scripts/install-pro.sh VERIFIED_IP` stages a new app under
`.codex-staging`, pins Ferrari / version20260911125116 / stock editor SHA256
`4f433281c71a29d07921665b4724420735f3c88aceb431067f3a432b3f89f6a4`, checks
the bundle and atomically moves it to its previously absent AppLoad directory.
Receipts capture PID/drop-ins/restarts/root mode. No restart is performed.
User refreshes AppLoad's list and opens Wikipedia.

## Existing app / later OS

1. Obtain a fresh runtime/firmware inventory and read that device's maintenance
   knowledge base. Stop on mismatched firmware; do not weaken the old installer.
2. Close Wikipedia normally and ensure its backend is no longer running. Never
   replace an actively registered resource bundle or interrupt an import.
3. Back up the app directory and app-owned state; copy and verify the archive
   off-device. Do not restore old state over newer import history.
4. Stage and hash-check the rebuilt bundle. Requalify native import signals and
   the `file:` URL/parent argument against this firmware's stock resources.
5. Atomically swap only this app directory, retaining the old folder outside
   AppLoad for rollback. Preserve the state directory untouched.
6. Refresh AppLoad and test search, PDF download, native import, opening the PDF,
   and closing the app. Compare editor PID and settings; no restart is expected.

## Rollback / uninstall

Close Wikipedia. Move only its app folder out of AppLoad and refresh the list.
Retain state and downloaded PDFs until deciding what to keep. Imported library
documents are independent and must not be deleted by uninstall. Restore the
previous app folder only while the app is closed. No firmware-root change.
