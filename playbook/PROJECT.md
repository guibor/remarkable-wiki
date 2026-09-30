# reMarkable Wiki — Project Playbook

> Single source of truth for what this project should do and for whom.

## Purpose

- Problem: finding a Wikipedia article and reading its PDF without a computer.
- Users: reMarkable owners with an independently qualified AppLoad installation.
- Outcome: search on tablet, tap Download, find the PDF in My files.

## Scope

- In scope: direct Wikipedia search/PDF requests, English/Hebrew selection,
  responsive e-ink UI, native document import, clear progress/errors.
- Out of scope: md-server, API keys, notebook-file rewriting, cloud API clients,
  firmware patches, bundled browser/PDF renderer, unattended batch scraping.
- Success: Wikipedia PDF downloaded on device and accepted by the native library;
  user can open and annotate it. Network/GUI/import evidence stays distinct.

## Milestones

- Near term: Paper Pro 3.29.0.148, existing AppLoad 0.6.0, no runtime replacement.
- Next: physical search/download/open acceptance, independent Move qualification.
- Later: more Wikipedia languages and optional download history refinement.

## Open questions

- A direct PDF URL is a Wikipedia service and can be temporarily unavailable;
  report that accurately rather than silently introducing a private server.
