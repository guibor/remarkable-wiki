# reMarkable Wiki — Engineering Playbook

> Single source of truth for how this project is built.

## Architecture

- QML frontend, Go network/backend worker, AppLoad's documented local protocol.
- Native DocumentImporter imports completed PDFs; no direct library writes.
- Wikipedia REST search and PDF service, AppLoad, Qt Quick. No credentials.

## Repository map

- `qml/`, `cmd/`, `internal/`, `packaging/` contain app source.
- `scripts/` builds/tests and performs guarded app-directory-only installation.
- `.cache/` and `dist/` are ignored outputs, not source.

## Conventions

- Go standard library plus x/sys; Qt Quick for native text/RTL rendering.
- Unit tests mock HTTP and disk; QML mock tests prove frontend state transitions.
  Actual native import and tablet interaction have separate acceptance receipts.
- Stage/hash-verify a new isolated AppLoad folder; never overwrite other apps,
  restart xochitl, change QMDs or remount the root filesystem for installation.
- Preserve Pro/Move separation and app-owned state. Read prd.org and design.md.

## Open technical questions

- Revalidate the native import API and exact runtime on each firmware target.
