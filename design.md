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
and download states. `search()` snapshots the submitted query/language and
clears input focus before starting work. Draft query/language and committed
results are separate: editing never clears the results. Only a matching
successful response replaces the list and resets pagination; errors,
cancellation and stale responses preserve it. The clipped `ListView` remains
visible and scrollable with the keyboard open. Input uses `readOnly` during
work rather than disabled/re-enabled focus transitions. Keyboard opening is an
explicit input tap/button action, never a side effect of focus restoration.
`download()` sends the result set's original language, even if the user has
since changed the language selector. Once a PDF is complete, it calls the stock
`DocumentImporter.importFromUrls([fileUrl], "")`. Completion is acknowledged
only by matching native importer signals, not by a successful download alone.
Import-in-progress persists separately so closing mid-import never triggers an
automatic duplicate import. A timeout reports uncertainty, not false success.

`scripts/build.sh` produces a static arm64 backend and a binary Qt resource.
The AppLoad manifest loads those without any new shared library or QMD patch.
Installation is isolated to the new app directory after model/firmware/hash
checks. Pro and Move qualification records are independent.

`scripts/update-pro-ui.sh` handles UI-only updates on the exact qualified Pro.
It refuses an active app, verifies model/build/editor hash, archives app+state
and verifies an off-device copy, then stages a copy of the installed app with
only its manifest/resource replaced. A guarded two-rename swap retains the old
folder for rollback. State, backend and icon hashes and editor runtime must
stay unchanged. It does not deploy a rebuilt backend or restart the editor.

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
cover source-matched import callbacks and both display layouts. The user has
now confirmed end-to-end use; the device log records native import completion
at 11:17:15 on October 1. The native import does not run from CLI diagnostics.
No library entry was created by the deployment or its network tests.

The v0.1.1 regression suite covers keyboard-visible results, explicit Enter
submission, no focus-triggered reopening, failed/cancelled/stale searches and
language-correct downloads from retained results. Desktop screenshots verify
results remain readable above the keyboard; physical acceptance of this new
keyboard behavior remains distinct from the accepted v0.1.0 import flow.
UI-only transaction `wiki-ui-20261001T112545Z` installed v0.1.1 on Pro with
unchanged backend/icon/state hashes, PID 861536, zero restarts, identical
drop-ins and read-only root. The dated playbook log records payload hashes and
both backup locations. Move was not modified.
