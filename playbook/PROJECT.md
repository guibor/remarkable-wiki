# reMarkable Wiki — Project Playbook

> Single source of truth for what this project should do and for whom.

## Purpose

- Problem: finding a Wikipedia article and reading its PDF without a computer.
- Users: reMarkable owners with an independently qualified AppLoad installation.
- Outcome: search on tablet, download to My files or a chosen folder, then
  open the newly imported PDF directly in the native reader.

## Scope

- In scope: direct Wikipedia search/PDF requests, English/Hebrew selection,
  stable incremental search, responsive e-ink UI, native document import with
  remembered destination, prominent progress/errors and a dominant quick-open
  action after native success; quiet explicit refresh preserves older copies.
- Native reMarkable keyboard and existing device keyboard settings; Wikipedia
  search-language selection is separate from keyboard-layout selection.
- Out of scope: md-server, API keys, notebook-file rewriting, cloud API clients,
  firmware patches, bundled browser/PDF renderer, unattended batch scraping.
- Success: Wikipedia PDF downloaded on device and accepted by the native library;
  user can open and annotate it. Network/GUI/import evidence stays distinct.

## Milestones

- Near term: Paper Pro 3.29.0.148, existing AppLoad 0.6.0, no runtime replacement.
- Accepted: user-confirmed end-to-end search/download/native import on Paper Pro.
- Accepted: owner's October 1 recording shows explicit refresh and Open PDF
  into the correct native document; native-ID verification confirmed in log.
- Next: incremental keyboard/results interaction acceptance, chosen-folder flow,
  independent Move qualification.
- Later: more Wikipedia languages and optional download history refinement.

## Open questions

- A direct PDF URL is a Wikipedia service and can be temporarily unavailable;
  report that accurately rather than silently introducing a private server.
