# PixelMania Project Rules

## Backend Persistence

For backend persistence policy, read:

- `docs/backend_persistence_rules.md`

Short version:

- PostgreSQL is the permanent source of truth for durable game data.
- Redis is only for temporary live coordination such as locks, rate limits,
  presence, sessions, cooldowns, and queues.
- DigitalOcean Spaces is file/object storage for off-site backups and large
  world snapshot files.
- Local JSON is only for development, migration fallback, or emergency recovery.

When adding any durable backend feature, wire it to PostgreSQL as part of the
feature.

