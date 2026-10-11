# Daily rewards

Implemented on 2026-10-11 for staging testing. The client and backend must be
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

Verified: 34 client checks passed; rendered desktop/mobile/HUD/prize screens were
inspected. Route and PostgreSQL tests passed. The existing backend security chain
passed in resumed segments (the initial dependency advisory request was blocked
by network restrictions; the separate npm audit succeeded at the configured high
severity threshold, reporting five existing moderate advisories). TypeScript,
lint, failed-ledger coverage, economy checks, and runtime checks passed. Godot
reported environment certificate-store/shader-cache warnings; no script errors
remained. No authenticated live-server or physical-device test was performed.
