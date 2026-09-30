# Wikipedia, on your reMarkable

Search for an article. Tap **↓ PDF**. Read and annotate it in **My files**.

reMarkable Wiki is a standalone AppLoad app. The tablet talks directly to
Wikipedia for both search and PDF downloads—no private server, md-server,
Google Drive, API key, or desktop companion is involved.

## Use

1. Open **AppLoad**. If newly installed, tap its **refresh** icon.
2. Open **Wikipedia**.
3. Type a query using the on-screen keyboard, then tap **Search**.
4. Browse the results with the page arrows and tap **↓ PDF** beside an article.
5. Wait for **Added to My files**, then close the app and open the PDF there.

The language button switches between English and Hebrew Wikipedia and their
keyboards. Search language is remembered. The **Keyboard** button lets you
edit your query after searching. PDFs use Wikipedia's own rendering, including
its article attribution and reference sections; this app does not restyle them.

Downloads are bounded to 64 MB and 90 seconds. You can cancel network work.
Already imported articles are not automatically duplicated. If the app closes
mid-import, it asks you to check My files instead of assuming failure and
creating another copy. A failed native import can be retried using the saved
download. Successful imports remove only the app's cached source PDF.

## Compatibility and current evidence

| Target | Status |
| --- | --- |
| Paper Pro, 3.29.0.148, AppLoad 0.6.0 | App installed; direct search/download tested; physical UI/native import acceptance pending |
| Paper Pro Move | Responsive UI covered by desktop mocks; not installed or device-qualified |
| Other firmware/devices | Not yet qualified |

Installing the app **does not** install AppLoad or XOVI, replace other apps,
patch the editor, change the boot process, or restart the tablet. It uses the
existing native `DocumentImporter` interface for library insertion. That API
must be rechecked for each firmware release. There are no private native
offsets or shared-library injections in this package.

## Privacy and sync

Your selected Wikipedia site receives the query and article request over
HTTPS. No request goes to the author's server. No keys or accounts are needed.
Once imported, the PDF is a normal reMarkable document and follows your existing
cloud-sync settings. **This is not a private/non-syncing notebook feature.**

App state lives in `~/.local/share/remarkable-wiki/`, separate from the library.
Keep `state.json` across upgrades: it records language and import outcomes.
Never blindly clear an `importing` record to retry; inspect My files first.

## Build and test

Requires Go 1.22+, Qt 6 `rcc`, and `rsvg-convert`. For UI tests also install
`qmltestrunner`. The provided build defaults to Homebrew's `rcc` path; override
`RCC` on another build host.

```sh
bash scripts/test.sh
bash scripts/build.sh
```

The output is `dist/remarkable-wiki/`: an AppLoad manifest, icon, QML resource,
static Linux arm64 backend and checksums. Runtime needs no Go/Qt SDK installed
on the tablet. The native UI uses Qt already provided by the existing editor.

For a **first** install on a previously identified, supported Paper Pro:

```sh
RM_SSH_KEY=~/.ssh/your_tablet_key bash scripts/install-pro.sh VERIFIED_IP
```

The installer requires a trusted SSH host key, pins the Pro model/firmware and
stock editor hash, verifies the uploaded bundle, and refuses to overwrite an
existing installation. Read [UPDATE-RECIPE.md](UPDATE-RECIPE.md) for upgrades.

Network diagnostics, without GUI or library insertion:

```sh
backend/entry --search 'Earth'
backend/entry --download 'Earth' /tmp/wiki-diagnostic
```

The diagnostic commands use English Wikipedia. They never claim a PDF was
imported and do not alter notebook files.

## Architecture

- **QML UI:** readable results, pagination, keyboard, progress and native import.
- **Go backend:** Wikipedia HTTP requests, validated atomic downloads and history.
- **AppLoad:** local backend messaging and application lifecycle.

See [design.md](design.md), [prd.org](prd.org) and [playbook/](playbook/).

The API choices follow MediaWiki's [REST search documentation](https://www.mediawiki.org/wiki/API:REST_API/Reference)
and [PDF service documentation](https://www.mediawiki.org/wiki/Extension:ElectronPdfService).
The application format/protocol follows [AppLoad 0.6.0](https://github.com/asivery/rm-appload/tree/v0.6.0).
Not affiliated with Wikimedia or reMarkable.
