# Initial Paper Pro installation

User requested a separate app and repo to search Wikipedia and obtain PDFs on
the tablet, preferably without md-server. Both public endpoints were confirmed
working from the Pro; no private-server fallback was added.

## Source and interface checks

- MediaWiki REST search `/w/rest.php/v1/search/page` and PDF
  `/api/rest_v1/page/pdf/{title}` documented by MediaWiki and probed live.
- AppLoad protocol/manifest inspected at pinned0.6.0 commit
  `7ec0830c97570bf5c607f3f458ea78edfa03e5a3`.
- Stock3.29.0.148 MainView.qml uses
  `DocumentImporter.importFromUrls(urls, parentId)`, and the target binary
  contains DocumentImporter/imported/failed/importFromUrls metadata. This is
  evidence of API presence, not proof of this app's completed native import.
- UI uses standalone AppLoad resources and a static backend. No DSO/QMD added.

## Tests

- Go HTTP/download/history tests and race detection pass; go vet passes.
- Nine Qt Quick test cases (including setup/cleanup) pass. Screenshots inspected
  for search/keyboard and results. Both layouts load with mocks.
- Three isolated SOCK_SEQPACKET tests pass on the real Pro: UTF-8/empty round
  trip, oversized header rejection and truncated body rejection.
- Installed backend `--search Earth` returned15 results directly on the tablet.
- Installed backend `--download Earth` saved a complete4,469,762-byte PDF under
  the diagnostic staging directory; native library import was not called.
- Qt needed unsandboxed CPU detection and Go's external linker on this Mac.
  These are local build-tool constraints, not device changes.

## Deployment receipt

Local date2026-10-01; UTC installer ID `wiki-20260930T222638Z`.
Ferrari, version20260911125116 / OS3.29.0.148, trusted SSH host key, stock editor
SHA256 `4f433281c71a29d07921665b4724420735f3c88aceb431067f3a432b3f89f6a4`.

Installed only `/home/root/xovi/exthome/appload/remarkable-wiki` from a newly
staged, checksummed directory. The target did not exist before this install.

| Payload | SHA256 |
| --- | --- |
| manifest.json | `87976ae29d746b1eb7003cb418b76665e98c3403fd49ddb302f37632c891171a` |
| resources.rcc | `bdbafecc04e9f83e400722815a83b9bad5146235eff7f628186391cbf3716809` |
| backend/entry | `b83034022d22279489cb9fec86c6c23db964faad03a314bab1414854044fd3ad` |
| icon.png | `96579ab4418365917f03c5898653368265883b5ba1fb612278362403a6aecf7f` |

Before/after: MainPID861536, NRestarts0, identical three runtime drop-ins,
including Companion20260927T183500Z-1; root `ro,relatime`. No editor restart,
settings change, existing app replacement, service or library-file edit.

## Acceptance still pending

User opens AppLoad, refreshes the list and opens Wikipedia. Check the screen,
keyboard, a search, Download and actual `Added to My files` native receipt; then
open the document. Until then do not equate network success with library
insertion or physical acceptance. Move is not installed or qualified.
