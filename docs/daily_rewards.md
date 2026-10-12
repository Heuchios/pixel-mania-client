# Daily rewards

Deployed to staging on 2026-10-11 for testing. The client and backend must be
released together. This feature is not included in the published production build.

The HUD gift button sits directly below the gem counter at the top left. It follows
the counter's scaled bounds. The compact window uses the shared game UI atlas:
outer panel, inventory slots, selected slot frame, and green action buttons.
The surrounding world stays visible with no full-screen tint or backdrop.
The 4.5-second reel slows onto the server-confirmed prize, then automatically
reveals it with an animated gem count. Collect closes the panel and sends cosmetic
gems toward the actual HUD counter. The next UTC reset remains visible; reward
percentages are not displayed, and the window is shorter without that row.

The reveal reuses the game's fishing reward confetti scenes and textures:
spinning squares, ribbons, and star glints thrown upward before falling. Jackpot
uses the full legendary effect (164 particles, 1.45x UI scale); rare uses the epic
effect (78 particles); common reduces the epic effect to 22 smaller, slower,
shorter-lived pieces. Shared scene resources are duplicated before tuning.
Confetti fires once on reveal, stays clipped inside the window, pauses its GPU
simulation and lifetime timer when hidden, and frees itself after completion.
The one-second collection flight is cosmetic and does not grant currency. It
respects Back/close, and reopening during a spin recovers the same confirmed
prize. The reveal sound uses the existing sound manager and its SFX volume setting.
The panel blocks movement, item use, fishing starts, and gameplay/chat shortcuts.
Escape, Android Back, and the close button dismiss it. Closing never cancels or
re-grants a saved reward.

User-approved prizes are 250, 1,000, and 5,000 gems. The requested jackpot chance
is 0.5%; rare stays at 20% and common receives the remaining 79.5%. Integer server
weights are 795 / 200 / 5, sampled with `crypto.randomInt(1000)` and verified across
all 1,000 outcomes. Each account may claim once per UTC calendar day. Reset is 00:00 UTC.
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

Verified: 42 client checks passed; desktop/mobile/HUD/prize renders were inspected,
including all three confetti tiers and the collection flight over a world screenshot.
Client checks cover automatic reveal, duplicate collect, GPU confetti pause/resume,
effect cleanup, and closing during collection. Route and isolated
PostgreSQL tests passed. The full backend `check:security` chain passed in the
isolated staging checkout, including TypeScript, lint, economy, and runtime checks.
Deployed route tests and a read-only query confirmed the daily receipt primary
key `(player_id, reward_day)`. Public health and smoke checks passed with PostgreSQL
and Redis ready. No real-account claim or physical-device test was performed.

## Staging release

- Client implementation: `592025e0`; staging merge: `f798c048`.
- Follow-up polish uses the shared atlas and the game's existing tiered confetti;
  the 2026-10-12 update also removes displayed percentages and lowers jackpot odds
  to 0.5% in the authoritative backend.
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
