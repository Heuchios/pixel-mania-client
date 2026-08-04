# PixelMania Backend Persistence Rules

These rules are project policy for production backend work.

## Durable Data

PostgreSQL is the permanent source of truth for durable game data.

Any new feature that stores account, player, inventory, economy, trade, shop,
vending, punishment, admin, world, item, security, or audit data must be wired to
PostgreSQL as part of the feature.

Examples of durable data:

- accounts and sessions
- player state and progression
- inventory and item instances
- item transactions and gem ledger rows
- trades, vending transactions, and shop purchases
- worlds, world members, world locks, and world access
- world block changes, world object changes, and world snapshot metadata
- admin actions, security events, bans, mutes, and punishments
- canonical transaction ledger rows for valuable economy actions

Local JSON files are only for development, migration fallback, or emergency
local recovery. They are not the preferred permanent production store once
PostgreSQL is ready.

## Live Temporary Data

Redis is for live temporary coordination, not permanent truth.

Use Redis for:

- rate limits
- presence markers
- active-session markers
- short-lived locks
- cooldowns
- queues
- temporary multiplayer coordination

Redis data must be safe to lose or rebuild from PostgreSQL/player reconnects.

## File/Object Storage

DigitalOcean Spaces is the object storage layer.

Use Spaces for:

- off-site PostgreSQL backup copies
- large world snapshot JSON files
- future large world/archive files that should not live inline in PostgreSQL

PostgreSQL should keep metadata, checksums, ownership, timing, and storage URIs
for object-stored files.

## Item Instance Tracking

Stackable common items may be tracked as inventory counts.

Valuable, rare, equipment, locks, tools, event, shop, quest, crafting, vending,
trade, or admin-created items must have a tracked `item_instances` row with a
stable `PM-ITEM-*` public ID.

When adding a new valuable item source or movement path:

1. Create or move the specific item instance, not only the item count.
2. Record a clear source such as `shop`, `event`, `quest`, `crafting`, `trade`,
   `vending`, `world_drop`, `admin`, or `reconcile`.
3. Keep owner, location, state, transaction, and event history aligned.
4. Use the anti-dupe audit/admin tools to check for duplicate IDs, impossible
   state/location combinations, and inventory count mismatches.

## Transaction Ledger

Every valuable economy action must write a permanent `transaction_ledger` row in
PostgreSQL as part of the same successful database transaction whenever
possible.

Examples include shop purchases, completed trades, vending buys, admin
give/remove, crafting/furnace outputs, fishing rewards, world lock placement,
item drops, and item pickups.

Ledger rows should include the action type, player/counterparty/world, item
type/category, quantity, `PM-ITEM-*` instance ID for tracked rare items,
gem/inventory before-after context when available, request/correlation IDs,
network/session/device context when available, server time, status, and metadata
that explains source and reason.

Successful, rejected/failed, and rollback/reversal paths should all leave
ledger evidence. Use `status = success` for completed actions, `status = failed`
for rejected valuable attempts, and `status = reversed` or a `ROLLBACK_*`
transaction type when rollback tooling restores or removes durable economy
state.

Developer/admin lookup tools should be able to inspect transaction ledger rows
by player, `PM-ITEM-*` public ID, item type, transaction type, or status.

## Gem Ledger

Every gem balance change must write a permanent `gem_ledger` row in PostgreSQL.
Gems must not be changed silently with direct balance mutations.

Each `gem_ledger` row should include the player, positive or negative delta,
reason/source, before balance, after balance, reference type/id, server time,
and useful metadata. The matching `transaction_ledger` row should link the
`gem_ledger_id` when the gem movement is part of a valuable action.

Gem movements that must stay ledgered include admin grants/removals, shop
purchases, fish or reward payouts, trade gem sends/receives, vending gem flows
if added later, drop pickup gem rewards, rollback adjustments, and every future
quest/event/crafting/reward source.

## World Change Journal

Worlds must not rely only on final saved state. Important world edits need
permanent journal rows in PostgreSQL so rollback and investigations can explain
what changed, who changed it, and when.

Block edits use `world_block_changes` and should include world, actor, layer,
grid position, old block ID, new block ID, action/reason such as place, break,
hit, admin, or rollback, timing, source/request IDs, and useful metadata.

Interactive object edits use `world_object_changes` and should include world,
actor, object type, object ID, grid position where available, old JSON data, new
JSON data, action/reason, timing, source/request IDs, and metadata.

Object journal coverage includes world locks, wooden entrances, doors, signs,
toggle objects, safes, vending machines, and future durable world objects. When
adding a new world object, write an old/new object journal row as part of the
same PostgreSQL transaction that saves the new world state whenever possible.

## Rollback System

Rollback actions must be auditable PostgreSQL corrections, not silent data
rewrites. Use rollback tooling that writes `rollback_jobs`, `item_transactions`,
`gem_ledger`, `transaction_ledger`, `item_instance_events`,
`world_block_changes`, `world_object_changes`, or `world_snapshots` rows as
appropriate.

Supported rollback levels:

- player rollback: reverse one player's inventory/gem movements after a point
  in time
- world rollback: restore one world from a saved snapshot, or restore to an
  exact timestamp by selecting the nearest prior snapshot and replaying
  `world_block_changes` / `world_object_changes` up to the target time
- item rollback: freeze, retire, flag, transfer, or unfreeze one exact
  `PM-ITEM-*` instance
- transaction reversal: reverse one bad `transaction_ledger` row or
  transaction group

Do not delete investigation records. Original transaction rows should be marked
`status = reversed` with rollback metadata. Rollback correction rows should use
`source = rollback`, a clear `ROLLBACK_*` transaction type, and metadata such as
`rollback_applied`, `admin_corrected`, `rollback_job_id`, and
`rollback_reason`.

## Server-Side Validation

The client only requests valuable actions. The server must decide whether the
action is allowed using authoritative world, inventory, account, permission,
cooldown, distance, and PostgreSQL state.

Every valuable action must validate the relevant server-side facts before
committing durable state:

- build/break/place permission, world lock access, and world-ban status
- player reach/distance and cooldown/rate limits
- item ownership, item category, tradeability, vendability, dropability, and
  inventory capacity
- current vending/safe/drop/trade state, stock, and live mutation locks
- gem balance, item balance, and PostgreSQL transaction preconditions
- admin/developer role and developer PIN unlock for privileged actions

Actions that wait on PostgreSQL or Redis must not keep trusting stale client or
pre-await state. Use live action locks and final revalidation for contested
resources such as trades, vending machines, safes, drops, and future shared
economy objects.

Run `npm run check:server-validation` before deploying backend/security/economy
changes. It is also part of `npm run check:security`.

## Anti-Dupe Transaction Locking

Valuable item and currency movement must be protected by both live locks and
PostgreSQL transaction locks.

Use live Redis/local locks for contested multiplayer resources before the
database transaction starts:

- player inventory locks for any durable inventory mutation
- two-player inventory locks for trade finalization
- vending-machine locks plus buyer/owner inventory locks for vending buys
- drop locks plus picker inventory locks for drop pickup
- safe/vending object locks for safe and vending mutations

Acquire multi-player inventory locks in a stable sorted order. Release locks in
`finally` blocks so failures, exceptions, or rejected actions cannot leave local
resources stuck forever. Redis lock TTLs are temporary protection only; the
database remains permanent truth.

Inside PostgreSQL, the durable move must run in one transaction and use row-level
locks (`FOR UPDATE`) on affected inventory and item instance rows before
validating balances, moving exact `PM-ITEM-*` rows, writing ledgers, and
committing. If any step fails, the transaction rolls back and no partial item or
currency movement should survive.

Never allow two buyers to purchase the same vending stock at once, two players
to claim the same world drop, or a trade to finalize while either inventory is
being changed by another valuable action.

Run `npm run check:anti-dupe` before deploying economy changes. It is also part
of `npm run check:security`.

## Admin Action Logs

Every developer/admin action must leave an audit row in PostgreSQL
`admin_actions` through `logAdminAction()`. Local `admin_actions.log` is only a
secondary mirror.

Admin logs should include:

- admin username/id, role, IP, session token hash, user agent, and device info
- server-side role/PIN validation result, including denied attempts
- action type, target type/id, target player/world where relevant
- item/gem/world affected, amount/delta, reason, request id, and timestamp
- before/after values or compact hashes/summaries for mutable state

Admin commands and dev-panel tools must validate the actor on the server with
`isAdmin()` and developer PIN unlock where required. Hidden UI is not security.
When adding a new admin command, log both success and denied/failed paths and
include enough metadata to investigate abuse, mistakes, or rollback needs later.

Run `npm run check:admin-actions` before deploying admin/security changes. It
is also part of `npm run check:security`.

## Account / Session Security

Account and session security must stay server-authoritative and auditable.

Accounts should use a strong password hashing algorithm with stored algorithm
metadata so future migrations can be audited. Sessions should store only token
hashes, not raw tokens. Login/session flows should track IP, user agent, device
metadata, issued/expiry times, refresh-token rotation, revoked sessions, and
one-active-session or multi-session policy in PostgreSQL.

Login attempts must be rate-limited by IP and account, preferably through Redis
with local fallback, and written to PostgreSQL `account_login_attempts` plus
the existing security event stream. Successful, failed, expired, rate-limited,
and punishment-blocked authentication attempts should leave evidence.

Admin/developer access needs stronger protection than hidden UI. Admins should
use server-side role checks, developer PIN unlock, optional TOTP 2FA,
admin-command cooldowns, optional confirmation tokens for dangerous commands,
and PostgreSQL `admin_actions` audit rows for both denied and successful
paths.

Run `npm run check:account-security` before deploying account, session, login,
or admin-auth changes. It is also part of `npm run check:security`.

## Bot / Rate-Limit Protection

Gameplay request throttles are server-side security controls. The client may
request actions quickly, but the server must enforce limits before expensive
validation, inventory movement, world mutation, or PostgreSQL work.

Use Redis-backed rate buckets when Redis is ready, with local per-socket
fallback if Redis is unavailable. Rate-limit state is temporary live data and
must be safe to lose.

The bot/rate-limit baseline must cover:

- block places per second
- block breaks/hits per second
- drop pickup attempts per second
- chat messages per second
- trade requests per minute
- world joins per minute
- login attempts per IP/account
- vending purchases per second

Rejected bot/rate-limit attempts should notify the client and leave throttled
security evidence without spamming logs. Tune limits through env variables
rather than hard-coded gameplay edits when production traffic grows.

Run `npm run check:bot-rate-limits` before deploying gameplay networking,
rate-limit, login, or bot-protection changes. It is also part of
`npm run check:security`.

## Integrity Hashes

Important mutable state must carry integrity hashes so corruption, manual
database edits, bad migrations, and unexpected economy changes can be detected
later.

Current hash baseline:

- `players.inventory_hash` stores the current authoritative inventory hash.
- `transaction_ledger.transaction_hash` stores a deterministic hash of each
  ledger row payload.
- `world_snapshots.snapshot_hash` stores a stable hash of inline snapshot JSON
  when available, while legacy `checksum` stays for compatibility.
- `integrity_audit_runs` stores audit summaries and issue samples.

The integrity audit should check:

- stored player inventory hash matches current `inventory` rows
- transaction hash matches the immutable ledger payload
- world snapshot hash matches inline snapshot JSON when present
- inventory counts have item-ledger evidence
- gem balance has gem-ledger evidence
- rare `PM-ITEM-*` instances have sane owner/location state
- vending items are not also present in player inventory

Legacy rows created before hash wiring may show as missing-hash notices. Hash
mismatches are higher severity and should be investigated before assuming a
player report or admin action is clean.

Run `npm run check:integrity-hashes` before deploying backend/security/economy
changes. On production, run `npm run integrity:hash-audit -- --limit 200` for a
real PostgreSQL audit. The wiring check is also part of
`npm run check:security`.

## Monitoring Dashboard

Admin monitoring must be server-authoritative and read-only from the client.
The client may request dashboard data, but the server decides whether the actor
is an admin/developer with the required PIN/2FA state and writes an
`admin_actions` audit row for both denied and successful dashboard access.

The dashboard baseline should show:

- online/authenticated players and connected sockets
- saved and loaded world counts
- server loop/TPS/tick-lag health
- dupe and integrity warning summaries
- top gem gainers from `gem_ledger`
- top item gainers from `item_transactions`
- suspicious accounts from `security_events`

Dashboard data must come from live server state plus PostgreSQL aggregates.
Redis may help with live counters later, but it must not become the permanent
truth for monitoring history. New security/economy systems should add dashboard
signals from their durable PostgreSQL tables when useful.

Run `npm run check:monitoring-dashboard` before deploying dashboard/security
changes. It is also part of `npm run check:security`.

## Implementation Rule

When adding a new backend feature:

1. Decide whether the data is durable, temporary, or file/archive data.
2. Persist durable data in PostgreSQL.
3. Use Redis only for live/temporary helpers.
4. Use Spaces for large files or off-site copies.
5. Keep local JSON fallback scoped to development/migration/emergency use.
