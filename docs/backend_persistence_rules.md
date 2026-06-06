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
- world block changes and world snapshot metadata
- admin actions, security events, bans, mutes, and punishments

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

## Implementation Rule

When adding a new backend feature:

1. Decide whether the data is durable, temporary, or file/archive data.
2. Persist durable data in PostgreSQL.
3. Use Redis only for live/temporary helpers.
4. Use Spaces for large files or off-site copies.
5. Keep local JSON fallback scoped to development/migration/emergency use.

