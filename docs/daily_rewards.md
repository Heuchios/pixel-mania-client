# Daily rewards

Deployed to staging on 2026-10-11 for testing. The client and backend must be
released together. This feature is not included in the published production build.

The HUD gift button sits directly below the gem counter at the top left. It follows
the counter's scaled bounds. A compact charcoal window leaves the surrounding
world visible, with no full-screen tint or purple backdrop. Celebration effects
stay inside the window. It includes a five-second reel, published odds, a
collect/reveal screen, and a countdown.
The panel blocks movement, item use, fishing starts, and gameplay/chat shortcuts.
Escape, Android Back, and the close button dismiss it. Closing never cancels or
re-grants a saved reward.

User-approved prizes are 250, 1,000, and 5,000 gems. Server weights are 75%, 20%,
and 5%. Each account may claim once per UTC calendar day. Reset is 00:00 UTC.
Client values are display data only; `server_daily_rewards.ts` owns the rewards,
cryptographic random choice, database clock, and claim eligibility.

`daily_reward_status` and `daily_reward_claim` use the existing authenticated,
rate-limited inventory transaction transport. A claim includes the offered
`reward_day`, which prevents yesterday's delayed requests from consuming today's
box. Requests use player inventory locks and flush pending player saves. PostgreSQL
locks the player and gem inventory rows and atomically commits gems, the unique
`daily_reward_receipts(player_id, reward_day)` receipt, item/gem/transaction ledgers,
and inventory hashes. Failed commits roll back; repeated claims recover the saved
prize without paying again. No local-clock or local-file reward fallback exists.

Validation entry points:

- Client: `--headless --path . --script res://tests/daily_rewards_ui_test.gd`
- Render the same test without `--headless` to capture desktop, portrait, phone
  landscape, wide-screen, HUD, claimed, and winner views under `D:/Pixelmania/`.
  Set `DAILY_REWARDS_PREVIEW_BACKGROUND` to a local screenshot for a world backdrop.
- Backend: `npm run check:daily-rewards` (also in `check:security`).
- Database: `npm run test:daily-rewards-postgres`; set `QUEST_TEST_PGLITE_PATH` to
  an installed PGlite package if it is not available locally. The test uses an
  isolated PostgreSQL/WASM database and never reads game-server credentials.

The database test covers rollback after partial writes, all reward boundaries,
duplicate and simultaneous requests, account case normalization, recovery after
module restart, UTC rollover, stale-day rejection, capacity, and database outages.

Verified: 34 client checks passed; desktop/mobile/HUD/prize renders were inspected,
including the compact window over a world screenshot. Route and isolated
PostgreSQL tests passed. The full backend `check:security` chain passed in the
isolated staging checkout, including TypeScript, lint, economy, and runtime checks.
Deployed route tests and a read-only query confirmed the daily receipt primary
key `(player_id, reward_day)`. Public health and smoke checks passed with PostgreSQL
and Redis ready. No real-account claim or physical-device test was performed.

## Staging release

- Client implementation: `592025e0`; staging merge: `f798c048`.
- Backend implementation: `ef9bf28`; staging merge/deployed commit: `0a7e3097b90e`.
- Active release: `20261011-daily-rewards-v2-0a7e309`.
- API: `https://staging-api.pixelmaniagame.com`; WebSocket: same host at `/ws`.
- Existing staging compatibility retained: current 1.2.20, minimum 1.2.14.
- The usual local client project already targets staging in editor/debug builds.
  Restart its game session to use the changed UI; no new published client binary.
- Previous pre-feature release: `20261008-mobile-inventory-214da34`.

Deployment caveat: `-SkipClientVersionLock` omitted the old release's version
overrides and temporarily fell back to the shared environment's 1.0.4/1.0.0 values.
The final immutable release explicitly restored 1.2.20/1.2.14 using the existing
deploy script with staging user, host, URL, and port 8180. It reused the successful
full gate for the identical backend commit and reran the reduced release checks
and public smoke checks. The automatic `previous` pointer is the first daily
rewards release; use the named pre-feature release above for a feature rollback.
Production was not deployed or reconfigured.
