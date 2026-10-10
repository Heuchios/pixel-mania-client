# PixelMania Codex Handoff Status

Last updated: 2026-10-08

This document exists so a fresh Codex chat can continue from the current
backend/security state without relying on chat memory.

## Latest Verified Status

### Production 1.2.23 fishing fixes verified (2026-10-09 local / 2026-10-10 UTC)

Backend `5a59e28` and client build `654bba8` shipped as
`20261010-fishing-5a59e28`. Natural ponds are now included in authoritative
fishing validation, expired casts permit retries, and client cancellations
replace misleading casting messages. Full security and 248 client fishing
checks passed. Target (33), completion (80), start recovery and visual sync
regressions pass against deployed code. Main/route health and real launcher
1.2.23 download/checksum/install pass. Signed Android 1.2.23/code 45 APK/AAB
are ready, not uploaded to Play. Compatibility floors remain unchanged.

FREEZE has a valid wooden rod/bait setup; its saved ponds are currently ice.
The exact reported S22 attempt remains unconfirmed without a live open-water
retry. No player/world data was modified during diagnosis. Artifacts:
`D:/Pixelmania/PixelMania/release_artifacts/client-1.2.23/`.
[Full evidence and limits](fishing_release_1_2_23.md).

### Production 1.2.22 wearable names verified (2026-10-09)

Five requested display names are now Construction Hat, Brown Pigtails, Brown
Ponytail, Black Stylish Hair and Black Mid Hair. Existing IDs, assets, animations,
owned items and Hair Pack odds are preserved. Client build source `1a7b34e9`
and backend `6acf01a` shipped as `20261009-wearable-names-6acf01a`.

Full backend security and focused catalog/wearable checks passed. All five names
and healthy main/route instances were verified on production. PC 1.2.22 is live;
the real launcher download/checksum/install test passed. Desktop minimum remains
1.2.21 and global minimum remains 1.2.14. Signed Android 1.2.22/code 44 builds are
ready but not uploaded; Android policy remains 1.2.6. Pending fishing changes
remain excluded. [Release evidence](wearable_names_release_1_2_22.md).

### Production 1.2.21 wearables verified (2026-10-09 UTC)

Client build source `0f747b51` and backend `a4de8670af2a` shipped as
`20261009-wearables-a4de867`. Added six Hair Pack styles and nine hats from the
requested wearable atlas cells; Police Hat already existed. Supernova Hair has
three frames and Witch Hat four. Baby Hair remains at 0.1%, and shop odds match.

Production desktop 1.2.21 is published; the actual launcher download, checksum
and installation test passed. Main/route health and all 16 item IDs were verified.
The server minimum stays 1.2.14; Android remains 1.2.6. Signed Android 1.2.21/code
43 APK/AAB are ready, not uploaded to Play. Artifacts are in
`D:/Pixelmania/PixelMania/release_artifacts/client-1.2.21-verified/`.

Full backend security and focused client tests passed. Normal packaged Windows
startup connected to production without script/resource errors. Staging upload
was rejected by automatic review; only the authorized production deployment ran.
Unrelated pending fishing edits were excluded and remain local. Complete item
names, cells, commits, hashes, validation and limits:
[Wearables release 1.2.21](wearables_release_1_2_21.md).

### Fishing investigation and preparation for 1.2.23 (2026-10-09)

The affected account/world is FREEZE, using a wooden rod on a Samsung S22
(correcting the earlier tentative Z Flip report). Read-only production boolean
checks confirm valid rod ownership/tracking, usable bait and a compatible reward
pool. The latest recorded client includes 1.2.20 fixes. No accepted fishing start
or catch was found in this account's item-transaction history. Account records
remain on production; automatic review blocked detailed record export.

Found and fixed a separate concrete server defect: fishing validated only saved
foreground placements, so naturally generated ponds were rejected. It now uses
the effective authoritative terrain, including generated ponds, player edits,
removals and snow/ice overrides. Actual FREEZE terrain generation reproduced the
failure before the patch. Production replay also found FREEZE's natural ponds
currently replaced by ice with no remaining fishable water. Do not claim the
current world is open water, undo legitimate ice, or claim a Samsung-specific
root cause. The user was asked for an open-water retry in FISHING.

Two earlier fixes remain included: remove expired server casts before retrying
(live casts still prevent duplicate bait spending), and show an explicit client
cancellation reason when selection/rod/water/reach/menu/keyboard changes before
an accepted cast reply. Late responses still cancel only their own session.

Validation passed: 33 target checks using actual generated terrain for FREEZE,
FISHING, START and POND, including removal/ice/cleared-world/reach rejection;
start recovery and 80 completion checks; fishing visual synchronization; full
backend check:security; 248 isolated client fishing checks, catalog and mobile
single-tap tests. Client checks include wooden rod and bait selection on phone
viewports, resize/low-frame-rate behavior, late replies and acknowledgement
loss. Physical S22 testing is unavailable; the reported exact attempt is not
proven by the account snapshot.

Release preparation is based on production 1.2.22, including wearable renames.
Released as 1.2.23 / Android code 45; verification is recorded above.
Earlier pickup/loadout/mobile/shop/music and
identity-recovery work is already in production. Do not overwrite existing
version packages or change Android/global compatibility floors.

### Production 1.2.20 verified and published (2026-10-08 local / 2026-10-09 UTC)

Backend `214da3427bc6024cb546b529c689dafea15e16ee` and client build source
`b1cf65a9fd938c0f613528ad5b34c7705477709f` shipped as
`20261008-mobile-inventory-214da34`. Staging and production backend archives match
SHA-256 `bd37d101e7e70721b0e65f70f43434f9d820eec870ab928a4ac9cab8f3023878`.
The full security gate passed again during promotion, and staging/production API
smokes passed. Main 8080 and routes 18091/18092 report this release, 1.2.20,
minimum 1.2.14, PostgreSQL ready and Redis ready.

After production restart, all 5,692 players / 1,057 inventory stacks / 222 tracked
stacks still have ZERO identity mismatches. All 5,596 active drops in 95 worlds
(78 tracked drops) also have ZERO mismatches. This confirms the restored original
IDs survived startup with the cap correction. Previous FISHING snow/staff,
BUYSEED staff and partial player-state/loadout fixes are included.

Artifacts: `D:/Pixelmania/PixelMania/release_artifacts/client-1.2.20/`:

- `PixelMania-desktop-1.2.20.zip` — 52,077,576 bytes, published to production.
- `PixelMania-1.2.20-build42.apk` — 106,259,282 bytes, signed, non-debuggable.
- `PixelMania-1.2.20-build42.aab` — 54,003,108 bytes, signed.
- `build-manifest.json` records exact source and artifact SHA-256 values.

Desktop production minimum is 1.2.20 and ZIP hash is
`229ab10d7727f285dcb89c91a034b7d1a64a2d0b02f82b62a400eab091a7268c`.
Real launcher downloads on both staging and production verified and installed
1.2.20. The packaged debug client connected to staging; the packaged release
connected to production and ignored staging overrides. Both started without
script/resource-load errors. Windows embedded version is 1.2.20.0. The isolated
release import passed the sample-for-sample lossless music regression. Android
APK and AAB embedded version 1.2.20/code 42 and signatures were verified; APK
signing identity matches 1.2.19. Temporary build credentials were removed.

Android builds are ready, not uploaded to Google Play. The Android manifest and
global compatibility floor were preserved. No physical-device or authenticated
multiplayer gameplay test was run. Two stale legacy UI test limitations are
documented in the preparation note below; focused changed-path checks passed.
Rollback target: `20261008-pickup-loadout-0e00d0e`. Inventory repair backup and audit
records are in backend `docs/inventory_identity_recovery.md`. No GitHub push was
needed or performed. Unrelated untracked temporary files remain untouched.

### 1.2.20 mobile/music/inventory fixes prepared (2026-10-08)

Mobile gameplay control panels are transparent, zoom buttons are 64 instead of
96 authored pixels, and pressed icons retain feedback. The detached shop category
rail and main panel now share a fit/scale calculation and opening fade; the global
mobile scaler no longer separately positions them. Rendered phone checks confirm
visible tabs and transparent controls. Layout tests cover five viewport sizes and
four UI scale settings, including opening and category switching.

Login audio is imported as lossless stereo PCM. Legacy menu helpers share the
MusicManager player; duplicate deferred starts and cancelled starts are guarded.
The regression compares every imported PCM sample with the source WAV and checks
loop bounds, single-player reuse, stop-before-start and no restart on scene reuse.

The global production inventory audit found one 400-unit Super World Lock stack
with 250 usable identities. A historical fixed 250 cap in startup reconciliation
had retired 150 original IDs. Backend reconciliation and non-strict ledger sync
now use the actual item stack limit. Exact original IDs were restored with a
verified backup and transactional audit, without quantity changes. The repeat
audit covered 5,692 players/1,057 stacks/222 tracked stacks and found zero issues.
See backend `docs/inventory_identity_recovery.md` for evidence and recovery IDs.

Full backend security and real SQL drop/inventory tests pass. Client menu music,
mobile shop, mobile controls, zoom, connected layout, touch scrolling and shop
pack detail checks pass. The old `ui_typography_test` fails its first assertion
even in isolated published 1.2.19 source (legacy font opt-out expectation); it is
not a regression introduced here. The unchanged old `ui_atlas_migration_test`
also references a retired `shop_card_normal.tres` absent from published 1.2.19;
current rendered shop and focused pack/layout checks pass. No physical Android
device test is available.
Release target is 1.2.20 / Android code 42. Deployment results are recorded after
verification below; do not assume this preparation note means it is published.

### Production 1.2.19 pickup/loadout fixes and builds (2026-10-08)

All requested fixes passed checks and were committed before deployment. Backend
commit `0e00d0e9deb84` and client source `c6c159465df1` are released as
`20261008-pickup-loadout-0e00d0e`. Production and staging have the identical backend
archive SHA-256 `36842af7cf226c054b3602a4a6afc1c1fa74fa99300dff8617a2de4c2d425eb1`.
Main (8080) and world routes (18091, 18092) each report this release, version 1.2.19,
minimum 1.2.14, and healthy PostgreSQL/Redis. Production API smoke checks passed.
Rollback target is `20261008-world-entry-fixes-9df7bb6`. Verified pre-release backup:
`shared/backups/before-production-1219-1791503145874.dump` (62,174,957 bytes).

The deployed read-only identity audit found 5,596 active drops across 95 worlds,
78 requiring identities, and ZERO mismatches after the 50 snow and two staff
recoveries. Legacy provenance remains explicitly unknown; identities were repaired
with audit records, without changing drop counts, positions or player inventory.
The audit/recovery history and commands are in the backend's
`docs/drop_identity_recovery.md`.

The complete backend `check:security` passed before commit and again in production
promotion. All 19 pickup checks, the real SQL/PGlite recovery/history/partial-stack
tests, harvest weapon/race/rollback tests, and four client state/loadout suites
passed. This closes the identified creation, partial repair and partial player
update failure paths; it is not a claim that arbitrary future bugs are impossible.

Version 1.2.19 artifacts are in
`D:/Pixelmania/PixelMania/release_artifacts/client-1.2.19/`:

- `PixelMania-desktop-1.2.19.zip` (47,602,055 bytes), published to production.
- `PixelMania-1.2.19-build41.apk` (101,794,620 bytes).
- `PixelMania-1.2.19-build41.aab` (49,537,968 bytes).
- `build-manifest.json` records committed source and artifact SHA-256 values.

Staging and production launcher tests downloaded, checksum-verified and installed
1.2.19. Production desktop minimum is 1.2.19; Windows package SHA-256 is
`3be6979f0121720cb98a7e94d422830ffcfafa567dbe31adfaa3b2568d280ba0`.
Packaged debug startup connected to staging; packaged release startup connected to
production and ignored staging overrides. Isolated source import/startup had no
script or resource-load errors. Windows file version is 1.2.19.0. APK/AAB signatures
and embedded version 1.2.19/code 41 were verified, and APK signing identity matches
1.2.18. Temporary export credentials were removed from the isolated build source.

Android artifacts are built and signed, not uploaded to Google Play. Android
manifest/minimum remains unchanged, and the global server floor remains 1.2.14.
No physical Android-device or authenticated multiplayer gameplay test was run.
No GitHub push was needed or attempted. Unrelated temporary files remain untracked.

### Global drop audit and release 1.2.19 preparation (2026-10-08)

The user's follow-up authorized a game-wide pickup audit, Serpent Staff recovery,
permanent fixes, and commits/deployment/new builds after all fixes pass checks.
The production audit covered 5,596 active drops across 95 worlds and inspected
all 220 saved worlds. After the 50-snow recovery below, only two tracked-drop
mismatches remained: one Serpent Staff each in FISHING and BUYSEED. Both had no
identity or ledger evidence anywhere. Both were recovered with admin/ledger audit
records and a verified PostgreSQL backup. The fresh global audit reports zero
mismatches among 78 tracked drops. Backend `docs/drop_identity_recovery.md` records
the exact backup, recovery IDs, cause, audit CLI and regression commands.

The historical harvest path omitted drop-origin/identity journal entries; the
October 6 fix already protects newly harvested ordinary and mutated-tree rewards.
The new backend changes repair the entire outstanding stack on partial pickup,
check prior identities/events across all worlds and owners before any automatic
repair, and use the actual reward item rather than a source block for identity
creation. Nineteen pickup checks, real SQL/PGlite integration checks, the shipped
harvest handler's weapon reward checks and four client state/loadout checks pass.

Client metadata is prepared for 1.2.19, Android code 41. Code fixes and release
preparation are still local at this point; a later release entry will record the
actual deployed commit/builds. Do not raise the Android minimum until its Play
release is available. Unrelated untracked `tmp/` diagnostics remain excluded.

### FISHING legacy pickup recovery and partial player-state reset (2026-10-08)

Production logs on the current host `pixelmania@68.183.141.114` confirmed
`world_drop_item_instances_pending` for old FISHING snow drops. Fifty active
one-item snow drops created before September 30 had no origin metadata, tracked
identities, identity events, or matching item/transaction ledger references.
Automatic pickup repair correctly refused their unknown provenance. Do not
weaken that guard or infer provenance merely from a `server_` drop ID.

The user explicitly approved recovery of those 50 drops. The operator script
`PixelManiaServer/scripts/repair_legacy_drop_identities.js` first produced a
read-only exact-row plan, then revalidated it under world/drop row locks and
created exactly 50 identities in one audited transaction. Quantities, positions,
world snapshots and player inventories were not replaced. Verification found 50
active snow units, 50 claimable identities, zero mismatches and 50 ledger rows.
No server restart was needed. Recovery request:
`legacy-drop-repair-e2c79343-c209-42a5-a0a7-b515ee873299`.
Verified pre-repair backup:
`shared/backups/before-fishing-drop-repair-20261008-1791502062542.dump`
(62,155,037 bytes; `pg_restore --list` passed). The plan and before image remain
on the host under `/tmp/fishing-snow-plan-20261008.json*`; automatic approval
review rejected exporting the detailed production plan to the local workspace.
The separate old Serpent Staff drop was not part of the approved recovery.

The local client log also confirmed the hotbar/equipment issue: a partial
`player_data` update arrived without wearable inventory fields, and the client
zeroed all omitted maps before ownership checks. `save_manager.gd` now preserves
omitted/malformed maps while replacing explicitly supplied maps, including empty
ones. This preserves loadout, fish, shop claims and fishing records on partial
updates without reintroducing world-session item ghosts. The new
`partial_player_state_test.gd` fails 60 checks against the old source and passes
against the fix; session-item, hotbar-refresh and world-exit-appearance tests pass.

A related backend edge case is fixed locally: when PostgreSQL safely rebuilds a
server-authored drop's missing identities, it now rebuilds the entire outstanding
stack rather than only the current pickup quantity. Otherwise a partial pickup
made the remainder permanently fail the known-identity guard. All 17 pickup
regressions and drop-capacity checks pass. The recovery SQL integration test
passes in isolated PGlite, including atomic rollback on audit failure, repeat and
stale-plan refusal, global identity/history checks and partial pickup conservation.
The complete backend `npm run check:security` also passed, including the online
dependency audit, TypeScript/generated-module checks and economy/security gates.

Only the approved data recovery is live. The client/source and backend code fixes
are local and require a client build/backend release before packaged clients and
production pickup-repair code receive them. Production remains on 1.2.18 and
`20261008-world-entry-fixes-9df7bb6`. No client update was published in this task.

### Production 1.2.18 and desktop/Android builds (2026-10-07 local / 2026-10-08 UTC)

Production now runs `20261008-world-entry-fixes-9df7bb6`, backend commit
`9df7bb6271d7`, promoted from staging with the identical backend archive SHA-256.
Client release source is `499abd9b2089` (version 1.2.18, Android version code 40),
including the combined fixes below and the latest weapon trails and wing effects.
The vending preview hover experiment was removed before this release.

Main and both production world-route instances (8080, 18091, 18092) report the
new release, healthy PostgreSQL/Redis, server version 1.2.18 and minimum 1.2.14.
The production database backup was verified with `pg_restore --list` before
deployment: `shared/backups/before-production-1218-1791437805448.dump`
(62,052,263 bytes). No world/player data restore or replacement was performed.
Rollback target is `20261005T052200Z-b69931b01bc3`.

The desktop update manifest now advertises 1.2.18, minimum 1.2.14; its public
download returned HTTP 200 and its SHA-256 matches the local 47,596,161-byte ZIP.
Release artifacts and build manifest are in
`D:/Pixelmania/PixelMania/release_artifacts/client-1.2.18/`:
`PixelMania-desktop-1.2.18.zip`, `PixelMania-1.2.18-build40.apk`, and
`PixelMania-1.2.18-build40.aab`. Android store metadata was deliberately left
unchanged: the APK/AAB are built and signed, but have not been uploaded to Play.

Full backend `check:security` passed, including the production deployment's repeat
gate. Eleven weapon/wing FX suites and the door-world snapshot safety suite
passed. Isolated source import and release exports succeeded. Packaged debug PC
startup connected to staging; packaged release startup connected to production
even with staging override arguments. APK package/version, non-debuggable state
and signing identity match were verified; AAB signature verification passed.
Temporary export credentials were removed from the isolated source afterward.
No physical Android-device or authenticated two-player gameplay test was run.
The previously documented unrelated world-join lifecycle timing assertion remains.

All game changes are committed locally; temporary `tmp/` diagnostics remain
excluded. No GitHub push was attempted because the earlier source-egress approval
request remains unanswered. This entry supersedes earlier production-untouched
and no-downloadable-build notes below.

### Combined staging release verified (2026-10-07 local / 2026-10-08 UTC)

Staging release `20261008-world-entry-fixes-9df7bb6` is active with backend
`9df7bb6271d7` and client source/metadata `78e060635a95`. This supersedes the
local/not-deployed status in the historical entries immediately below: portal
snapshot ordering and guards, session item cleanup/restrictions, world-only door
destinations, first-attempt login, chat/face presentation, remote fishing visuals,
fish monger scrolling and developer noclip/visibility changes are included.
Client gameplay changes require restarting the editor play session; this operation
did not publish a new downloadable Windows/Android build. Production is untouched.

Full `check:security` (including dependency audit, TypeScript, generated-module,
economy/persistence and deployment checks) passed before commit. Developer
visibility, 11 focused Godot suites, fishing catalog, 197 fishing checks and mobile
tap tests passed. Deployment used `-Fast` only to avoid rerunning that completed
full gate; remote archive validation, activation and public smoke checks passed.
PostgreSQL and Redis are healthy. Read-only post-deployment verification confirms
START still has 721 foreground and 178 background tiles, entrance (49,63).
The pre-deployment staging dump was verified with `pg_restore --list`:
`shared/backups/before-world-entry-fixes-1791419136802.dump` (45,595,504 bytes).
Previous release `20261007-client-polish-71987b0` remains the rollback target.

All game changes are committed locally. GitHub push was blocked by automatic
approval review as private-source egress to unverified remotes; explicit approval
was requested for both existing Heuchios repositories. Temporary diagnostic
scripts/screenshots under `tmp/` remain outside the game release commit.

### Door/portal world snapshot race (2026-10-07, local)

Cross-world `door_enter_ok` started an asynchronous transition whose overlay waits
delayed `clear_world()`. The immediately following destination snapshot could
start building before that clear, losing its first batch (including the entrance
and nearby platforms). The missing-entrance fallback then fabricated a roof-level
gate with dirt/grass. Lobby and `/warp` entry did not use this delayed door path.
Read-only staging inspection found START's saved entrance at (49,63), 721
foreground tiles and 178 background tiles intact. No database restore or write
was performed; returning through the normal entry path displayed the saved map.

Door entry now claims a synchronous preparation barrier before any fade/overlay
await. Network packet dispatch and queued snapshots wait until old-world cleanup
has finished. Online snapshots are validated before replacement and their loaded
tile maps checked before activation. Invalid loads return to the lobby instead
of generating terrain; online entrance checks cannot alter saved terrain, and
an online/rejected world cannot later fall through to a local whole-world save.

Godot door snapshot regression passes for fade/no-fade transitions, delayed clear,
snapshot eligibility, malformed/missing tiles and non-mutating gate checks.
Portal entry, spawn safety, rejoin reconciliation and loading-operation tests
pass. Both string and compact versions of the read-only START snapshot validate
with all 899 tiles. The older lifecycle suite stops on its pre-existing 0.34s
fade assertion (HEAD uses 0.08s); that unrelated test/code was left unchanged.
Local client changes only; not committed or deployed. A live two-world traversal
should still be checked in the updated client before release.

### Developer noclip and visibility commands (2026-10-07, local)

Noclip now keeps render-frame movement packets and idle heartbeats flowing while
local physics is paused. The physics movement step also guards against gravity
if another path resumes it; respawn/entrance placement respect noclip and punch
knockback cannot resume physics during it. Remote players continue interpolating
while the local developer uses noclip. Server presence carries `noclip_enabled`
so observers do not collision-clamp a noclip avatar against walls.

Developer-only `/inv` and `/vis` use the existing server role, PIN/2FA, cooldown
and PostgreSQL admin audit path. Invisibility is temporary session state,
independent of noclip, and never hides the local character. The server omits
hidden avatars from direct/batched presence and join snapshots, immediately
culls existing avatars without a departure fade, and clears queued stale
presence/culls before switching visibility. `/vis` immediately restores current
position. Same-session world changes preserve invisibility; new sessions default
visible. Designers and regular players cannot use these commands.

Verified `npm run check:developer-visibility`, 39 movement rollback scenarios,
socket delivery/column batching, generated movement/server checks, and server
validation/admin/account-security checks. Godot developer movement/visibility,
batch protocol, multiplayer interaction and loading-operation suites pass.
Client and backend changes are local, not deployed; ship both together.

### World-session inventory ghosts (2026-10-07, local)

The client preserved old tool/material counts when an authoritative inventory map
omitted a zero-count item. It could therefore keep a cached Magnet Machine Remote
or World Lock Key after the server had removed it. Authoritative inventory loads
now clear absent counts. World exit immediately clears both local items, hotbar
selection and the magnet binding; local player files exclude these session items.
PostgreSQL cleanup remains server-authoritative. Godot world-session tests cover
same/different-world re-entry, stale snapshots, both selected items, cache writes
and unchanged ordinary inventory; hotbar and gem/rod regressions pass. Backend
world-exit and PGlite magnet persistence tests pass, including removal of both
inventory rows and their active item instances. Local only, not deployed.

### First-attempt sign-on timeout (2026-10-07, local)

Login now waits for the shared 20-second transport authentication deadline plus
one second for packet dispatch, instead of discarding replies after 8 seconds.
Sign On preserves an already-opening socket. Connection loss ends the UI wait;
a genuine auth timeout retires the socket before another attempt can start.
Password, registration and session-token senders now check whether the packet
was sent. Transient failures preserve remembered credentials. The remembered-login
suite passes with an 8.2-second delayed first response, disconnect, timeout,
stale response, failed send and socket-retirement cases; connection-health tests
also pass. No live account login was performed. Changes are local, not deployed.

### Talking mouth follows sent chat (2026-10-07, local)

Local and remote sent chat bubbles attach a weak reference to their speaker.
The face controller plays talk only while that bubble is visible in chat mode;
hidden/freed bubbles and notification messages do not trigger speech. Typing dots
still follow input activity independently. Existing hurt/death priority remains.
Face expression and chat typing indicator regression suites pass, including the
alternate player controller. Changes are local, not deployed.

### Fish monger and shared mobile scrolling (2026-10-07, local)

Fish monger rows pass gestures to their ScrollContainer and use the shared atlas
scrollbar/handle. InputManager no longer consumes UI wheel events before GUI
dispatch. MobileScrollPolicy configures native scroll containers on every platform,
including touch-capable desktops, with an 8px drag deadzone; text editors, ranges,
and inventory's custom touch scrolling retain their own gesture handling.
`tests/mobile_scroll_test.gd` and `tests/fish_monger_scroll_test.gd` pass. The latter
checks wheel and touch-emulated swipes at 1280x800, 640x360 and 390x844, including
swipes over Sell buttons without submitting a sale. Physical phones were not tested.
These changes are local and not deployed.

### Player emote dropdown (2026-10-07, local)

The right HUD now adds a smile button below chat with Wave, Laugh and Sad.
The supplied emotes atlas drives faces, with timed arm/head/body gestures;
movement, damage, death and world exit cancel them. Preview in Godot with
`Scenes/debug/player_emotes_preview.tscn` (F6). Client tests cover gesture reset,
input, routing, dedupe and desktop/mobile bounds; backend tests cover authentication,
world membership, rate and server-owned identity. `player_emote` is a cosmetic
world broadcast in the phase9 routes/phase7 dispatcher, with a message-rate bucket.
No durable data or schema changes. Client and matching backend changes are local;
the backend event must be deployed for live multiplayer visibility.

### Fish stack cap and hotbar quantity consistency (2026-10-07, local)

Fish additions now cap at 999 kg (9990 integer tenths) in client, item definitions,
server catch/grant capacity and PostgreSQL inventory/pickup transactions. Legacy
holdings up to the previous 2000 kg ceiling remain readable and sellable; no
quantity migration or truncation is performed. Decreasing a grandfathered holding
keeps its stored constraint at least its remaining amount. Hotbar and inventory
share a 24px quantity baseline with measured fitting. Changes are not deployed.


### Claimed-world lock removal grace (2026-10-07)

Paid ownership now survives physical World Lock removal for seven days only.
PostgreSQL stores `unlocked_until`; repeat saves/restarts do not reset it. Only
the owner can replace the lock during grace, canceling the timer at no charge.
Expiry releases ownership and claim while retaining public name and terrain;
old receipts move to world_name_claim_history, release is ledgered, no refund.
Another player or former owner can lock and pay to claim again. Existing claimed
worlds already missing locks start a full window on migration. Client removal
notice, daily in-world reminders, lock card and payment confirmations explain it.
Taxes remain suspended. This replaces previous permanently-retained ownership.
Verified staging release `20261007-claimed-grace-987c429`, backend `987c429`,
client `02995c7`. Full security/deploy gate, Godot claim UI/ownership/alias tests,
and name integration tests in both PGlite and a disposable real PostgreSQL schema
passed (grace start, no reset, owner-only replacement, expiry, archived receipt,
stale snapshot suppression and new payment). Fresh staging backup verified before
rollout. Live TEST remains claimed with its physical lock and no grace deadline;
name identities/deadlines intact, PostgreSQL/Redis healthy, taxes disabled.
Backend release used an isolated worktree to exclude concurrent quest edits.

### World taxes removed from gameplay (2026-10-07)

User requested removing taxes for now. Backend WORLD_TAX_SUSPENDED defaults true,
overriding prior activation; no billing, payments, or overdue acquisition blocks.
Profile no longer creates the Taxes entry or panel. Historical accounting remains
untouched. Name reservations, claim prices and permanent ownership are unchanged.
Do not opt back in without a billing-date migration to prevent retroactive bills.
Verified staging release `20261007-tax-suspended-7cd610a` (backend `7cd610a`,
client `061aa26`). Profile regression, suspension no-accounting/no-payment checks,
name integration and archived tax integration suites passed, as did the full
security/deployment gate. Staging PostgreSQL/Redis healthy; name deadlines and
world identities preserved. Restart the editor play session to remove the UI.

### Unpaid world lock release (2026-10-07)

Removing an unpaid world lock now releases the reservation and owner immediately,
leaving the existing public name and terrain intact. Anyone, including the same
player, may relock for a fresh seven-day period without a release cooldown.
Only paid names retain ownership without a physical lock. Creation alone keeps
the entered public name and has no expiry; auto-renaming only follows unpaid
locked reservation expiry. The placement precheck now checks physical blocks,
not the permanent-owner flag. Tax counts fall on release without erasing weekly
peaks or accrued bills. This supersedes the earlier all-locks-persist rule below.

Committed backend `3006ce9` and client `72a3996`; staging release
`20261007-unpaid-release-3006ce9` is active. Full deployment security/smoke checks,
focused Godot ownership/alias/claim UI checks, backend lock lifecycle checks, and
both name/tax suites against disposable real PostgreSQL schemas passed.
After a verified staging backup, repaired ABC's confirmed missing physical lock:
released its unpaid owner/reservation, preserved ABC and every terrain block,
cleared its expiry, and restarted staging with release metadata preserved.
Post-repair verification: 1 claimed, 12 reserved, 122 unowned names, valid deadlines,
preserved world identities, healthy authoritative PostgreSQL and Redis.
Restart the editor play session to load the client-side replacement-lock fix.

### World taxes (2026-10-06)

Implemented behind backend `WORLD_TAX_ENABLED`: three free worlds per account,
500 gems per extra world weekly, seven days of grace, manual gem payment through
the new personal Profile > TAXES panel. Weekly bills use peak extra ownership;
transfers cannot erase accrued charges. Overdue accounts cannot acquire worlds or
reserve/claim names. Existing worlds, builds and permanent names are preserved.
See sibling backend `docs/world-taxes.md` for accounting, tests and activation.
PostgreSQL/WASM rollback, concurrency, receipt replay and transfer tests pass;
client profile access, request transport and desktop/mobile panel tests pass.

Active on staging release `20261007-world-tax-685a0a3` (backend `685a0a3`, client
`0858378`). Full security/deployment smoke checks and the tax suite against real
PostgreSQL in a disposable staging schema passed, including trade eligibility,
deadline-crossing permits and receipt replay. Activation: 2026-10-07 02:59:35 UTC;
existing owners' first bills: October 14 02:59:35 UTC, grace ends October 21 at the
same time. Initial verification: 8 owner accounts, 14 owned worlds, zero debt,
1,000 gems total projected first-week bills. A verified staging database backup
was taken before rollout. Permanent names and existing reservation deadlines are
unchanged. Production was not deployed or activated. Restart the client/editor
play session for Profile > TAXES. Tax activation persists across restarts.
For service restarts, source the release's `.release-env` with BASE_DIR set and
exported before calling the release activator; otherwise release/client-version
metadata is lost. This was corrected and public health reverified on staging.

### World name claims (2026-10-06, active on staging)

World-name reservations, rarity-priced permanent claims, seven-day expiry, and
server-verified original payment receipts are implemented in the sibling
PixelManiaServer repository and this client. See that repository's
`docs/world-name-claims.md` for architecture, activation, checks and limitations.
`WORLD_NAME_CLAIMS_ENABLED` defaults off. It is enabled on staging release
`20261006-world-names-f727ec1` (backend `f727ec1`, client source `2f21658`).
Production was not deployed or activated. Staging activation was
2026-10-06 20:02:26 UTC; its 13 existing owned names have the same deadline,
2026-10-13 20:02:26 UTC. Another 120 names are unowned. A staging database backup
was verified before deployment under the staging account's shared/backups folder.
Public names are aliases; stable internal world identities preserve contents and
ownership when names expire. Do not replace this with physical world-row renames.
Ship the matching client and coordinate all backend shards before enabling it.

The full standard deployment security gate and post-deploy smoke checks passed.
Claim SQL/rollback/receipt/concurrent-payment tests also passed against real
PostgreSQL in a disposable staging schema, which was removed after the test.
Staging public health confirms the expected release with PostgreSQL and Redis ready.
Client alias/receipt/layout, inventory, and electrical tests pass. Existing world-entry lifecycle coverage
has an unrelated stale fade-duration assertion (0.34 versus current 0.08 seconds);
multi-shard verification remains required before production deployment. Staging
currently has one backend process. Do not roll staging back to a pre-claims binary
without a directory/database migration; permanent world identities now use aliases.

Staging follow-up: the client inventory-action allowlist omitted world_name_status,
world_name_reserve, and world_name_claim. This caused the lock panel to display
"Could not contact the server" before sending anything. All three are now allowed;
`tests/world_name_request_test.gd` exercises the real sender with captured transport
and rejects unknown actions and unauthenticated requests. Restart the running
client/editor play session to load this client-side fix.

Name-retention correction deployed to staging as `20261006-name-retention-1b77a2b`:
locking a world keeps its entered public name for seven days even when the account
has other unpaid reservations. Only unpaid expiry assigns the old name plus 1–3
random digits, skipping occupied names. Internal UUID identities remain unchanged.
The full deployment gate and real PostgreSQL regression tests passed. The prematurely
renamed owned ABC was restored with its original October 13, 20:08:28 UTC deadline;
the unused, unowned re-entry placeholder was preserved as ABC1. Both repairs were
recorded in the transaction ledger after a verified staging database backup.

World-name search follow-up: the World Lock card now lets players look up a name's
availability and claim price. Only the owner of an auto-named world can reserve a
replacement; reservation is free and changes the public alias for seven days.
The server rechecks availability, cooldown and quoted price during reservation.
Paid names and active reservations cannot be replaced through this control.
Permanently claimed worlds hide search controls and reject server-side searches;
their claimed name and original payment receipt remain visible.
Client requests correlate responses and invalidate quotes when the input changes.
Focused PostgreSQL/WASM, request transport and desktop/mobile UI tests pass.
Restart the client/editor play session to load the new search action and controls.
Deployed to staging as `20261006-name-search-e8584bf` (backend `e8584bf`, client
`16d0dee`). The full security gate, post-deploy smoke checks, and the updated
search/reservation/expiry tests against real PostgreSQL in a disposable staging
schema passed. Live registry verification confirms preserved identities and valid
seven-day deadlines: 1 claimed, 13 reserved and 120 unowned names.

### Netfox Movement / Server Handoff (2026-07-02)

Current goal: transition player movement to Netfox while keeping the existing
backend authoritative for login/auth, world loading, inventory, actions,
persistence, drops, moderation, and economy. Netfox should own movement only;
do not replace the whole backend with Netfox.

Production Netfox status:

- A production Netfox movement server process exists on the droplet
  `165.227.33.94` as PM2 app `pixelmania-netfox-start`.
- The current production Netfox server is for world `START` on UDP port `24566`.
- Route registration and lookup were verified after fixing the token/hash
  mismatch. The verifier showed manual route registration `ok: true` and route
  lookup `ok: true` for `START -> 165.227.33.94:24566`.
- Server logs showed successful world loading from the backend with collision
  data present, and route registration similar to
  `Netfox route registered... public=165.227.33.94:24566`.
- Backend `.env` and the PM2 backend environments must use the same
  `NETFOX_SERVER_WORLD_STATE_TOKEN_HASH`, which is the SHA256 hash of the raw
  token passed to the Netfox server via `--netfox-server-token`. Do not commit
  or document the raw token.

Useful verification commands:

```powershell
.\Scripts\verify_netfox_server_route.ps1 -World START -NetfoxHost 165.227.33.94 -Port 24566 -ServerToken $env:NETFOX_TOKEN -Register
ssh root@165.227.33.94 "pm2 list; pm2 logs pixelmania-netfox-start --lines 120 --nostream"
ssh root@165.227.33.94 "cd ~/PixelManiaServer && grep -n '^NETFOX_' .env && pm2 env 6 | grep NETFOX_SERVER_WORLD_STATE_TOKEN_HASH && pm2 env 1 | grep NETFOX_SERVER_WORLD_STATE_TOKEN_HASH && pm2 env 2 | grep NETFOX_SERVER_WORLD_STATE_TOKEN_HASH"
ssh root@165.227.33.94 "pm2 restart pixelmania pixelmania-a pixelmania-b --update-env && pm2 restart pixelmania-netfox-start --update-env && pm2 save"
```

PM2 ids can change; prefer PM2 app names when restarting, and only use ids when
you have just checked `pm2 list`.

Active issues to resume from:

- The client can still fall back to WebSocket movement when the backend route is
  missing, expired, or resolves to `127.0.0.1:24566`. In production, a healthy
  client should target `165.227.33.94:24566`.
- The latest observed blocker was severe 1 FPS lag caused by log spam, including
  repeated `NETFOX_STATUS` lines and repeated `[PM_DROP_PICKUP_DIAG] no_player`
  entries. Fix log throttling first before deeper movement/collision work.
- Collision is still unresolved: players can walk/pass through many blocks.
  Earlier collision/tilemap changes caused major FPS drops and were reverted.
  Do not guess here; inspect TileMap/TileSet collision, NetfoxPlayer
  layer/mask, and server collision generation with fresh evidence.
- Re-entering a world can still get stuck on `Preparing player...` when route,
  ticket, or spawn readiness fails.
- Late join / remote player positioning and world isolation had visual issues
  during transition and should be re-verified once Netfox connection is stable.

Recommended next steps:

1. Flush/restart `pixelmania-netfox-start`, verify the route with the script
   above, then launch exactly one client and collect fresh logs.
2. Fix log spam only. Likely files to inspect are
   `Scripts/networking/netfox_real_manager.gd`, `Scripts/network_manager.gd`,
   and `Scripts/drop_manager.gd`. Do not change movement, collision, or routing
   behavior while doing this.
3. Fix route/fallback next: prove the backend route exists before ENet connect,
   ensure production clients never connect to `127.0.0.1:24566`, and honor
   `NETFOX_MOVEMENT_ALLOW_STATIC_FALLBACK=false`.
4. Fix collision only after Netfox connection and logging are stable, using a
   minimal reproduction and concrete collision-layer/mask/tile data.

Do not:

- Do not commit or paste the raw Netfox server token.
- Do not trust stale Godot Output or PM2 logs. Flush logs before verifying.
- Do not re-enable static fallback as a hidden fix.
- Do not make broad collision/tilemap rewrites without measuring FPS.
- Do not revert unrelated dirty worktree files.

### Latest Multiplayer Scaling Handoff

As of 2026-06-26, the multiplayer scale-readiness work in this Codex window is
implemented locally and verified with local/static checks. Treat it as ready for
staging or Redis-enabled multi-instance validation before production rollout:

- Phase 1: `MAX_PLAYERS_PER_WORLD` defaults to 50 and is enforced on
  `join_world` and cross-world `door_enter`.
- Phase 2: backend world fanout uses a per-world player index
  (`socketByPlayerId` / `worldPlayers`) instead of scanning all sockets.
- Phase 3: Redis-backed world admission reservations are wired with
  `WORLD_ADMISSION_TTL_MS`, refresh on live presence, and cleanup on leave,
  disconnect, and session replacement.
- Phase 4: `backend/scripts/multi_instance_world_cap_smoke.js` can prove two
  backend instances share one Redis world cap. It skips cleanly with
  `--allow-skip` when Redis is not available locally.
- Phase 5: Redis-backed world route ownership is wired through
  `SERVER_INSTANCE_ID`, `SERVER_INSTANCE_WS_URL`, `WORLD_ROUTE_TTL_MS`, and
  `WORLD_ROUTE_ENFORCEMENT_ENABLED`. The server can reject with
  `reason: "world_route_redirect"` and includes `redirect_ws_url` plus
  `owner_instance_id`.
- Phase 6: the Godot client handles `world_route_redirect`: it validates the
  redirect WebSocket URL, preserves the saved session during the route hop,
  reconnects to the owner, and retries the pending world join. Production builds
  only follow trusted URLs from `SERVER_URLS` or
  `pixelmania/network/world_route_ws_urls`; editor/debug builds can follow dev
  overrides for local tests.
- Test harness: `backend/scripts/multiplayer_scaling_smoke.js` and npm scripts
  `test:multiplayer-scaling`, `test:multiplayer-scaling:fast`, and
  `test:multiplayer-scaling:redis` now run the completed multiplayer checks
  from one command.

Latest local verification from this window:

- `npm run check:scale-readiness` passed.
- `npm run check:security` passed.
- `npm run test:multiplayer-scaling` passed locally; Redis-specific smokes
  skipped because Redis was not reachable at `127.0.0.1:6379`.
- `npm run test:multiplayer-scaling:fast` passed locally after the client route
  redirect change.
- `node --check backend/scripts/multiplayer_scaling_smoke.js` passed.
- PowerShell parse check for `backend/deploy_to_droplet.ps1` passed.

Continuation verification on 2026-06-26:

- `npm run test:multiplayer-scaling:fast` passed locally.
- `npm run smoke:world-cap:multi -- --redis-url redis://127.0.0.1:6379
  --redis-connect-timeout-ms 500 --cap 2 --ports 18570,18571 --world
  MULTI_INSTANCE_CAP_SMOKE` failed before starting the multi-instance assertion
  because Redis was not reachable at `127.0.0.1:6379`.
- A follow-up attempt using `redis://127.0.0.1:8080` also failed with
  `ECONNREFUSED`; from this Codex process, port `8080` was not listening as a
  Redis endpoint.
- This Windows environment did not have `redis-server`, Docker, a Redis service,
  or an installed WSL Linux environment available, so the Redis-required smoke
  still needs a Redis-enabled local machine or staging server.
- Redis-enabled validation later passed on the DigitalOcean droplet from
  `~/PixelManiaServer` with Redis at `redis://127.0.0.1:6379`.
  `npm run test:multiplayer-scaling:redis -- --redis-url
  redis://127.0.0.1:6379` completed with `syntax`, `static_gates`,
  `local_single_instance`, `redis_world_cap`, and `redis_route_conflict` all
  reporting `ok`.
- Route-staging helper scripts were added locally after the Redis pass:
  `npm run stage:world-route` starts two non-production PM2 route instances
  (`pixelmania-route-a` and `pixelmania-route-b`) on ports `18081` and `18082`
  with PostgreSQL disabled, Redis enabled, and world route enforcement enabled.
  `npm run smoke:world-route:public` validates public shard URLs such as
  `wss://api.pixelmaniagame.com/staging-ws-a` and
  `wss://api.pixelmaniagame.com/staging-ws-b`.
- The route-staging helper must run those temporary route apps with
  `ENVIRONMENT=development` and `PIXELMANIA_ENABLE_DEV_BACKEND_LOGIN=true`,
  because the public route smoke uses `dev_backend_login`. Keep these apps
  isolated from production durable data and remove them after validation.
- Public route staging validation passed on the droplet:
  `npm run smoke:world-route:public -- --owner-url
  wss://api.pixelmaniagame.com/staging-ws-a --other-url
  wss://api.pixelmaniagame.com/staging-ws-b --follow-redirect` returned
  `ok: true`, `redirect_reason: "world_route_redirect"`,
  `redirect_ws_url: "wss://api.pixelmaniagame.com/staging-ws-a"`,
  `owner_instance_id: "route-stage-a"`, and `followed_redirect: true`.
  This proves the public Caddy shard paths can route to two backend instances
  and the redirect payload points clients back to the owner route.
- Cleanup after public route staging: remove or comment the Caddy
  `/staging-ws-a*` and `/staging-ws-b*` handles, run
  `sudo caddy validate --config /etc/caddy/Caddyfile`, reload Caddy, and stop
  the temporary PM2 apps with `pm2 delete pixelmania-route-a
  pixelmania-route-b && pm2 save`.
- Client route trust is now configured locally in `project.godot` under
  `pixelmania/network/world_route_ws_urls` for the intended production shard
  URLs `wss://api.pixelmaniagame.com/ws-a` and
  `wss://api.pixelmaniagame.com/ws-b`. The scale-readiness wiring check now
  verifies these URLs are present, and the deploy helper copies `project.godot`
  to `~/pixel-mania/project.godot` for droplet-side static checks.
- A guarded production-route helper is now available locally:
  `npm run prod:world-route` starts `pixelmania-a` on `127.0.0.1:18091` and
  `pixelmania-b` on `127.0.0.1:18092` using production PostgreSQL/Redis,
  dev-login disabled, snapshots disabled on the route apps, and
  `WORLD_ROUTE_ENFORCEMENT_ENABLED=false` by default. Set
  `ROUTE_PRODUCTION_ENFORCEMENT_ENABLED=true` only when intentionally testing
  redirect enforcement on those route apps.
- `npm run smoke:world-route:public` now supports production token auth through
  `--token-file ./load_tokens.json`, writes rotated tokens to
  `./load_tokens.next.json` by default, and can validate
  `wss://api.pixelmaniagame.com/ws-a` -> `wss://api.pixelmaniagame.com/ws-b`
  redirects with `--owner-instance-id pixelmania-a --follow-redirect` after
  enforcement is enabled.
- Production route dry-run is in progress with enforcement still disabled:
  `pixelmania-a` and `pixelmania-b` are online behind Caddy `/ws-a*` and
  `/ws-b*`, local health checks on `18091`/`18092` are healthy, and `/ws-b`
  can authenticate/join with disposable load-test tokens. `/ws-a` initially
  returned `Saved login expired. Sign on again.` for multiple fresh token rows,
  and direct `ws://127.0.0.1:18091` showed the same failure. Route-a logs showed
  `[postgres] initialization failed ... tuple concurrently updated` followed by
  JSON fallback, so route-a was not reading the production sessions table.
  Restarting `pixelmania-a` restored Postgres readiness and direct/public
  `/ws-a` token auth passed. Public `/ws-b` token auth also passed. After
  route-app reload, both `pixelmania-a` and `pixelmania-b` reported
  `postgres_ready:true` and `postgres_authoritative:true`, and fresh public
  token load tests passed against both `wss://api.pixelmaniagame.com/ws-a` and
  `wss://api.pixelmaniagame.com/ws-b` with `auth=1 joined=1`.
  A controlled route-enforcement redirect smoke also passed with
  `ROUTE_PRODUCTION_ENFORCEMENT_ENABLED=true`: the owner joined
  `wss://api.pixelmaniagame.com/ws-a`, the other route returned
  `reason:"world_route_redirect"`, `redirect_ws_url:"wss://api.pixelmaniagame.com/ws-a"`,
  `owner_instance_id:"pixelmania-a"`, and `followed_redirect:true`. Enforcement
  was then set back to `false`; leave it off until an exported client build
  that trusts `/ws-a` and `/ws-b` has been tested.
- Exported client validation: after `project.godot` was updated with trusted
  route URLs for `/ws-a` and `/ws-b`, the user exported a client build,
  connected to the live game, and confirmed normal gameplay. This validates the
  exported client baseline against the current backend route setup. The user
  also tested the exported client with route enforcement enabled and confirmed
  normal gameplay, completing the production route-enforcement canary.
- Load-test follow-up: attempted 500/100 synthetic load from the production
  droplet itself did not prove 500 active players. The first run was limited by
  the shared login IP throttle (`LOGIN_ATTEMPT_LIMIT_IP=20` by default). A
  follow-up 50+50 local route test with separate token pools kept PM2, Redis,
  Postgres, and pending queues healthy, but each route plateaued at
  `auth=24/joined=24` because `account_token_login` is also protected by the
  shared Redis message limiter (`8` per `15s` per IP before authentication).
  Treat these as rate-limit/load-generator-shaping results, not capacity
  failures. For one-host synthetic tests, either ramp auth below that limit
  or add a guarded load-test-only config knob before trying 500 active clients.
- Later 250-client local route attempts used five 50-client workers against
  direct route ports `18091`/`18092`. The server processes stayed online and
  reported no load-script errors/rejections, but it was not a clean 250-player
  pass: final worker auth counts were partial (`40`, `28`, `2`, `2`, `0`) and
  a repeat attempt ended partial again (`47`, `12`, `0`, `2`, `11`). Several
  workers stayed connected without authenticating. This again points at the
  shared pre-auth `account_token_login` message limiter and/or one-droplet load
  generator shaping from a single source IP, not a gameplay-loop failure. Do
  not cite 250 as verified until auth reaches 50/50 on each worker during the
  hold window.
- The staged WebSocket load test now supports `--token-offset` and prints the
  token row/user range it is using; combine it with `--verbose` when diagnosing
  one failing production shard URL.
- `postgres_store.js` now retries retryable Postgres startup failures,
  including the observed `tuple concurrently updated` conflict, so one route app
  should not stay in JSON fallback after a transient concurrent bootstrap race.
- The local deploy helper now copies `Scripts/block_manager.gd`,
  `Scripts/world_tilemap_renderer.gd`, `scripts/start_route_staging_instances.sh`,
  and `scripts/public_world_route_smoke.js` so the droplet scale gates and route
  staging helpers are present after deployment.

Known local test limits:

- Redis is not installed/running locally, so the true Redis multi-instance cap
  and route-conflict/redirect smokes still need to be run on a Redis-enabled
  machine or staging with:

```powershell
cd G:\PixelMania\pixel-mania\backend
npm run test:multiplayer-scaling:redis -- --redis-url redis://127.0.0.1:6379
```

- No Godot executable was found on PATH in this Codex environment, so the
  Godot client route redirect code was verified by static scale-readiness checks
  and source inspection, not by launching the editor/runtime.

Recommended next phase in a fresh Codex window:

1. Run the Redis-required multiplayer scaling smoke on a machine/staging server
   with Redis available.
2. If it passes, deploy to staging with two backend instances, unique
   `SERVER_INSTANCE_ID` values, and route-specific `SERVER_INSTANCE_WS_URL`
   values.
3. Add the shard WebSocket URLs to `pixelmania/network/world_route_ws_urls` for
   exported clients before enabling `WORLD_ROUTE_ENFORCEMENT_ENABLED=true`.
4. Only after staging proves redirects and world caps, decide whether to deploy
   the multi-instance route enforcement path to production.

### Backend Security Foundation

As of the latest 2026-06-10 production work in this chat, the backend security
foundation through checklist item 10 is implemented, deployed, and user-tested.
Checklist items 11, 12, 13, and 14 are implemented locally and ready for
deployment/testing:

- PostgreSQL is the authoritative durable database for account, player, world,
  inventory, economy, audit, session, punishment, transaction, rollback, and
  journal data.
- Redis is the live helper layer for rate limits, presence, active sessions,
  cooldowns, locks, and short-lived multiplayer coordination.
- DigitalOcean Spaces is configured for off-site backups and large snapshot
  files. The Spaces CLI/key issue was fixed by installing AWS CLI v2 and
  configuring a matching DigitalOcean Spaces access key/secret pair; a manual
  `put-object` test succeeded with an `ETag` and lifecycle `Expiration`.
- PostgreSQL backup, restore-check, maintenance, and off-site copy scripts are
  present. Backup/restore-check has been run successfully on production.
- Item instance tracking is wired for valuable/rare/equipment/tool/lock items
  with exact `PM-ITEM-*` movement and dev-panel lookup/history tools.
- Session validation reads the PostgreSQL `sessions` table.
- Punishments, bans, and mutes are stored in PostgreSQL and enforced by login,
  chat, request-pipeline, and admin/dev tooling.
- Transaction ledger rows are written for valuable economy actions, failed
  valuable attempts, and rollback/reversal paths.
- Gem ledger rows are written for gem balance changes through the shared
  authoritative inventory/economy paths.
- World block/object journals are wired for rollback and investigation.
- Rollback tooling supports player, world, item, and transaction rollback, with
  exact-time world restore and explicit crash recovery through
  `npm run world:recover`.
- Snapshot + action-log tooling is wired. Production snapshot scheduling is
  throttled for the 1GB droplet.
- Server-side validation is wired for valuable actions. The client requests;
  the server validates permissions, world locks, reach, cooldowns, ownership,
  capacity, balances, roles, and contested state.
- Anti-dupe transaction locking is wired for trades, vending, drops, shared
  inventory commits, and safe/vending object mutations using live locks plus
  PostgreSQL transaction/row locks.
- Admin action logging is wired, deployed, and user-tested. Admin/dev actions
  now include actor, target, role, IP/session/device context, reason, affected
  item/world, before/after values or hashes, denied attempts, and success/fail
  metadata in PostgreSQL `admin_actions`.
- Account/session security hardening is wired in code: explicit scrypt password
  algorithm metadata, hashed session/refresh tokens, refresh rotation,
  one-active-session enforcement, IP/user-agent/device tracking, durable login
  attempt rows, Redis/local login throttling, optional admin TOTP 2FA, optional
  admin confirmation tokens, and admin command cooldowns.
- Bot/rate-limit protection is wired in code: Redis/local server-side buckets
  for block places, block breaks/hits, pickup attempts, chat messages, trade
  requests, world joins, login attempts, and vending purchases, with throttled
  `security_events` evidence for blocked bot-limit attempts.
- Integrity hashes are wired in code: player inventory hashes are stored on
  `players`, transaction ledger rows get deterministic `transaction_hash`
  values, world snapshots get stable `snapshot_hash` values, rollback updates
  hashes after legitimate reversals/corrections, and
  `npm run integrity:hash-audit` records PostgreSQL audit summaries in
  `integrity_audit_runs`.
- Monitoring dashboard is wired in code: an admin/PIN-gated developer panel
  Monitor tab requests server-authoritative dashboard data, logs access to
  `admin_actions`, shows live online/world/server-loop/memory/snapshot state,
  and reads top gem gainers, top item gainers, suspicious accounts, dupe
  warnings, and latest integrity audit status from PostgreSQL.

Future backend/economy/security work must keep using these patterns: durable
state in PostgreSQL, temporary coordination in Redis, large/off-site files in
Spaces, exact `PM-ITEM-*` rows for valuable items, transaction/gem ledger rows
for economy movement, world journal rows for world edits, and admin action rows
for privileged operations. Important mutable state should also keep integrity
hashes so manual edits, corruption, and bad migrations can be audited.

## Core Architecture

PixelMania production backend uses:

- PostgreSQL as the permanent source of truth for durable game data.
- Redis as a temporary live helper for locks, rate limits, presence,
  active-session markers, cooldowns, and multiplayer coordination.
- DigitalOcean Spaces as file/object storage for off-site backups and large
  world snapshot JSON files.
- Local JSON only for development, migration fallback, or emergency recovery.

When adding any durable backend feature, wire it to PostgreSQL as part of the
feature.

## Production Services

Known production droplet:

- SSH target used in this project: `root@165.227.33.94`
- Backend directory on droplet: `~/PixelManiaServer`
- Public API base: `https://api.pixelmaniagame.com`
- Public WebSocket: `wss://api.pixelmaniagame.com/ws`
- PM2 app name: `pixelmania`

10,000-player readiness notes live in `docs/scale_readiness_10k.md`. The
current small single-node droplet is not a 10,000-concurrent-player target by
itself; use the scale runbook, load tests, and horizontal/world-sharding plan
before treating that number as production capacity.

The health endpoint should show:

- `persistence.postgres_ready: true`
- `persistence.postgres_authoritative: true`
- `persistence.redis_ready: true`
- `persistence.redis_stats`
- `persistence.world_snapshot_storage.mode: "spaces"` when Spaces is enabled
- `persistence.world_snapshot_storage.mode: "local"` is expected while Spaces
  snapshot uploads are intentionally paused for stability

## PostgreSQL Coverage

PostgreSQL is wired as the authoritative durable store for:

- accounts
- players
- worlds
- world_members / world access data
- world_locks and lock access state
- inventory
- item_instances
- item_instance_events
- item_transactions
- transaction_ledger
- gem_ledger
- trades
- vending_transactions
- shop_purchases
- admin_actions
- world_block_changes
- world_object_changes
- world_snapshots metadata
- security_events
- account_login_attempts
- sessions
- punishments / bans / mutes
- integrity_audit_runs

Session validation has been hardened to read from the sessions table instead of
only relying on compatibility account-state logic.

## Redis Coverage

Redis is enabled as the live helper layer. It is used for:

- message/action rate limits
- live presence markers
- active-session markers
- drop pickup locks
- vending buy locks
- world admission reservations for shared 50-player caps across instances
- world route ownership keys for temporary per-world backend ownership
- short-lived live coordination

Redis is not permanent truth. Any Redis state must be safe to lose or rebuild
from PostgreSQL/player reconnects.

## DigitalOcean Spaces Coverage

Spaces bucket used in production work:

- Bucket: `pixelmania-backups`
- Region/endpoint: `tor1`, `https://tor1.digitaloceanspaces.com`

Spaces is wired for:

- off-site PostgreSQL backup copies under `postgres/`
- large world snapshot JSON files under `world_snapshots/`
- lifecycle cleanup policy:
  - expire `postgres/` objects after 90 days
  - expire `world_snapshots/` objects after 180 days
  - abort incomplete multipart uploads after 7 days

Do not commit Spaces keys. If keys appear in chat/logs, rotate them in
DigitalOcean and update only the droplet config files.

Production incident note from 2026-06-10:

- Repeated world snapshot uploads to Spaces caused log spam and likely PM2
  instability on the 1GB droplet.
- Logs showed repeated `[snapshots] Spaces upload failed` lines, and a manual
  `aws ... s3api put-object` test failed with
  `argument of type 'NoneType' is not a container or iterable`.
- The server stabilized after setting `WORLD_SNAPSHOT_STORAGE=local` and
  restarting PM2 with `--update-env`.
- The Spaces CLI/key issue was later fixed by installing AWS CLI v2 and
  configuring a matching DigitalOcean Spaces access key/secret pair. A manual
  `aws ... s3api put-object` test then succeeded and returned an `ETag` plus a
  lifecycle `Expiration`.
- Spaces-backed world snapshots can be used only when `/health` confirms the
  expected snapshot storage mode and PM2 logs show no new Spaces upload errors
  for at least one snapshot cycle. If upload failures return, switch snapshots
  back to local storage first. PostgreSQL remains authoritative, and PostgreSQL
  backup/off-site copy handling is separate from world snapshot upload mode.

Temporary stability command on the droplet:

```bash
cd ~/PixelManiaServer
grep -q '^WORLD_SNAPSHOT_STORAGE=' .env && sed -i 's/^WORLD_SNAPSHOT_STORAGE=.*/WORLD_SNAPSHOT_STORAGE=local/' .env || echo 'WORLD_SNAPSHOT_STORAGE=local' >> .env
pm2 startOrReload ecosystem.config.js --env production --update-env
```

Before enabling or re-enabling Spaces-backed world snapshots, this manual
upload test must succeed without AWS CLI errors:

```bash
cd ~/PixelManiaServer
echo "pixelmania spaces test $(date -u)" > /tmp/pixelmania-space-test.txt

AWS_REQUEST_CHECKSUM_CALCULATION=when_required \
AWS_RESPONSE_CHECKSUM_VALIDATION=when_required \
aws --endpoint-url https://tor1.digitaloceanspaces.com s3api put-object \
  --bucket pixelmania-backups \
  --key world_snapshots/test/pixelmania-space-test.txt \
  --body /tmp/pixelmania-space-test.txt
```

## Backup And Recovery

PostgreSQL backup/recovery scripts are in `backend/scripts/`:

- `postgres_backup.sh`
- `postgres_restore_check.sh`
- `postgres_maintenance.sh`

NPM shortcuts:

- `npm run db:backup`
- `npm run db:restore-check`
- `npm run db:maintenance`
- `npm run db:maintenance:preflight`
- `npm run db:maintenance:copy`
- `npm run db:maintenance:alert-test`

Production cron jobs were added for periodic backup and restore checks. Off-site
copy cron was also added once Spaces upload worked.

The restore check includes table counts, including `transaction_ledger`.

## Item Instance Tracking

Stackable/common items are tracked as inventory counts.

Valuable, rare, equipment, locks, tools, event, shop, quest, crafting, vending,
trade, or admin-created items must use `item_instances` rows with stable
`PM-ITEM-*` public IDs.

Completed rare-item movement work:

- admin give/remove uses explicit item instance source labels
- shop, crafting, and fishing rewards use explicit sources
- trades move exact tracked item instances
- vending list/buy/payment paths move exact tracked item instances
- world drop and pickup paths use tracked instance rows
- raw inventory mirrors do not mint missing tracked items
- dev panel can look up item instances and instance history
- anti-dupe audit can detect duplicate IDs, impossible state/location
  combinations, and inventory count mismatches

Old legacy items may still show `unknown` or `reconcile` as the source because
they existed before full tracking was wired.

## Transaction Ledger

`transaction_ledger` is now the canonical investigation trail for valuable
economy actions.

Completed transaction ledger work:

- schema/table and indexes exist in bootstrap SQL and startup migration
- Postgres helper writes canonical ledger rows
- generic inventory commits write ledger rows
- drop pickup writes ledger rows
- trade finalization writes ledger rows
- vending buy writes ledger rows
- rejected/failed valuable attempts write `status = failed` rows through the
  shared action rejection path
- rollback snapshot restores write `ROLLBACK_RESTORE` rows with
  `status = reversed`
- dev panel can look up transaction ledger rows by player, item instance, item
  type, transaction type, or status
- server passes IP/session/device context where available
- `npm run check:transaction-ledger` validates static wiring

Examples of ledgered actions:

- `SHOP_PURCHASE`
- `TRADE_COMPLETE`
- `VENDING_BUY`
- `ADMIN_GIVE_ITEM`
- `ADMIN_REMOVE_ITEM`
- `CRAFT_OUTPUT`
- `FURNACE_OUTPUT`
- `FISHING_REWARD`
- `WORLD_LOCK_PLACE`
- `ITEM_DROP`
- `ITEM_PICKUP`

Ledger rows support statuses `success`, `failed`, and `reversed`. Current live
gameplay paths write `success` rows for completed valuable actions, failed rows
for rejected valuable action attempts, and rollback restore rows for snapshot
restore reversals.

## Gem Ledger

`gem_ledger` is the canonical trail for gem balance movement. Gems must not be
changed silently.

Completed gem ledger work:

- generic authoritative inventory commits write `gem_ledger` rows when the item
  is `gem` or the category is `currency`
- shop purchases write negative gem rows with before/after balance through the
  shared commit path
- admin give/remove writes gem rows through the shared commit path
- fish/fishing/crafting style rewards that add gems write rows through the
  shared commit path
- drop pickup gem rewards write `drop_pickup` gem rows and link them to
  `ITEM_PICKUP` transaction ledger rows
- trade gem sends/receives write `trade_send` / `trade_receive` gem rows and
  link them to `TRADE_COMPLETE` transaction ledger rows
- legacy JSON gem ledger writes still mirror into PostgreSQL when the shared
  commit path did not already write the row
- `npm run check:gem-ledger` validates static wiring

Every future gem source such as quests, events, loot boxes, vending gem flows,
rollback adjustments, or reward systems must create a `gem_ledger` row with a
clear reason/source and before/after balances.

## World Change Journal

World change journaling is wired for rollback/investigation support.

Completed world journal work:

- `world_block_changes` records block edits with actor, world, layer, x/y,
  action, old block type, new block type, source/request metadata, and time
- `world_object_changes` records durable interactive object edits with actor,
  world, object type, object ID, x/y, action, old JSON data, new JSON data,
  source/request metadata, and time
- interaction updates for world locks, wooden entrances, doors, signs, and
  toggles commit through the Postgres world-change path instead of only using a
  delayed world save
- vending list/buy/collect/cancel and safe-style world state saves are captured
  by explicit object rows or old/new world-state diff inference
- reciprocal door links write their own object journal rows
- block place/break rows now include `block_type_before` and `block_type_after`
- `npm run check:world-journal` validates static wiring

Old `world_block_changes` rows from before this pass may have `NULL`
`block_type_before` values. New world object rows start from the deployment time
of this feature; older door/sign/vending edits cannot be reconstructed unless
separate logs/snapshots already captured them.

## Rollback System

Rollback tooling is wired as an auditable PostgreSQL correction layer. It does
not delete investigation records.

Completed rollback work:

- `rollback_jobs` stores every applied rollback plan/result
- player rollback reverses one player's inventory/gem movements after a chosen
  timestamp
- world rollback restores one world from a PostgreSQL, local, or Spaces-backed
  snapshot and writes a `world_object_changes` rollback row
- world rollback also supports exact timestamp recovery with `--at` / `--to` /
  `--target-time`: the tool chooses the newest snapshot at or before that
  timestamp, replays `world_block_changes` and `world_object_changes` up to the
  target time, then applies the replayed state
- `--safe-only` is now supported on world rollbacks to ignore unsafe journal
  events during replay
- explicit crash recovery now exists as `npm run world:recover`. It wraps the
  same snapshot + journal replay path, defaults to dry-run, supports one world
  or all worlds, and requires `--confirm-server-stopped` before applying so live
  players cannot race a recovery write
- item rollback can retire, freeze, unfreeze, flag, or transfer one exact
  `PM-ITEM-*` instance
- transaction reversal can reverse one `transaction_ledger` row or a whole
  transaction group by transaction ID
- original transaction ledger rows are marked `status = reversed`
- correction rows use `source = rollback`, `ROLLBACK_*` transaction types,
  `rollback_applied`, `admin_corrected`, `rollback_job_id`, and
  `rollback_reason` metadata
- rollback inventory/gem corrections write `item_transactions` and
  `gem_ledger` rows
- exact rare-item corrections write `item_instance_events`
- `npm run check:rollback` validates rollback static wiring

Production snapshot scheduling is throttled for the 1GB droplet:

- `WORLD_SNAPSHOT_MAX_WORLDS_PER_CYCLE=5` by default
- `WORLD_SNAPSHOT_STARTUP_RUN=false` by default
- each periodic snapshot waits for pending snapshot persistence/upload work
  before starting the next world

If PM2 shows memory restarts or snapshot-related crashes, temporarily set
`WORLD_SNAPSHOT_INTERVAL_MINUTES=0`, restart PM2, and inspect the snapshot
health/log fields before re-enabling.

If Spaces upload errors return, prefer `WORLD_SNAPSHOT_STORAGE=local` before
disabling the scheduler entirely. Local snapshots plus PostgreSQL journal rows
still support rollback/recovery while avoiding failed off-site upload loops.

Rollback command examples on the droplet:

```bash
cd ~/PixelManiaServer

npm run rollback:apply -- player --user uso --since 2026-06-07T00:00:00Z --reason "dupe correction"
npm run rollback:apply -- player --user uso --since 2026-06-07T00:00:00Z --reason "dupe correction" --apply

npm run rollback:apply -- world --world START --latest --reason "restore before grief"
npm run rollback:apply -- world --world START --latest --reason "restore before grief" --apply

TARGET_AT="$(date -u -d '5 minutes ago' +'%Y-%m-%dT%H:%M:%SZ')"
npm run rollback:apply -- world --world START --at "$TARGET_AT" --reason "restore exact time"
npm run rollback:apply -- world --world START --at "$TARGET_AT" --safe-only --reason "restore exact time (safe events only)"
npm run rollback:apply -- world --world START --at "$TARGET_AT" --reason "restore exact time" --apply

npm run world:recover -- --world START --at now
npm run world:recover -- --world START --at now --safe-only
npm run world:recover -- --world START --at now --reason "recover after crash" --confirm-server-stopped --apply
npm run world:recover -- --all-worlds --at now --continue-on-error

npm run rollback:apply -- item --item-instance PM-ITEM-ABC123 --action retire --reason "duplicate copy"
npm run rollback:apply -- item --item-instance PM-ITEM-ABC123 --action transfer --target uso --reason "restore owner" --apply

npm run rollback:apply -- transaction --ledger-id 123 --reason "bad admin action"
npm run rollback:apply -- transaction --transaction-id 00000000-0000-0000-0000-000000000000 --reason "bad trade" --apply
```

Dry-run is the default. Use `--apply` only after reviewing the plan. Applying a
rollback requires `--reason`.

## Server-Side Validation

Server-side validation is wired as the authority layer for valuable actions:

- block break/place validates server world state, reach, permissions, world
  locks, cooldown/pacing, item breakability/placeability, and inventory cost
- world-based inventory actions enforce world bans consistently
- trade finalization rechecks both players are online, in the same trade world,
  still close enough, and still have the offered inventory before PostgreSQL
  moves anything
- vending list/buy/collect/cancel validate ownership, stock, vendability,
  capacity, and use live vending locks
- safe deposit/withdraw validate ownership, storable item rules, capacity, and
  use live safe locks
- shop, station crafting/furnace, fishing, fish monger, drops, and seeds use
  server item definitions and inventory/capacity checks
- admin/developer actions require admin/developer role and developer PIN unlock

Deploy checks include `npm run check:server-validation`, and that check is part
of `npm run check:security`.

## Anti-Dupe Transaction Locking

Anti-dupe transaction locking is wired for the main valuable movement paths:

- shared inventory commits acquire a live player inventory lock before
  PostgreSQL inventory writes and release in `finally`
- trade finalization sets `_finalizing`, locks both player inventories in a
  sorted order, validates both offers, runs one PostgreSQL transaction, and
  unlocks in `finally`
- vending buys lock the vending machine plus buyer/owner inventories before the
  PostgreSQL vending transaction; the database locks buyer payment/item rows and
  exact tracked item instances
- drop pickup locks the world drop plus picker inventory before the PostgreSQL
  pickup transaction; the database locks inventory and exact world-drop
  `PM-ITEM-*` rows
- vending/safe object mutations already use live object locks and then pass
  through the shared inventory commit lock when inventory changes

PostgreSQL transaction paths use row-level `FOR UPDATE` locks and exact
`PM-ITEM-*` movement helpers for tracked items. If a step fails, the DB
transaction rolls back and live locks release in `finally`.

Deploy checks include `npm run check:anti-dupe`, and that check is part of
`npm run check:security`.

## Admin Action Logs

Admin/dev actions are logged through `logAdminAction()` into local
`admin_actions.log` and mirrored into PostgreSQL `admin_actions`.

Completed admin action logging work:

- deployed and live-tested on production after checklist item 10; user confirmed
  admin action logging works
- admin action rows include admin username/id, role, IP, session token hash,
  user agent, device info, action type, target type/id, target username/world,
  affected item/world, amount, reason, request id, timestamp, success/denied
  status, and message
- developer commands require server-side `isAdmin()` and developer PIN unlock
  before execution
- denied developer/admin attempts are logged and mirrored to PostgreSQL
- admin give/remove logs inventory before/after hashes and before/after item
  counts
- health, teleport, noclip, clear world, reset world, snapshot world, clear
  drops, and spawn commands include before/after values or affected-world
  summaries where relevant
- punishment issue/revoke logs target, type, scope/world, reason, active
  before/after state, and revoke counts
- item instance freeze/unfreeze/retire/transfer/flag logs exact instance ID,
  item type/category, previous state/location/owner, new state/location/owner,
  reason, and inventory effects
- admin lookup tools log both successful and denied lookup attempts
- `npm run check:admin-actions` validates static admin-action logging wiring

Any future admin/dev command must call `logAdminAction()` for success and
denied/failed paths, and must include enough metadata to investigate what
changed and why.

## Account / Session Security

Checklist item 11 is implemented in local code and should be deployed/tested
before marking it production-verified.

Completed account/session security work:

- passwords use Node `crypto.scryptSync` with explicit algorithm metadata stored
  as `password_algorithm`; legacy rows default to `legacy_scrypt` and upgrade on
  successful login
- raw session tokens and refresh tokens are never stored; PostgreSQL stores
  `session_token_hash` and `refresh_token_hash`
- auth responses remain backward-compatible with `session_token` and also
  include `refresh_token` / `refresh_token_expires_at` for newer clients
- saved-login/token login accepts `refresh_token` or legacy `session_token`,
  rotates to fresh tokens, and revokes the old token hash
- one-active-session mode is controlled by `ACCOUNT_ONE_ACTIVE_SESSION` and is
  enforced in memory/Redis and PostgreSQL session revocation
- sessions track IP, user agent, device info, issue time, expiry time,
  refresh expiry, token family, rotated-from session, revoked time, and revoked
  reason
- login attempts are rate-limited by IP/account with Redis when ready and local
  fallback otherwise
- login successes/failures are written to PostgreSQL `account_login_attempts`
  and mirrored to the existing `security_events` stream
- admin/developer unlock can require TOTP 2FA through `ADMIN_2FA_REQUIRED`,
  `ADMIN_2FA_SECRET`, or per-user `ADMIN_2FA_SECRETS`
- developer/admin commands now use combined PIN + optional 2FA security,
  optional confirmation tokens for dangerous commands, admin command cooldowns,
  and existing `admin_actions` audit rows
- `npm run check:account-security` validates static wiring and is part of
  `npm run check:security`

Important production note: `ADMIN_2FA_REQUIRED` and
`ADMIN_COMMAND_CONFIRMATION_REQUIRED` default to `false` so deployment will not
lock out the current admin UI. Enable them only after setting a real TOTP
secret and confirming the client/dev panel sends the required code/token fields.

## Bot / Rate-Limit Protection

Checklist item 12 is implemented in local code and should be deployed/tested
before marking it production-verified.

Completed bot/rate-limit work:

- broad message-level throttling still runs for all WebSocket messages
- action-specific Redis/local throttles now run before expensive validation or
  database work
- block places are limited separately from block breaks/hits
- drop pickup attempts are limited per second
- chat messages are limited per second
- trade requests are limited per minute
- world joins are limited per minute
- login attempts remain limited by IP/account through the account security path
- vending purchases are limited per second through the `vend_buy` transaction
  action
- Redis is used when ready; local per-socket buckets are used as fallback
- blocked bot/rate-limit attempts send a `rate_limited` response and write
  throttled `security_events` evidence
- limits are tunable through `.env` using `BOT_*` variables
- `npm run check:bot-rate-limits` validates static wiring and is part of
  `npm run check:security`

Default bot/rate-limit knobs:

```env
BOT_BLOCK_PLACE_LIMIT=12
BOT_BLOCK_PLACE_WINDOW_SECONDS=1
BOT_BLOCK_BREAK_LIMIT=16
BOT_BLOCK_BREAK_WINDOW_SECONDS=1
BOT_PICKUP_ATTEMPT_LIMIT=12
BOT_PICKUP_ATTEMPT_WINDOW_SECONDS=1
BOT_CHAT_MESSAGE_LIMIT=3
BOT_CHAT_MESSAGE_WINDOW_SECONDS=1
BOT_TRADE_REQUEST_LIMIT=20
BOT_TRADE_REQUEST_WINDOW_SECONDS=60
BOT_WORLD_JOIN_LIMIT=20
BOT_WORLD_JOIN_WINDOW_SECONDS=60
BOT_VENDING_PURCHASE_LIMIT=5
BOT_VENDING_PURCHASE_WINDOW_SECONDS=1
BOT_RATE_LIMIT_SECURITY_LOG_WINDOW_MS=5000
```

## Moderation / Punishments

Punishment storage and behavior are wired:

- `punishments` table
- Postgres helper code
- admin commands for ban/mute/unban/unmute style behavior
- login checks for active bans
- chat checks for active mutes
- request-pipeline enforcement for relevant actions
- dev/admin visibility hooks

## Admin / Dev Tools

Developer/admin tooling includes:

- inventory lookup
- item instance lookup
- item instance history lookup
- transaction ledger lookup
- item instance audit
- item instance moderation helpers such as freeze/retire/transfer-style
  management where available
- punishment management
- monitoring dashboard for online players, world counts, loop health, dupe
  warnings, economy gainers, and suspicious accounts
- snapshot commands

Admin and security actions should continue to write to PostgreSQL audit tables.

## Deployment

Preferred backend deploy command from Windows PowerShell:

```powershell
cd G:\PixelMania\pixel-mania\backend
powershell -ExecutionPolicy Bypass -File .\deploy_to_droplet.ps1 -RemoteIp 165.227.33.94
```

Manual deploy fallback:

```powershell
$SERVER = "root@165.227.33.94"
$ROOT = "G:\PixelMania\pixel-mania"
$LOCAL = "G:\PixelMania\pixel-mania\backend"

scp "$LOCAL\server.js" "$LOCAL\postgres_store.js" "$LOCAL\redis_store.js" "$LOCAL\server_item_database.js" "$LOCAL\ecosystem.config.js" "$LOCAL\package.json" "${SERVER}:~/PixelManiaServer/"
scp "$LOCAL\docs\postgres_security_foundation.sql" "$ROOT\docs\backend_persistence_rules.md" "$ROOT\docs\codex_handoff_status.md" "$ROOT\docs\production_backend_wiring.md" "${SERVER}:~/PixelManiaServer/docs/"
scp "$LOCAL\scripts\check_item_instance_wiring.js" "$LOCAL\scripts\check_transaction_ledger_wiring.js" "$LOCAL\scripts\check_gem_ledger_wiring.js" "$LOCAL\scripts\check_world_journal_wiring.js" "$LOCAL\scripts\check_rollback_wiring.js" "$LOCAL\scripts\check_server_validation_wiring.js" "$LOCAL\scripts\check_anti_dupe_locking_wiring.js" "$LOCAL\scripts\check_admin_action_wiring.js" "$LOCAL\scripts\check_account_session_security_wiring.js" "$LOCAL\scripts\check_bot_rate_limit_wiring.js" "$LOCAL\scripts\check_integrity_hash_wiring.js" "$LOCAL\scripts\check_monitoring_dashboard_wiring.js" "$LOCAL\scripts\rollback_plan.js" "$LOCAL\scripts\rollback_apply.js" "$LOCAL\scripts\world_recover_at_crash.js" "$LOCAL\scripts\world_snapshot_tool.js" "$LOCAL\scripts\postgres_backup.sh" "$LOCAL\scripts\postgres_restore_check.sh" "$LOCAL\scripts\postgres_maintenance.sh" "${SERVER}:~/PixelManiaServer/scripts/"
ssh $SERVER "cd ~/PixelManiaServer && chmod +x scripts/*.sh && npm install && node --check server.js && node --check postgres_store.js && npm run check:security && pm2 startOrReload ecosystem.config.js --env production --update-env"
```

Do not deploy placeholder hostnames such as `YOUR_DROPLET_IP`.

## Verification Commands

Backend local checks:

```powershell
cd G:\PixelMania\pixel-mania\backend
node --check server.js
node --check postgres_store.js
node --check redis_store.js
node --check server_item_database.js
npm run check:security
npm run check:gem-ledger
npm run check:world-journal
npm run check:rollback
npm run check:server-validation
npm run check:anti-dupe
npm run check:admin-actions
npm run check:account-security
npm run check:bot-rate-limits
npm run check:integrity-hashes
npm run check:monitoring-dashboard
npm run check:scale-readiness
npm run test:multiplayer-scaling
npm run test:multiplayer-scaling:fast
```

Redis-enabled multiplayer checks:

```powershell
cd G:\PixelMania\pixel-mania\backend
npm run test:multiplayer-scaling:redis -- --redis-url redis://127.0.0.1:6379
npm run smoke:world-cap:multi -- --redis-url redis://127.0.0.1:6379 --cap 2 --ports 18570,18571
```

Production health:

```bash
curl -s https://api.pixelmaniagame.com/health | python3 -m json.tool
```

PM2 logs:

```bash
cd ~/PixelManiaServer
pm2 logs pixelmania --lines 120
```

Transaction ledger summary:

```bash
sudo -u postgres psql -d pixelmania -c "
SET search_path TO pixelmania, public;
SELECT transaction_type, status, count(*)
FROM transaction_ledger
GROUP BY transaction_type, status
ORDER BY transaction_type, status;"
```

Recent rollback jobs:

```bash
sudo -u postgres psql -d pixelmania -c "
SET search_path TO pixelmania, public;
SELECT rollback_type, status, target_username, target_world, target_item_instance_id, created_at, applied_at
FROM rollback_jobs
ORDER BY created_at DESC
LIMIT 20;"
```

Recent world object changes:

```bash
sudo -u postgres psql -d pixelmania -c "
SET search_path TO pixelmania, public;
SELECT object_type, object_id, action, block_x, block_y, created_at
FROM world_object_changes
ORDER BY created_at DESC
LIMIT 20;"
```

Recent rare-item ledger rows:

```bash
sudo -u postgres psql -d pixelmania -c "
SET search_path TO pixelmania, public;
SELECT public_item_instance_id, transaction_type, source, action, quantity, server_time
FROM transaction_ledger
WHERE public_item_instance_id IS NOT NULL
ORDER BY server_time DESC
LIMIT 20;"
```

Recent admin actions:

```bash
sudo -u postgres psql -d pixelmania -c "
SET search_path TO pixelmania, public;
SELECT action_type, target_type, target_id, target_username, affected_item_id,
       affected_world, ok, created_at
FROM admin_actions
ORDER BY created_at DESC
LIMIT 20;"
```

Recent login attempts:

```bash
sudo -u postgres psql -d pixelmania -c "
SET search_path TO pixelmania, public;
SELECT username, action, success, reason, ip_address, created_at
FROM account_login_attempts
ORDER BY created_at DESC
LIMIT 30;"
```

Spaces snapshot listing:

```bash
aws --endpoint-url https://tor1.digitaloceanspaces.com s3api list-objects-v2 \
  --bucket pixelmania-backups \
  --prefix world_snapshots/ \
  --output json
```

## Known Caveats

- The worktree may contain unrelated Godot/frontend changes. Do not revert user
  changes unless explicitly requested.
- Spaces access keys were exposed in screenshots/chat during setup. Rotate or
  delete exposed keys in DigitalOcean, then update only droplet config files.
- Old legacy item rows can have source labels such as `unknown` or `reconcile`.
- Any future rare item source such as quests, events, loot boxes, rewards,
  crafting, or admin tools must create/move exact `PM-ITEM-*` instances and
  write transaction ledger rows.
- Admin TOTP 2FA and admin command confirmation are implemented but env-disabled
  by default. Enable carefully after configuring secrets and confirming the
  client/dev panel sends the expected fields.
- Bot/rate-limit values are intentionally configurable through env variables.
  Raise them gradually only after checking normal gameplay, `/health`, and PM2
  logs for new `rate_limit_exceeded` noise.
- Multiplayer route enforcement needs Redis plus a tested route strategy. Do
  not enable `WORLD_ROUTE_ENFORCEMENT_ENABLED=true` in production until the
  Redis-required multiplayer smoke passes and exported clients trust the shard
  WebSocket URLs through `pixelmania/network/world_route_ws_urls`.
- This Codex environment did not have Redis running locally and did not have a
  Godot executable on PATH. Redis-specific smokes and Godot runtime validation
  still need a Redis/Godot-capable machine or staging server.
- Rollbacks should be dry-run first, then applied with a clear reason. They
  leave correction records instead of deleting history.
