# Trade review, chat layout and version enforcement — 1.2.25

Both parties enter a final five-second review after their first trade approvals.
The server sets the deadline and refuses early final accepts from either party;
client-supplied deadlines do not affect it. The final window shows a disabled
countdown button, starting from its actual display time using a monotonic client
clock. Repeated state packets do not restart the timer. Editing/cancelling clears
review state; missing server review state fails closed with a fresh review.

Local and remote chat bubbles now share one screen-space placement pass. Whole
panels avoid each other, preferring space above or beside their speakers and
remaining within the viewport. Overflow artwork is temporarily suppressed while
its lifetime and anchor remain active, then restored when room becomes available.
The existing text wrapping and camera-position stability remain in use.

Older releases were admitted by outdated compatibility minimums, rather than a
missing version check: production server minimum 1.2.14, desktop manifest 1.2.21,
Android manifest 1.2.6, with current server/desktop at 1.2.24. The server already
checks versions before authenticated actions. Malformed numeric version cores
now fail closed as well. Release minimums must be raised alongside distribution
of the installable update; a platform label alone must never bypass the server
minimum.

Android's existing update screen opens Google Play. Its public release manifest
still advertises 1.2.6. Availability of a newer Play release has been requested
from the user and has not yet been confirmed. Do not claim Play availability or
pass `play_available=yes` without that confirmation. This request explicitly
supersedes earlier instructions to preserve old compatibility floors, once the
update distribution target is known.

## Validation

- Server review tests reject both parties at 0, 1000 and 4999 ms, ignore forged
  deadlines, preserve the original deadline on retries, and accept at 5000 ms.
- Client trade review: 14 checks, including countdown text fitting the button,
  duplicate state, acceptance, editing, restarting and cancellation.
- Chat collision layout: 36 checks across desktop/phone viewport sizes, edge
  placement, stable positions, expiry, crowded-screen suppression and recovery.
- Existing chat text layout, update gate, 189 remote-hand checks and partial
  player-state regressions pass.
- Actual phone-sized chat and trade panels were rendered and visually inspected.
- Full backend `npm run check:security` passed.

## Prepared release — not deployed

Client source `d14036891545c20512b666c402e08d78ec375d52` and backend
`1a64150e7bd1ad1edcf43df4309e0c22bd81c9ca` are committed. Windows 1.2.25 and
signed Android 1.2.25/code 47 APK/AAB builds are complete in
`D:/Pixelmania/PixelMania/release_artifacts/client-1.2.25/`.

The packaged Windows release starts with the normal renderer, connects to
production and exits successfully without script/resource errors. APK metadata
confirms the release version, code and non-debuggable flag; its signing
certificate matches 1.2.24. APK and AAB signature verification passes. Temporary
export credentials were removed. The earlier 1.2.24 test source was restored
from its original archive after isolated regression testing.

Artifact SHA-256:

| Artifact | SHA-256 |
| --- | --- |
| Windows ZIP | `1489e780c81a215e0eabbaa576d5e6ac9e746fb4f5936cc3f578aae640ca55cb` |
| Android APK | `32f6c8d3580c71cb96dc0412bc7c6abcd2d1c1dd1fc17fb4bfb59d0f9c8c7275` |
| Android AAB | `f54141d3f9eaa18233284e3c8512cbb55b9dde8e8bf906b9c7ebac3ca9faa7f4` |

`build-manifest.json`, `release-verification.json`, test/build/signature logs and
the two rendered previews are stored beside the packages. No physical Android
device or live two-player trade test was performed for this release.

Production remains `20261010-hand-visuals-33256ff` / 1.2.24; no deployment,
manifest publication, minimum-version change or player-data mutation occurred
for 1.2.25. Android distribution is still awaiting a user answer. Once an
installable 1.2.25 update path is established, deploy both repositories and
publish synchronized required minimums, then verify old versions are rejected
on production. A Play release must actually be available before advertising it.

## Follow-up: readable item messages (2026-10-12)

Backend commit `15343ee9464b034c8427be86516dce89fa8b768e` replaces raw item IDs
in gameplay text with catalog display names. Display withdrawal now sends
`Took Blue Tang.`. The same lookup covers storage, pickup/drop, shop, crafting,
fishing, planting, trade and inventory failure messages, including newly added
catalog entries. The actual withdrawal handler and all 701 configured display
names were checked; full backend security passes. IDs and amounts are unchanged.

Include this backend follow-up when preparing the combined production release;
the original backend candidate listed above does not contain it. This message
fix requires no client rebuild. The existing artifact verification remains a
record of the original candidate. Production deployment and the Android
distribution decision remain pending. Backend details:
`D:/Pixelmania/PixelMania/PixelManiaServer/docs/item_display_names.md`.

## Follow-up: UI warning visibility (2026-10-12)

The client now closes gameplay popups for action errors/warnings so the overhead
message can be read, including nested world-lock confirmations, inventory
selection, daily rewards and emotes. Active trades are canceled on dismissal.
Success/progress feedback keeps its existing behavior. The 29 warning-flow
checks and related trade/chat/menu regressions pass. See
[UI warning visibility](ui_action_warning_visibility.md).

This follow-up requires a new client build. The existing 1.2.25 packages predate
it and remain unchanged; do not deliver them as containing this fix. Include
the follow-up when preparing the combined release with a new artifact version.
