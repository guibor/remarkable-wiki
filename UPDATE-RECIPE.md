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

v0.2.2 adds explicit Download again with **backendProtocol 4**. Use the same full
app update while Wikipedia is closed. Preserve state and cache. Check that an
already-imported article offers refresh, an uncertain import does not, and a
refresh imports a new copy into the current destination without altering the
old copy/annotations. Open PDF must target the newly imported copy.

v0.2.1 corrects the missing Open PDF button using native library-ID signals and
source-PDF hash verification; it requires **backendProtocol 3**. Use the full
`scripts/update-pro.sh VERIFIED_IP` path while Wikipedia is closed, not the
UI-only script. Preserve state and any unresolved cached PDFs. After installation,
download a new article and require both `Wiki: saved PDF identity verified; Open
PDF enabled` in the app log and a physical tap that opens the right document.
The older root-import success and desktop mock do not qualify this action.

For **v0.2.0 folder destinations and Open PDF**, run the tests/build and close
Wikipedia, then `RM_SSH_KEY=... bash scripts/update-pro.sh VERIFIED_IP`.
This explicitly updates the static backend with the UI using the same verified
backup/rollback procedure. The old app and all history/preferences are retained.
The staged backend must pass `--check-folders` read-only enumeration before
the swap. The native `parentId` contract is confirmed in stock 3.29.0.148
MainView.qml (drag/drop import), and opening follows its existing
`windowNavigator.open("legacydevice/window/main", {documentId: id})` route.
Check a real chosen-folder import and Open PDF separately after installation.
The manifest's `backendProtocol: 2` prevents an accidental UI-only upgrade
against an old backend.

For the v0.1.0 → v0.1.1 **UI-only** update on the existing qualified Pro, run
`bash scripts/test.sh`, close Wikipedia, then
`RM_SSH_KEY=... bash scripts/update-pro-ui.sh VERIFIED_IP`.
The script copies the installed app into staging, changes only manifest/resource,
and preserves backend/icon/history. Its verified app+state archive is retained
both under `.codex-backups/wiki-ui-TIMESTAMP/` and local `.cache/receipts/`.
The previous app is retained at `previous-app` in that remote backup folder.
It refuses an active backend/mapped resource and verifies unchanged runtime
and state around the swap. Physical UI acceptance is still a separate step.
For backend changes or later firmware use the complete procedure below.

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
