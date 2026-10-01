# Native keyboard disappears during live search — v0.3.2

The owner's 23:42:36 recording shows the keyboard hiding as automatic search
starts, reopening when tapped, then hiding again after further typing. Continue
on main; no publication or runtime-wide changes requested.

## Reproduction and cause

Search set busy=true before searching=true. Because controlsLocked depends on
busy && !searching, QML bindings saw an intermediate true value and briefly set
TextInput.readOnly=true. stopSearch and the Cancel button had the inverse pulse
when clearing searching before busy. A native IME can dismiss immediately when
its input stops being editable, even if readOnly is restored in the same JS call.

New regression on the unmodified v0.3.1 implementation failed: observed two
readOnlyChanged events on automatic search start instead of zero. Prior tests
checked only final flags and used a mock that did not react to readOnly changes.
The new fixture models native dismissal and observes all intermediate states.

## Fix

Set searching before busy on search start; clear busy before searching on both
cancellation paths. Success/error responses were already in the safe order.
No new timer, native keyboard recreation or forced reopening. A second test
checks that intentionally dismissing the system keyboard stays respected.
Only UI resource/manifest change; backend protocol remains 4.

## Verification

After the fix, all 38 Qt checks pass, including the previously failing pulse
test, success/error/cancel transitions and intentional keyboard dismissal.
Go/race/vet pass. Pre-fix output retained in `.cache/keyboard-pulse-before.log`;
full passing output in `.cache/keyboard-pulse-after.log`. Native display/typing
was visible in the recording, but persistence after this fix still needs a
physical recheck. LAN scan found none; trusted pinned address answered as
Ferrari/build20260911125116, app closed, PID861536/NRestarts0.

## Deployment

UI-only transaction `wiki-ui-20261001T204553Z` completed. Verified backups and
receipts at `.cache/receipts/wiki-ui-20261001T204553Z/` and device directory
`/home/root/.codex-backups/wiki-ui-20261001T204553Z/` (retains previous-app).

Installed hashes:
- manifest: `a9b547372e36ab79eeec899a9ffa36bdb635ff1d19c680d308865f01a95b3bf2`
- resource: `abda54c4966b459997f838b14b484c5381107004450cb9003ef1c25996587229`
- unchanged backend: `fa3c2fbd666cb17d7011d3cbd47da4ff84c08dfa3873c1cf5ef605258a037abb`
- unchanged state: `13947061c196a83f2ee038481010d290c0421516a03658cd599f4d829404fe8d`

Icon unchanged. Runtime before/after: PID861536, restarts0, identical drop-ins,
read-only root. No firmware/global keyboard changes or restart. Move untouched.
Physical persistence recheck remains pending.
