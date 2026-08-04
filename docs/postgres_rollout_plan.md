# PixelMania PostgreSQL Rollout Plan

This rollout is designed to layer in security/integrity without rewriting systems
you already have working in server-authoritative flow.

## What is already covered

- Authoritative world + inventory contract exists:
  - [server_authoritative_save_contract.md](/G:/PixelMania/pixel-mania/docs/server_authoritative_save_contract.md)
- Client already sends validated transactional intents (`inventory_transaction_request`, world updates, pickup messages).
- Production network path already uses HTTPS/WSS and session-based identity.

## What this rollout now adds

- Full PostgreSQL schema for permanent truth:
  - [postgres_security_foundation.sql](/G:/PixelMania/pixel-mania/docs/postgres_security_foundation.sql)
- Backend persistence wiring:
  - startup waits for PostgreSQL initialization
  - existing JSON accounts/players/worlds import into PostgreSQL on first empty DB run
- accounts, player state, inventory snapshots, world state, world locks, admin actions, and world snapshots write to PostgreSQL when ready
- JSON files remain local migration/backups, not the preferred source once PostgreSQL has data
- legacy client inventory import is disabled by default; enable `ALLOW_LEGACY_PLAYER_STATE_IMPORT=true` only for a controlled migration window
- Dupe prevention primitives:
  - `idempotency_keys`
  - immutable ledgers (`item_transactions`, `gem_ledger`)
  - indexed audit trails for world, trade, vending, admin, and security events
- Rollback readiness:
  - `world_block_changes` + `world_snapshots`
- Enforcement surfaces:
  - `punishments`, `world_members`, `world_lock_access`

## Table coverage against requested model

- `accounts`: yes
- `players`: yes
- `worlds`: yes
- `world_members`: yes
- `world_locks`: yes
- `inventory`: yes
- `item_instances`: yes; tracked equipment/tool-style inventory now reconciles into unique item rows with `PM-ITEM-*` public IDs, source/location fields, and `item_instance_events` history. Trade, vending, drop pickup, and item-ledger paths now keep tracked rows aligned with inventory balances.
- `item_transactions`: yes
- `gem_ledger`: yes
- `trades`: yes
- `vending_transactions`: yes
- `shop_purchases`: yes
- `admin_actions`: yes
- `world_block_changes`: yes
- `world_snapshots`: yes
- `security_events`: yes
- `sessions`: yes
- `punishments` (ban/mute/etc.): yes; schema, Postgres helpers, admin commands, and request-pipeline enforcement are wired.

## Recommended implementation order

1. Schema + migrations
- Apply `postgres_security_foundation.sql` to staging DB.
- Set `POSTGRES_ENABLED=true` and `POSTGRES_AUTHORITATIVE=true`.
- Optionally set `POSTGRES_AUTO_BOOTSTRAP=true` only in controlled environments where the app may apply the foundation SQL itself.

2. Auth/session hardening
- `accounts` + `sessions` are mirrored/written by the backend.
- Next hardening pass should move token validation directly against `sessions` instead of the compatibility `account_state` JSON.

3. Inventory transaction truth path
- Every successful inventory mutation writes:
  - `inventory` (current state)
  - `item_transactions` (immutable event)
  - `gem_ledger` when currency changes
- Use one DB transaction for each server gameplay transaction.

4. World mutation audit path
- On block place/break/hit, write `world_block_changes` in same transaction as world state mutation.
- Snapshot on interval and on last-player-leave into `world_snapshots`.

5. Economy systems
- Trades: `trades` + `trade_items` + matching `item_transactions`.
- Vending/shop: `vending_transactions` / `shop_purchases` + matching ledger entries.

6. Security and moderation
- Log suspicious events in `security_events` (rate-limit triggers, invalid pickup attempts, invalid lock checks, rejected admin commands).
- Enforce `punishments` in request pipeline before action validation once `/ban`, `/mute`, and related admin commands are enabled.

## Anti-dupe rules (server side)

1. Require idempotency key per mutation request:
- Key format suggestion: `<player_id>:<action>:<client_request_id>`
- Store in `idempotency_keys` before processing.
- If duplicate key exists, return previous result (or safe reject).

2. Single transaction per gameplay mutation:
- Lock relevant rows (`inventory`, drop rows, trade rows, vending rows) using `FOR UPDATE`.
- Apply delta checks and final write atomically.

3. Never trust client final counts:
- Client sends intent only.
- Server computes before/after from DB rows.

4. Append-only ledgers:
- Never edit old `item_transactions` or `gem_ledger` rows except with explicit compensating transaction.

## Redis usage (optional but recommended)

- Rate limiting buckets by account/session/IP
- Short-lived session cache and websocket presence
- Async queue handoff for expensive snapshot writes

PostgreSQL remains the source of truth.

## Minimum operational checks before launch

1. Every mutation endpoint emits:
- a DB write in current-state table (`inventory`/world state)
- a DB write in ledger/audit table

2. DB transaction isolation:
- Use `READ COMMITTED` with explicit row locks at minimum.
- Use retry-on-conflict path for transaction aborts.

3. Recovery drills:
- Restore latest `world_snapshots` in staging.
- Rebuild a player inventory from `item_transactions` and compare with `inventory`.

## New feature onboarding playbook

Use this checklist for every new gameplay feature before release.

1. Define the server action contract
- Add one request/reply pair for each server mutation (for example: `my_feature_request` -> `my_feature_result`).
- Keep the request intent-only (server computes resulting amounts/changes).

2. Add authorization and hardening checks
- Require session authentication.
- Require correct world permissions where applicable.
- Apply server-side distance/range checks from current world state.
- Apply rate limiting and anti-spam checks before expensive logic.

3. Implement deterministic state transition logic
- Read authoritative player/world state from server memory and compute a deterministic delta.
- Validate stack limits, ownership, and required resources before writing.
- Keep failure reasons explicit and non-leaky.

4. Persist through PostgreSQL once per action
- Add or reuse one `postgresStore` method that performs:
  - current-state write (`inventory`, `worlds`, `players`, etc.)
  - immutable event write (`item_transactions`, `gem_ledger`, `trades`, `vending_transactions`, `shop_purchases`, `world_block_changes`, etc.) for this action.
- Keep these writes in one transaction path.

5. Emit authoritative replies and broadcasts
- Return `player_data` when inventory/equipment changes.
- Broadcast world updates only after persistence is accepted.
- Make idempotency safe (`client_request_id`, action key, optional replay-safe dedupe key).

6. Add moderation and monitoring checks
- Add `security_events` entries for suspicious rejects (range cheats, lock contention, or duplicate attempts).
- Verify Redis lock cleanup guard behavior for new lock scopes.

7. Validate on release
- `curl /health` should keep:
  - `persistence.postgres_authoritative === true`
  - `persistence.redis_ready === true`
  - `persistence.redis_stats.key_counts` stable for normal activity.
- Run both success and failure manual checks for the feature before enabling for players.
