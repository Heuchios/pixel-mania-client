# Three Good Pulls

The fishing manager now uses `Scripts/fishing_pull_game.gd` and the existing
PixelMania UI atlas, font, item icons, journal, and catch reveal.

- Cast on water within four tiles using an equipped/selected rod and a lure.
- Tap the hook button, click the world, or press E/Space within three seconds
  of a bite. Holding the original cast never hooks or reels automatically.
- Tap REEL, E/Space, or the world while the gold marker is in the green zone.
- Common/uncommon rewards require three pulls; rare/epic/legendary require four.
- A sweep takes three seconds. The baseline zone is 44% wide (1.32 seconds);
  better lures increase it up to 56%. Each miss widens the next zone by 6%,
  capped at 64%. Completed pulls never decay.
- Two misses are allowed. A third failed/skipped sweep ends the cast.
- A 0.65-second rest separates attempts; the hook has a 0.35-second grace period.
- Fish/item artwork moves toward the shore after each good pull. The timing
  marker is drawn directly from the gameplay state, without display smoothing.

Casting and rewards use correlated request IDs. Duplicate replies do not
restart casts or count catches twice. Cancelled, timed-out, or wrong-world
cast acknowledgements are closed instead of reactivating fishing. A pending
reward blocks recasting until its reply or a 12-second timeout, and a late
reward cannot hide a newer fishing UI. Old bobbers clean up independently of
new casts. Spending the last selected lure does not cancel the paid cast when
the hotbar automatically selects its primary tool.

The companion server change in `PixelManiaServer/src/server.ts` removes the
extra random failure roll after a won minigame. Session/world/expiry checks,
bait costs, reward selection, inventory commits, XP, and transaction logging
continue through the existing server paths. Publish the updated server build
with the client feature so the live server honors completed catches.

## Local verification

From the client project:

```powershell
.\tests\run_fishing_tests.ps1
```

The runner copies only the needed scripts/assets into a temporary project. It
loads no game network/account autoloads and never saves real player data. It
checks the gameplay rules, actual mouse/keyboard/touch dispatch, local rewards,
cast/catch reply handling, cancellation, rapid recasts, last-lure handling,
timeouts, responsive layouts, and stale fade animations. Runtime errors fail
the runner; the Windows sandbox's unavailable system certificate store is the
only excluded startup diagnostic. The existing mobile single-tap regression
also runs.

From the server project:

```powershell
npm run build:server-entry
node scripts/check_fishing_completion.js
node scripts/check_server_validation_wiring.js
node scripts/check_anti_dupe_locking_wiring.js
node scripts/check_server_phase11e_to_11j_entry_build.js
```

The completion test executes the generated handler with isolated network and
inventory dependencies. It checks all ten difficulty levels, cancellation,
invalid success flags, duplicate completion, wrong/expired sessions, world
changes, bans, capacity rejection, and failed inventory commits.

For visual inspection, run `res://tests/fishing_ui_preview.gd` in the temporary
project with the real graphics renderer, passing an output directory after
`--`. It renders the native UI to PNGs without opening a network connection.
Live server and physical Android-device playtesting remain release checks.
