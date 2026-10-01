# Native keyboard integration — v0.3.1

User approved replacing the custom keyboard after seeing an unsupported square
glyph on the backspace key. Continue on main. No custom fallback added without
evidence of a need; native Hebrew layout availability remains a physical check.

## Exact-firmware reference

Stock 3.29.0.148 TextInputDialog.qml uses Qt.inputMethod.visible/keyboardRectangle
to reserve layout space. The native VirtualKeyboardWindow sits above other
windows; KeyboardPanel has built-in language controls. The earlier owner video
also showed the native keyboard over the custom grid. No firmware patch or new
keyboard-window instance is needed: use the existing Qt input method.

## Changes

- Delete the custom Keyboard.qml and its RCC entry, eliminating its glyph bug.
- Focus native TextInput and call show on field tap/Keyboard. Hide and release
  focus on explicit Search/Enter, download, folder navigation, Open and close.
- Bind visibility to the system state, not an independent flag. Map keyboard
  rectangle into app coordinates and reserve overlap, accounting for scaling
  and already-resized windows. No hardcoded fallback height.
- Keep automatic search focus/keyboard unchanged. Queries typed before backend
  readiness now get queued for normal debounced search after its ready signal.
- Wiki: EN / Wiki: עברית selects the Wikipedia site, not global keyboard layout.
  No keyboard preferences modified. Native input owns symbols, backspace and IME.

## Checks

36 Qt checks and Go/race/vet pass. New tests cover system show/hide, native
dismissal, keyboard overlap, scaled coordinates, no double inset in resized
windows, Unicode Hebrew text/backspace/Enter, close/download dismissal, and
pre-ready query handling. These use an injected input-method mock; they do not
claim the device's native keyboard rendering or available Hebrew layout.
The trusted Pro answered as Ferrari/build20260911125116, PID861536, restarts0,
with Wikipedia closed. LAN scanner returned no devices; pinned key-authenticated
address 10.100.102.101 worked. Deployment and physical acceptance recorded below.

## Deployment

UI-only transaction `wiki-ui-20261001T203935Z` completed; verified rollback
archive/receipts at `.cache/receipts/wiki-ui-20261001T203935Z/` and on-device
`/home/root/.codex-backups/wiki-ui-20261001T203935Z/` (including previous-app).

Installed SHA256:
- manifest: `18475577832da62fcff1c9d2855fa987b36f012202004817709f8000408a9e7b`
- resource: `8ead7c2c1486a0d72e59fad337abeadf9bcf19c4ed1b02fedf8bb1538cde706e`
- unchanged backend: `fa3c2fbd666cb17d7011d3cbd47da4ff84c08dfa3873c1cf5ef605258a037abb`
- unchanged state: `13947061c196a83f2ee038481010d290c0421516a03658cd599f4d829404fe8d`

Icon unchanged. Runtime before/after: PID861536, NRestarts0, identical drop-ins,
read-only root. No device keyboard setting changed. Move untouched. On-device
native keyboard display, language layouts and typing remain physical checks.
