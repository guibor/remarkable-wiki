# Public source and real-device demo

User explicitly approved publishing the October 2 recording to Reddit/GitHub,
making the repository public after privacy review, and retaining MIT licensing.
The existing LICENSE already grants MIT; no licensing substitution is needed.

## Review

- Reviewed tracked-file inventory and all nine existing commits. No credentials,
  private keys, authinfo files, private notebook contents or state/cache receipts
  found in tracked source/history. Broad token hits refer to article/request
  identifiers and test fixtures, not authentication tokens.
- Existing logs include non-routable LAN IPs, firmware hashes, runtime receipts
  and app-directory paths. Git author metadata identifies the repository owner.
  No history rewrite performed; ignored deployment backups remain local.
- The recording contains the app, public Wikipedia results and Jacques Hadamard
  article. Media export strips container metadata/audio and omits the unrelated
  screen-share footer after the native keyboard closes.

## Media / acceptance

Five chronological segments from the owner's 57.815-second recording produce
the MP4 and looping README GIF. Typing/selection use 1.25x speed, static waits
are trimmed. No fabricated states. `scripts/make-reddit-demo.sh` reproduces both.
Footage confirms stable native keyboard during incremental results, download,
Open PDF and reading/highlighting on Pro. No Move qualification implied.

## Publication workflow

Reddit's r/RemarkableTablet rules require Self-Promotion flair for developer
announcements. Use that community, where the owner's related apps were posted,
not r/Remarkable, which prohibits self-promotion. Use native video attachment
for feed media. Autoplay remains subject to each reader's Reddit settings.
The OAuth helper has no configured Reddit app credential; use the existing
signed-in browser account without requesting passwords or creating new scopes.

## Verified outcome

- Commit `2717885` pushed to main. Repository visibility changed to PUBLIC with
  explicit owner approval; GitHub API reports MIT. Unauthenticated requests to
  the repository and README GIF both return HTTP 200.
- Public source: https://github.com/guibor/remarkable-wiki
- MP4: H.264, 1038x1380, 28.6 seconds, 591760 bytes, no audio. GIF: 520px wide,
  looping, approximately 723 KiB. Contact sheet visually inspected.
- Shell syntax and `git diff --check` pass. This is media/documentation-only;
  the app code and previously passing 38 UI checks are unchanged.
- Reddit draft saved with complete title/body and Self-Promotion flair, not
  published. Video attachment failed because the ChatGPT Chrome extension lacks
  Allow access to file URLs. Normal-picker fallback did not resolve it; no
  extension/security permission changed. Owner asked to enable the setting.
- The composer also reported that its reCAPTCHA service could not connect;
  no challenge was solved. Recheck after upload access is fixed.

No tablet files, settings, services, or app payloads changed for this work.
