# Wikipedia, on your reMarkable

Search for an article. Tap **↓ PDF**. Read and annotate it in **My files**.

reMarkable Wiki is a standalone AppLoad app. The tablet talks directly to
Wikipedia for both search and PDF downloads—no private server, md-server,
Google Drive, API key, or desktop companion is involved.

## Use

1. Open **AppLoad**. If newly installed, tap its **refresh** icon.
2. Open **Wikipedia**.
3. Type a query using the on-screen keyboard, then tap **Search** (or press Enter).
4. Browse the results with the page arrows and tap **↓ PDF** beside an article.
   With the keyboard open, you can also swipe within the results to see more.
5. Wait for **Added to My files**, then close the app and open the PDF there.

The language button switches between English and Hebrew Wikipedia and their
keyboards. Search language is remembered. The **Keyboard** button lets you
edit your query after searching. Results stay visible while you type or toggle
the keyboard. Search/Enter submits a new query; typing alone does not search.
The small **Results for…** caption identifies the list you're seeing. A failed
or cancelled search leaves that list available to download. Switching language
does not change old results; submit again to search the other Wikipedia.

PDFs use Wikipedia's own rendering, including
its article attribution and reference sections; this app does not restyle them.

Downloads are bounded to 64 MB and 90 seconds. You can cancel network work.
Already imported articles are not automatically duplicated. If the app closes
mid-import, it asks you to check My files instead of assuming failure and
creating another copy. A failed native import can be retried using the saved
download. Successful imports remove only the app's cached source PDF.

## Compatibility and current evidence

| Target | Status |
| --- | --- |
| Paper Pro, 3.29.0.148, AppLoad 0.6.0 | End-to-end use confirmed by the owner; native PDF import confirmed in device log. v0.1.1 keyboard fix covered by UI tests; physical recheck pending |
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

## Installation from source

This is a developer-mode app, not an official reMarkable app or a stock-device
installer. You need SSH access and a separately installed, working
[XOVI](https://github.com/asivery/xovi) / [AppLoad](https://github.com/asivery/rm-appload)
setup. This repository does not install or update that foundation. Back up
your device first, and do not bypass a model/firmware mismatch in the installer.

There is no prebuilt public release yet. The repository is currently private;
these source-install instructions work for accounts with repository access.

```sh
git clone git@github.com:guibor/remarkable-wiki.git
cd remarkable-wiki
```

Requires Go 1.22+, Qt 6 `rcc`, and `rsvg-convert`. For UI tests also install
`qmltestrunner`. The provided build defaults to Homebrew's `rcc` path; override
`RCC` on another build host.

On macOS with Homebrew:

```sh
brew install go qt librsvg
export PATH="$(brew --prefix qt)/bin:$PATH"
```

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

For a **UI-only upgrade** of an existing installation on that same qualified
Paper Pro, close Wikipedia, run the tests/build above, then:

```sh
RM_SSH_KEY=~/.ssh/your_tablet_key bash scripts/update-pro-ui.sh VERIFIED_IP
```

This keeps the installed backend, icon and app history byte-for-byte. It backs
up the app and state to the tablet and `.cache/receipts/` on your computer,
verifies both copies, and updates only the UI resource and manifest. Do not use
this script for a release that changes the backend. Refresh AppLoad, then reopen
Wikipedia. No editor or tablet restart is needed.

### If something goes wrong

- **No results yet:** typing alone does not search. Tap Search or press Enter.
- **Need more space:** Hide keys expands the list; results remain available with
  the keyboard open too.
- **Network/PDF error:** check Wi-Fi and retry. Wikipedia's PDF service may be
  unavailable for a particular article; this app has no fallback server.
- **Import taking too long:** check My files before retrying. A successful
  download is not proof that import completed.
- **Installer rejects your device:** stop; the exact firmware/model has not
  been qualified by that installer. Do not remove the guard to force it.

## Development diagnostics

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
