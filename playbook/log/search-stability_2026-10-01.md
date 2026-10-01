# Stable search results and publishing preparation

The owner confirmed that Wikipedia works end-to-end, but reported results
appearing/disappearing with the touch keyboard open. The native runtime log
also records `Wiki: UI ready; importer=true` at 11:15:08 and
`Wiki: native import completed` at 11:17:15 on October 1. This supersedes the
initial-installation log's pending native import acceptance.

## Root cause and fix

The results column was explicitly hidden while `keyboardOpen` was true.
Disabling/re-enabling the focused query field during a search could restore
focus and reopen the keyboard, hiding results again. There was no actual
live/fuzzy search in our frontend; explicit submission already existed, but
the visibility/focus coupling made it appear unstable.

v0.1.1 keeps a scrollable results list visible regardless of keyboard state.
Typing, focus restoration and language changes do not clear it. Search/Enter
snapshots the draft query/language, closes the keyboard intentionally, and
replaces results only when a matching successful response arrives. Failed,
cancelled and stale requests preserve the last list and page. Downloads from
retained results always use their original Wikipedia language.

## Validation and deployment boundary

Go race tests and vet pass. All 14 desktop Qt checks pass, covering keyboard/focus,
Enter/touch submission, delayed/stale/error/cancel transitions and result
language. Screenshots inspected with results both above an open keyboard and
in the full-height results view. Actual native import was accepted on v0.1.0;
the new interaction still needs a physical v0.1.1 check.

The new UI-only updater preserves the installed backend/icon/state, verifies
an app+state backup off-device, retains the previous app for rollback, and
requires unchanged editor PID/drop-ins/restarts/root mode. No new DSO, QMD,
boot/service edit, native import test document or editor restart is involved.

Deployment completed after an initial SSH timeout resolved. Transaction
`wiki-ui-20261001T112545Z` on verified Ferrari / OS 3.29.0.148 / build
20260911125116. The app was closed; the UI-only updater verified the off-device
backup before replacing the installed app directory. Manifest version is 0.1.1.

| File | Installed SHA256 |
| --- | --- |
| manifest.json | `700c3e48bbb1588a2740b285ea2ffe886795904a19575e959db28ead73b9afde` |
| resources.rcc | `fc42bb303745a6714984b316e8929ad795cf703a2864582fb89a416461713993` |
| backend/entry (unchanged) | `b83034022d22279489cb9fec86c6c23db964faad03a314bab1414854044fd3ad` |
| icon.png (unchanged) | `96579ab4418365917f03c5898653368265883b5ba1fb612278362403a6aecf7f` |

State SHA256 stayed
`b66be8ae729a0a9d77f394eae79c5c9a852ba76135430ccb180366b01a25d698`.
Runtime stayed PID 861536 / zero restarts / identical three drop-ins / root
`ro,relatime`. Local verified archive and receipts:
`.cache/receipts/wiki-ui-20261001T112545Z/`; remote backup and previous app:
`/home/root/.codex-backups/wiki-ui-20261001T112545Z/`.
Move was not changed. Physical v0.1.1 keyboard acceptance remains pending.

## Documentation and publication

README now has explicit search semantics, prerequisites, source installation,
UI-only upgrades, troubleshooting and honest per-device qualification.
`docs/reddit-draft.md` is an unpublished draft in the owner's first-person
voice. Repository remains private with no public release. A public announcement
requires the owner's visibility/license decision and current subreddit-rule
review; no post or public-release action was taken.
