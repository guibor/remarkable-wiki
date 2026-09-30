# Design

## Modules

`internal/wiki` owns Wikimedia-only HTTPS URLs, bounded REST search responses,
PDF content checks, cancellable downloads and app-owned persistence. `Search`
normalizes plain-text results. `Download` streams to an exclusive temporary file,
checks PDF signature/size, then atomically publishes it under a safe name.
`Store` records per-language/article status without touching notebook files.

`cmd/wiki-backend` implements AppLoad's two-packet SOCK_SEQPACKET protocol.
Network operations run outside the UI. Request IDs prevent stale results from
replacing new state. Only one operation runs at a time; cancellation interrupts
HTTP. Backend never imports or writes library files itself.

`qml/Main.qml` hosts the search/results, touch keyboard, English/Hebrew selector
and download states. Once a PDF is complete, it calls the stock
`DocumentImporter.importFromUrls([fileUrl], "")`. Completion is acknowledged
only by matching native importer signals, not by a successful download alone.
Import-in-progress persists separately so closing mid-import never triggers an
automatic duplicate import. A timeout reports uncertainty, not false success.

`scripts/build.sh` produces a static arm64 backend and a binary Qt resource.
The AppLoad manifest loads those without any new shared library or QMD patch.
Installation is isolated to the new app directory after model/firmware/hash
checks. Pro and Move qualification records are independent.

## Boundaries

No md-server, API credentials, web listener, document mutation, native pointers,
stock binary edits, or boot/startup service. Wikipedia receives search terms and
article requests. Imported PDFs can sync through the user's existing normal
reMarkable sync, which this application neither bypasses nor disables.

## Verified build / deployment boundary (2026-10-01 Israel time)

The Pro app-directory install preserves editor PID861536, runtime drop-ins,
zero restart count and read-only root. The installed static binary successfully
searched and downloaded a complete Earth PDF directly from Wikipedia. Linux
protocol socket tests pass independently of the editor. Desktop QML checks
cover source-matched import callbacks and both display layouts, but real
DocumentImporter invocation/acceptance still needs an actual app interaction.
The native import does not run from CLI diagnostics. No library entry was
created by the deployment or its network tests.
