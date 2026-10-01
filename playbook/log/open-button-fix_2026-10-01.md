# Missing Open PDF button

User reported that the ready-to-read PDF had no clickable Open action.
The Pro is running v0.2.0 / firmware 3.29.0.148 with editor PID 861536 and
zero restarts. The native app log confirms successful import at 15:36:59.776.

## Cause

v0.2.0 read `document.id` from the DocumentImporter imported callback. Static
Qt metadata decoded from the exact qualified stock executable proves its
signature is `imported(std::shared_ptr<Document>, std::shared_ptr<Collection>,
QUrl)`. This is not the QmlEntryWrapper returned by Library.entryForId.
The code silently converted the missing id to an empty string, then hid the
Open button. The desktop test incorrectly supplied `{id: ...}` and missed it.

The same exact metadata confirms Library signals:
`entryAdded(entry::Id)` and `entryImported(QString visibleName, entry::Id)`.
No editor/runtime modification was used to inspect those contracts.

## v0.2.1 fix

- Capture native library ID notifications during our own import, regardless of
  whether they precede or follow its source-matched success callback.
- Keep Open PDF visible after success while resolving the identity.
- Backend verifies candidate parent/type/non-deleted state and exact PDF SHA256
  against the cached source. Ignore unrelated IDs; reject ambiguous duplicates.
- Save the verified native ID in our app-owned history and only then remove our
  cached source. Existing verified records can reopen without another import.
- Use bounded delayed retries for native notification/filesystem ordering. Keep
  the saved PDF intact and offer retry if its identity cannot be verified.
- Old v0.2.0 imports with no stored ID remain in the user's library; do not
  guess by title or import a duplicate to manufacture an Open action.

20 Qt checks pass, including an opaque callback fixture, late native IDs,
token filtering and the actual button state. Go/race/vet pass; identity tests
cover same-title wrong bytes, exact bytes under another title, duplicate
notifications, wrong parent, deleted PDFs, invalid IDs and ambiguity.

## Deployment status

Built but not installed. Wikipedia remained open at backend PID 1305351 on
the final read-only check. The user was asked to close only Wikipedia and
leave the Pro awake; no loaded resource or running app was overwritten.
No device mutation or editor restart occurred in this turn. Next: guarded
full app update, then real ID-resolution and physical Open acceptance.
