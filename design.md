# Design

## Reading first

The app fills the gap between finding an article and reading it as a native
document. It deliberately ends at PDF import: reading, highlighting and
annotation belong in the device's own reader, not an embedded browser. The
Reddit draft leads with this product principle rather than implementation
details or keyboard-fix release notes.

## Modules

`internal/wiki` owns Wikimedia-only HTTPS URLs, bounded REST search responses,
PDF content checks, cancellable downloads and app-owned persistence. `Search`
normalizes plain-text results. `Download` streams to an exclusive temporary file,
checks PDF signature/size, then atomically publishes it under a safe name.
`Store` records per-language/article status without touching notebook files.

`internal/wiki/folders.go` adds read-only folder metadata enumeration. Only
CollectionType entries with a complete non-deleted/non-trash ancestry qualify.
`ListFolders` builds readable nested paths and disambiguates duplicate names;
`ResolveDestination` checks a stable folder UUID, including again immediately
before native import. `SetDestination` atomically saves the app-owned preference
and reverts it in memory on failure. Existing state defaults to My files.
Each download record snapshots its destination; later preference changes never
move existing PDFs or retarget an in-progress import. No notebook content is read.

`cmd/wiki-backend` implements AppLoad's two-packet SOCK_SEQPACKET protocol.
Network operations run outside the UI. Request IDs prevent stale results from
replacing new state. Only one operation runs at a time; cancellation interrupts
HTTP. Backend never imports or writes library files itself.

`qml/Main.qml` hosts the search/results, native input-method integration, English/Hebrew selector
and download states. `scheduleSearch()` debounces edits/language changes by
500 ms, requires two characters, and cancels and invalidates older searches
immediately, before the next request. IME composition waits until committed.
`search(automatic)` snapshots the submitted query/language. Automatic calls
keep keyboard/focus; explicit Search/Enter closes the keyboard and flushes the
timer. A matching in-flight query is not duplicated. `stopSearch()` sends cancel
before advancing the request ID, so late results/errors cannot repaint the UI.
`searching` distinguishes background search from `controlsLocked` transfer/
import/history work. Input, keyboard, paging and existing download buttons stay
usable during search; selecting a result or folder stops the search/timer first.
There is one protocol operation at a time. Draft query/language and committed
results are separate: editing never clears the results. Only a matching
successful response replaces the list and resets pagination; errors,
cancellation and stale responses preserve it. The clipped `ListView` remains
visible and scrollable with the keyboard open. Input uses `readOnly` during
non-search work rather than disabled/re-enabled focus transitions. Keyboard opening is an
explicit input tap/button action, never a side effect of focus restoration.

v0.3.1 removes `Keyboard.qml` and its resource entry. `showKeyboard()` focuses
the real TextInput and calls `Qt.inputMethod.show()`; `hideKeyboard()` releases
focus and calls hide. `closeApp()` hides before closing. Submit/download/folder/
Open routes explicitly dismiss it, while automatic searches never do. The
read-only `keyboardOpen` follows system visibility, including native dismissal.
`keyboardInset` maps the system keyboard rectangle from window coordinates into
the app's local coordinate system, so AppLoad scaling is respected. The main
layout's bottom margin reserves the overlap. A window already resized above the
keyboard or a zero rectangle does not get a second margin. No hardcoded keyboard
height, overlay keyboard, global language write, or native keyboard-window
creation. `inputMethod` defaults to Qt.inputMethod and is injectable for desktop
tests only. Native TextInput owns text insertion, selection, backspace and IME
composition; no app glyph or manual deletion path remains. The language button
is labelled Wiki: EN / Wiki: עברית and only selects the Wikipedia site. Native
layouts follow the tablet's existing settings. Hebrew string handling is tested;
availability of a Hebrew system layout is not claimed from a desktop mock.

v0.3.2 fixes a synchronous binding transition missed by the initial native mock.
`controlsLocked = (busy && !searching) || importing || historyPending` feeds
TextInput.readOnly. QML reevaluates it between JavaScript assignments: setting
busy before searching briefly disabled editing and could dismiss the native
IME. Search now sets searching first, then busy; stopSearch and user cancellation
clear busy first, then searching. Results/errors already used the safe order.
Tests observe every readOnlyChanged signal, not just the final flag, and emulate
native dismissal on read-only. No keyboard reopen timer or focus-forcing retry:
intentional native keyboard closure remains respected.

`download()` sends the result set's original language, even if the user has
since changed the language selector. Once a PDF is complete, it calls the stock
`DocumentImporter.importFromUrls([fileUrl], destinationId)` (empty ID means
My files). The folder picker is separate from Wikipedia results, preserves
them, and closes only after the preference is saved. Completion is acknowledged
only by matching native importer signals, not by a successful download alone.
Import-in-progress persists separately so closing mid-import never triggers an
automatic duplicate import. A timeout reports uncertainty, not false success.

The transfer panel distinguishes download, native import, success and failure.
The matching native `imported` signal confirms success but does not expose a
usable `.id`: its argument is an opaque `std::shared_ptr<Document>`. v0.2.0
incorrectly assumed a QML entry wrapper, which hid the Open button on device.
v0.2.1 collects candidate IDs from the native Library `entryAdded` and
`entryImported` signals during the import. `MatchImportedPDF` verifies the
candidate's native parent and PDF SHA256 against the app-owned source, rejects
ambiguity, and persists the verified document ID. No title/time guessing or
library writes. The cached source is removed only after this verification.
The Open button stays visible after native success while bounded retries wait
for the library ID/file; it enables when resolved and offers retry on timeout.
`openSaved()` waits for history/identity verification, then uses the
existing stock main view's `windowNavigator.open` route with that exact ID.
`readerHost()` performs a bounded visual-tree lookup for the stock main view
and AppLoad launcher. Opening hides the launcher and closes only this app; it
does not patch navigation or restart anything. A missing route leaves the PDF
saved and tells the user its location rather than guessing by title.

`refreshSelected()` adds an explicit Refresh article action to completed or
already-imported article cards, including legacy records without native IDs.
It snapshots the original article key/language, independently of search-box
edits, and uses the currently selected save destination. `Record.BlocksDownload`
still blocks normal duplicate downloads and all uncertain/in-progress imports;
only an explicit refresh bypasses completed-history suppression. `DownloadFresh`
uses the same validated atomic download path as `Download` but bypasses the
app-owned cache, making a new Wikimedia request. Server-side rendering/caching
remains Wikimedia's responsibility. Failed downloads leave the previous cache
and history intact; only a successful validated download replaces the app's
latest per-article record. It is imported through the normal native pipeline as
a new document: no existing PDF, annotation or library metadata is overwritten.
The latest successful import becomes the Open PDF target. v0.2.2 requires
backend protocol 4 so UI-only installation cannot silently ignore refresh.
v0.3.0 uses a quiet `WikiButton` variant: no border/background, underlined smaller
text and a generous touch target. Open PDF remains the large filled primary
action. The backend protocol stays at 4; this release is UI-only over v0.2.2.

`scripts/make-reddit-demo.sh` trims the owner's supplied recording into
`docs/media/wikipedia-reddit-demo.mp4` plus a looping README GIF from the
October 2 v0.3.2 recording. Five chronological extracts show live search,
download/import, Open PDF, and native reading/highlighting. Typing and selection
run at 1.25x; static waits are cut. The full native keyboard is retained; later
shots crop/pad only the unrelated screen-sharing footer. No synthetic UI or
audio is added. The recording's other reader add-ons are not Wiki features.
The Reddit announcement uses a native video attachment for feed visibility,
with Self-Promotion flair and the public MIT repository's installation link.
The media is public on GitHub; the Reddit copy is currently a saved draft,
pending the browser's file-upload permission. Saving is not publication.

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
For v0.2.0, `scripts/update-pro.sh` explicitly opts into a matching backend
update through the same guard/backup transaction. `backendProtocol` in the
manifest prevents a UI-only update from pairing the folder UI with an old
backend. The staged backend's `--check-folders` diagnostic performs read-only
enumeration before activation. State/icon/runtime remain unchanged by install.

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

v0.2.0 transaction `wiki-ui-20261001T151422Z` updated this app's UI/backend
together. The staged backend found 35 live folders read-only. Before/after
state hash, icon, editor PID/restarts/drop-ins and root mode match. All 19 UI
checks and Go/race/vet pass; actual chosen-folder import and quick-open remain
physical acceptance steps. See the folder/open deployment log for hashes.

v0.2.1 transaction `wiki-ui-20261001T154340Z` installed the native-ID fix with
app history/icon unchanged, editor PID 861536, zero restarts, identical drop-ins
and read-only root. Twenty Qt checks and Go/race/vet passed. Real native-ID
resolution and the physical Open action remain separate acceptance gates.

v0.2.2 transaction `wiki-ui-20261001T154740Z` installed explicit refresh with
the same editor PID/restarts/drop-ins/root mode and unchanged app state/icon.
Twenty-three Qt checks and Go/race/vet pass; the desktop ready-card render shows
Open PDF as the primary action and Download again as a separate secondary row.
No refresh/import was triggered by deployment; physical acceptance is pending.

The owner's October 1 recording subsequently confirms v0.2.2 refresh/import/Open
into Machine learning; the device log confirms native ID verification at
17:57:55.564 (device log time). Old annotations/chosen folders were not inspected.
v0.3.0 UI-only transaction `wiki-ui-20261001T180343Z` preserves the same backend,
state/icon, PID 861536, zero restarts, drop-ins and read-only root. All 31 Qt
checks and Go/race/vet pass. Live-search physical QA is next, independent of the
older demo's confirmed Open flow. No Move deployment or public posting.

v0.3.1 UI-only transaction `wiki-ui-20261001T203935Z` installs native-keyboard
integration. Backend/state/icon hashes and editor runtime match their preimages
(PID861536, zero restarts, same drop-ins/read-only root). Thirty-six Qt checks
and Go/race/vet pass. Desktop layout with a simulated keyboard rectangle was
inspected; the blank reserved area is not a rendering of the actual keyboard.
Physical native keyboard/language/Enter/backspace acceptance remains next.

v0.3.2 `wiki-ui-20261001T204553Z` installs the transient-readOnly correction.
All 38 Qt checks and Go/race/vet pass; the new regression failed before the fix.
Backend/state/icon and runtime preimages match (PID861536, restarts0, same
drop-ins/read-only root). Physical keyboard persistence still needs recheck.

The owner's October 2 recording now confirms keyboard persistence during live
search, completed download/import and Open into Jacques Hadamard, followed by
reading/highlighting. This is flow-specific acceptance, not Move qualification
or proof of every keyboard layout/folder option.
