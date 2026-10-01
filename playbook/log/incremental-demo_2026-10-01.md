# Incremental search, quiet refresh, and Reddit demo

Continue on main as previously requested. User authorized implementation and
trimming their October 1 20:57:13 recording for the Reddit draft, not publication.

## UI v0.3.0

- Search after 500 ms of paused input, at least two characters. Explicit
  Search/Enter flushes debounce, accepts one letter, and hides the keyboard.
- An edit/language switch immediately cancels and invalidates the active request.
  Responses received during the debounce gap are already stale. Old results
  remain until the current request succeeds; failures/cancellation preserve them.
- Background searches do not lock keyboard/input/results/paging. Selecting an
  old result or opening folders stops search/timer before starting that action.
  Downloads/import/history verification still lock conflicting actions.
- Refresh article becomes a smaller, underlined, borderless secondary action;
  Open PDF remains the prominent filled button. Backend remains protocol 4.

## Evidence and media

The provided video shows Machine learning already imported, explicit refresh,
download/import, the ready card, then Open into that article in the native
reader. At device log time 17:57:54.994 native import completed; 17:57:55.564
confirmed saved PDF identity verified/Open enabled. This closes the prior
physical Open acceptance gap, but does not inspect old annotations or folders.

`docs/media/wikipedia-reddit-demo.mp4`: 19.8-second H.264, 1038x1310, 15 fps,
no audio, metadata removed. Source intervals 25.5–34.5 and 39–50.5 seconds,
original speed; cropped off screen-sharing footer. Reviewed contact sheet.
Source untouched. Reproduction script lives in scripts/make-reddit-demo.sh.
Draft links the clip and explicitly distinguishes older v0.2.2 footage from
new live search/refresh styling. No post or repository visibility change.

## Validation / deployment

31 Qt checks, Go race/unit tests and vet pass. Includes debounce, immediate
stale invalidation, keyboard continuity, download preemption, language changes,
empty/one-character input, Enter deduplication, folder interruption and hierarchy.
Desktop ready-card render inspected. Pro discovered at pinned trusted address
10.100.102.101 (scan returned none); live model Ferrari/build20260911125116,
PID861536/NRestarts0; app closed.
Physical incremental-search acceptance remains separate. Move not modified.

UI-only transaction `wiki-ui-20261001T180343Z` completed successfully. Verified
off-device backup/receipts: `.cache/receipts/wiki-ui-20261001T180343Z/`.
On-device backup/previous-app: `/home/root/.codex-backups/wiki-ui-20261001T180343Z/`.

Installed SHA256:
- manifest: `d2079f4b9c0fa25b93af64c16df33e260ae020c56b563793c937ba65373c9e75`
- resource: `905407f73da241f266c8d1309f894f1b6f181810c1b65b1462c7052612e74fab`
- unchanged backend: `fa3c2fbd666cb17d7011d3cbd47da4ff84c08dfa3873c1cf5ef605258a037abb`
- unchanged state: `13947061c196a83f2ee038481010d290c0421516a03658cd599f4d829404fe8d`

Installed payload checks passed, before/after runtime matched: PID861536,
NRestarts0, identical drop-ins, read-only root. Icon/backend/state checks passed.
A supplemental SSH connection after receipt collection timed out; this does
not undo the completed/verified transaction, but no new app launch was observed.
