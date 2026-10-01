# Destination folders and Open PDF

User requested a saved destination-folder setting with My files as default,
then added a prominent downloading indicator and a quick-open action for the
PDF just saved. Implemented together as v0.2.0 on the existing main branch.

## Contracts

- Existing CollectionType folder metadata is read-only. No notebook content,
  raw library writes, library moves or folder creation. Deleted/trash ancestors,
  missing parents, cyclic trees and invalid IDs do not become destinations.
- Default/root destination is the empty native parent ID. UUID/path preference
  lives in the app's state; legacy state migrates in memory without discarding
  language or import records. Each download snapshots its destination.
- Stock 3.29.0.148 MainView.qml:504 passes a folder ID directly to
  `DocumentImporter.importFromUrls`. We use the same native argument, validating
  folder existence before download and before import. Missing destinations
  produce an explicit error, never a silent root fallback.
- Only source-matched native import success supplies the document ID for Open
  PDF. Download completion alone does not enable it. History acknowledgment is
  awaited (with a bounded fallback) before allowing the shortcut.
- Open uses the stock main view's existing
  `windowNavigator.open("legacydevice/window/main", {documentId: id})` route,
  found through a bounded visual-tree lookup. It hides the AppLoad launcher
  and closes Wikipedia; it never guesses a document from the title or changes
  other apps. Missing navigation leaves the saved PDF and explains where it is.
- The transfer card shows article title, network byte progress when available,
  native-import phase, and completion with the saved location and Open PDF.

## Tests

- Go race tests and vet pass. Folder tests cover nested/Hebrew/duplicate names,
  deletion/trash/missing parents/cycles, read-only enumeration, invalid IDs,
  persistence, rename, legacy defaults and returning to My files.
- 19 desktop Qt checks pass. New checks cover save acknowledgment and failure,
  results retained while choosing a folder, exact import parent, prominent
  progress, no Open before native success, source-matched document identity,
  exact native navigation arguments and missing-route fallback.
- Mock screenshots for picker, keyboard/results, downloading and ready/open
  inspected. No physical screenshot or native-opening claim from these mocks.

## Pro deployment

Transaction `wiki-ui-20261001T151422Z`, Ferrari / OS 3.29.0.148 / build
20260911125116, trusted SSH key and exact stock executable guard.
App was closed. Verified app+state archive retained locally under
`.cache/receipts/wiki-ui-20261001T151422Z/` and remotely under
`/home/root/.codex-backups/wiki-ui-20261001T151422Z/`.
The old app remains at `previous-app` in the remote backup.

The new explicit `update-pro.sh` backend+UI path shares the prior transaction
guards; `backendProtocol: 2` prevents deploying only the new UI over v0.1.x.
The staged backend's `--check-folders` found 35 live folders plus My files,
without printing private names or changing metadata/state.

| Payload | SHA256 |
| --- | --- |
| manifest.json | `de7f35950c90362d6b67559387b162896b4d0a52234e664343d19f9f81b06d0f` |
| resources.rcc | `0edc082eeaeab8faeb41ba55dbcbf2ce2d5703656f07f09e1a67b446bc3d8ae8` |
| backend/entry | `20d0f01f4ac03d1944906db029dcbef46d5f7b1c82b14082913a7ece3462560f` |
| icon.png (unchanged) | `96579ab4418365917f03c5898653368265883b5ba1fb612278362403a6aecf7f` |

State before/after SHA256
`bcf9567de80a999e661c63fdc0647b9363e6b62da56f89c568631e2a69465171`.
Editor PID 861536, NRestarts 0, same three drop-ins, root `ro,relatime`.
No restart, runtime/firmware changes, other app changes or Move deployment.

## Acceptance still pending

Refresh AppLoad and reopen Wikipedia. Choose a destination, download a new
article, confirm its native import/location, then tap Open PDF and verify the
reader opens that article. Confirm preference survives closing/reopening and
My files restores the default. Base root-import flow was already accepted by
the owner; these new physical steps must not be inferred from installation.
