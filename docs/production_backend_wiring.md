# PixelMania Production Backend Wiring

For backend persistence policy, see `docs/backend_persistence_rules.md`.
Short version: PostgreSQL is durable truth, Redis is temporary live
coordination, and DigitalOcean Spaces is file/object storage for backups and
large snapshots.

For the 10,000-player scale target and rollout gates, see
`docs/scale_readiness_10k.md`.

Recommended public/private path:

```text
Player client
  -> https://api.pixelmaniagame.com / wss://api.pixelmaniagame.com/ws
  -> Cloudflare
  -> Caddy on :80 and :443
  -> Node backend on 127.0.0.1:8080
  -> PostgreSQL / save data
```

## Backend

Node should stay local-only:

```env
HOST=127.0.0.1
PORT=8080
PUBLIC_BASE_URL=https://api.pixelmaniagame.com
PUBLIC_WS_URL=wss://api.pixelmaniagame.com/ws
PIXELMANIA_DATA_DIR=/var/lib/pixelmania
POSTGRES_ENABLED=true
POSTGRES_AUTHORITATIVE=true
POSTGRES_HOST=127.0.0.1
POSTGRES_PORT=5432
POSTGRES_DATABASE=pixelmania
POSTGRES_USER=pixelmania
POSTGRES_PASSWORD=<real database password>
POSTGRES_SSL=false
POSTGRES_SCHEMA=pixelmania
ALLOW_LEGACY_PLAYER_STATE_IMPORT=false
# Optional until multi-node/live-scale features need it.
REDIS_ENABLED=false
# REDIS_URL=redis://127.0.0.1:6379
# REDIS_KEY_PREFIX=pixelmania
```

Start or reload with PM2:

```bash
cd ~/PixelManiaServer
npm install
pm2 startOrReload ecosystem.config.js --env production
pm2 save
```

The current PM2 defaults are for the small single-node droplet. They are not a
10,000-player architecture by themselves; use the 10k scale runbook before
changing process counts, load balancers, or world sharding.

Apply the Postgres schema from the backend repo:

```bash
cd ~/PixelManiaServer
sudo -u postgres psql -d pixelmania -f docs/postgres_security_foundation.sql
```

## One-command production deploy (Windows PowerShell)

From local `backend` folder:

```powershell
powershell -ExecutionPolicy Bypass -File ./deploy_to_droplet.ps1 -RemoteIp YOUR_DROPLET_IP
```

Optional with SSH key:

```powershell
powershell -ExecutionPolicy Bypass -File ./deploy_to_droplet.ps1 -RemoteIp YOUR_DROPLET_IP -SshKeyPath C:\path\to\your_key.pem
```

Run smoke checks during deploy:

```powershell
powershell -ExecutionPolicy Bypass -File ./deploy_to_droplet.ps1 -RemoteIp YOUR_DROPLET_IP -RunSmokeChecks
```

Smoke checks (via `backend/smoke_postdeploy.ps1`) verify:

- `/health` returns `ok: true`
- PostgreSQL is ready and authoritative
- Redis is ready
- Redis health stats are present

The deploy helper also uploads executable Postgres backup/restore-check scripts
to `~/PixelManiaServer/scripts`.

On first startup with an empty PostgreSQL database, the backend imports existing
JSON accounts, player saves, and world saves into PostgreSQL. After PostgreSQL
has data, it wins on startup; JSON files remain local migration/backups.

Verify the bind address and live cache:

```bash
sudo ss -ltnp | grep -E ':80|:443|:8080'
```

Expected:

```text
127.0.0.1:8080  node
*:80            caddy
*:443           caddy
```

Health check:

```bash
curl https://api.pixelmaniagame.com/health
```

Expected health payload includes:

```json
{
  "persistence": {
    "postgres_ready": true,
    "postgres_authoritative": true,
    "redis_ready": true,
    "redis_stats": {
      "key_counts": {
        "locks": 0,
        "presence": 3,
        "active_sessions": 2
      },
      "lock_ttl_ms": {
        "min_ttl_ms": 1800,
        "near_expiry_count": 0
      }
    }
  }
}
```

Use `lock_ttl_ms.near_expiry_count` and `stale_count` to flag Redis lock pressure before rollout.

Postgres table coverage check:

```bash
sudo -u postgres psql -d pixelmania -c "
SET search_path TO pixelmania, public;
SELECT 'item_instances' AS table_name, count(*) FROM item_instances
UNION ALL
SELECT 'item_instance_events', count(*) FROM item_instance_events
UNION ALL
SELECT 'punishments', count(*) FROM punishments
UNION ALL
SELECT 'inventory', count(*) FROM inventory
UNION ALL
SELECT 'item_transactions', count(*) FROM item_transactions
UNION ALL
SELECT 'transaction_ledger', count(*) FROM transaction_ledger
ORDER BY table_name;"
```

`item_instances` rows are created or moved for tracked equipment/tool-style
inventory during startup/manual legacy reconciliation and explicit item
transaction flows such as trade, vending, safe storage, world drops, drop pickup,
and admin/shop grants. Live player-state saves do not mint missing tracked rows
from raw counts.
`item_instance_events` records the audit trail for those unique tracked items.
`transaction_ledger` is the canonical investigation trail for valuable economy
actions. It links to the specialized ledgers where possible and stores
before/after inventory hashes, source/action, status, request/correlation IDs,
network context when available, and exact `PM-ITEM-*` IDs for rare-item
movements. Completed actions write `success`, rejected valuable attempts write
`failed`, and rollback restore tooling writes `ROLLBACK_RESTORE` rows with
`reversed` status.
Anti-dupe admin tools:

```text
/itemaudit [limit]
/itemcopies item_type_or_PM-ITEM-id
/itemfreeze PM-ITEM-id reason
/itemunfreeze PM-ITEM-id reason
/itemretire PM-ITEM-id reason
/itemtransfer PM-ITEM-id username reason
/itemflag PM-ITEM-id reason
```

Before deploying item/economy changes, run:

```bash
npm run check:security
```

`check:item-instances` is the static guard for the rare-item rule: valuable item
creation must have a clear source, and trade, vending, world drop/pickup, admin,
shop, crafting, and fishing paths must keep using tracked `PM-ITEM-*` movement
helpers. `check:transaction-ledger` guards the permanent transaction ledger
schema/helper/wiring for valuable economy actions.

`check:server-validation` guards the server-authority rule for valuable actions:
block edits, trades, vending, safes, stations, fishing, drops, seeds, admin
tools, cooldowns, live locks, distance checks, ownership checks, capacity checks,
and world-ban enforcement must stay wired on the server. Clients only request;
the server validates and decides.

`check:anti-dupe` guards the transaction-locking rule for valuable movements:
shared inventory commits must lock player inventories, trades must lock both
inventories, vending buys must lock the vending machine plus buyer/owner
inventories, drop pickup must lock the drop plus picker inventory, and the
PostgreSQL trade/vending/drop paths must keep using row-level `FOR UPDATE` locks
with exact tracked `PM-ITEM-*` movement helpers.

`check:admin-actions` guards the admin audit rule: developer/admin commands
must require server-side role/PIN validation, log denied and successful attempts,
mirror to PostgreSQL `admin_actions`, and include target, affected item/world,
amount, reason, network/session context, and before/after hashes or summaries
for mutable state.

`check:account-security` guards account/session security: password hashing
algorithm metadata, hashed session/refresh tokens, refresh rotation, durable
login attempt records, IP/user-agent/device tracking, one-active-session
revocation, admin TOTP 2FA hooks, admin confirmation tokens, and admin command
cooldowns must stay wired.

`check:bot-rate-limits` guards server-side bot/rate-limit protection: block
places, block breaks/hits, pickup attempts, chat messages, trade requests,
world joins, login attempts, and vending purchases must stay throttled through
Redis with local fallback before expensive validation or database work.

`check:integrity-hashes` guards player inventory hashes, transaction ledger
hashes, world snapshot hashes, and the PostgreSQL integrity audit path.

`check:monitoring-dashboard` guards the admin Monitor tab and server-side
dashboard endpoint: online players, saved/loaded world counts, server loop
health, dupe warnings, top gem/item gainers, suspicious accounts, PostgreSQL
aggregates, and admin audit logging must stay wired.

Optional admin hardening can be enabled after deploy:

```env
ACCOUNT_ONE_ACTIVE_SESSION=true
ADMIN_2FA_REQUIRED=true
ADMIN_2FA_SECRETS=uso:BASE32_TOTP_SECRET
ADMIN_COMMAND_CONFIRMATION_REQUIRED=true
```

Do not enable `ADMIN_2FA_REQUIRED` until the admin has a valid TOTP secret and
the client/dev panel can send `totp_code`, `two_factor_code`, or
`admin_2fa_code` during developer unlock.

Snapshot scheduling should stay gentle on the 1GB droplet. Use
`WORLD_SNAPSHOT_MAX_WORLDS_PER_CYCLE=5` or lower to rotate through loaded worlds
instead of snapshotting/uploading every world at once, and keep
`WORLD_SNAPSHOT_STARTUP_RUN=false` unless a startup checkpoint is intentionally
needed. Set `WORLD_SNAPSHOT_INTERVAL_MINUTES=0` temporarily if PM2 logs show
snapshot-related restarts while diagnosing production crashes.

Rare-item live test matrix after deploy:

```text
1. Admin give: create a tracked item and confirm source=admin.
2. World drop: drop the tracked item and confirm location=world_drop.
3. Pickup: pick up the same item and confirm the same PM-ITEM id returns to inventory.
4. Trade: trade the same item and confirm owner changes without a new PM-ITEM id.
5. Vending list: list the same item and confirm location=vending/locked.
6. Vending buy: buy it and confirm owner changes without a new PM-ITEM id.
7. Vending cancel: cancel a listing and confirm location returns to inventory.
8. Audit: run /itemaudit and investigate any new duplicate, impossible, or mismatch rows.
9. Ledger: confirm transaction_ledger has rows for the action and exact PM-ITEM ids where rare. Use the developer panel Ledger lookup or SQL when investigating a player/item.
```

Old legacy items may still show `unknown`, `reconcile`, or
`inventory_snapshot_reconcile` as their source because they existed before
instance tracking was fully wired. Going forward, new valuable item sources such
as events, quests, crafting, loot boxes, or rewards must create or move the exact
tracked item instance with a clear source label.

## Rollback Tooling

Rollback tooling lives in `scripts/rollback_apply.js` and records applied jobs
in PostgreSQL `rollback_jobs`. Dry-run is the default; add `--apply` only after
reviewing the generated plan. Applying a rollback requires `--reason`.

Supported rollback levels:

- player rollback: reverse one player's inventory/gem movements after a chosen
  timestamp
- world rollback: restore one world from a snapshot and write rollback journal
  evidence
- exact-time world rollback: restore the newest snapshot before `--at`, replay
  `world_block_changes` / `world_object_changes` to that timestamp, then apply
  the replayed world state
- explicit crash recovery: `npm run world:recover` wraps the exact-time world
  recovery path for one world or all worlds. It is dry-run by default and
  requires `--confirm-server-stopped` before applying
- item rollback: retire, freeze, unfreeze, flag, or transfer one exact
  `PM-ITEM-*`
- transaction reversal: reverse one transaction ledger row or transaction group

Examples:

```bash
cd ~/PixelManiaServer

npm run rollback:apply -- player --user uso --since 2026-06-07T00:00:00Z --reason "dupe correction"
npm run rollback:apply -- player --user uso --since 2026-06-07T00:00:00Z --reason "dupe correction" --apply

npm run rollback:apply -- world --world START --latest --reason "restore before grief"
npm run rollback:apply -- world --world START --latest --reason "restore before grief" --apply

TARGET_AT="$(date -u -d '5 minutes ago' +'%Y-%m-%dT%H:%M:%SZ')"
npm run rollback:apply -- world --world START --at "$TARGET_AT" --reason "restore exact time"
npm run rollback:apply -- world --world START --at "$TARGET_AT" --reason "restore exact time" --apply

npm run world:recover -- --world START --at now
npm run world:recover -- --world START --at now --reason "recover after crash" --confirm-server-stopped --apply
npm run world:recover -- --all-worlds --at now --continue-on-error

npm run rollback:apply -- item --item-instance PM-ITEM-ABC123 --action retire --reason "duplicate copy"
npm run rollback:apply -- item --item-instance PM-ITEM-ABC123 --action transfer --target uso --reason "restore owner" --apply

npm run rollback:apply -- transaction --ledger-id 123 --reason "bad admin action"
npm run rollback:apply -- transaction --transaction-id 00000000-0000-0000-0000-000000000000 --reason "bad trade" --apply
```

Rollback corrections must not delete investigation records. The tool marks
original ledger rows `status = reversed` and writes rollback correction rows
with `source = rollback`, `rollback_applied`, `admin_corrected`,
`rollback_job_id`, and `rollback_reason` metadata.

`punishments` rows stay at zero until admin ban/mute commands or moderation
tooling call the Postgres punishment helpers.

## Backups

PostgreSQL is the permanent recovery target. Redis stores temporary live helper
data, so Redis does not need permanent recovery backups.

Create a Postgres backup on the droplet:

```bash
cd ~/PixelManiaServer
./scripts/postgres_backup.sh
```

Prove the backup can restore safely into a separate test database:

```bash
cd ~/PixelManiaServer
./scripts/postgres_restore_check.sh
```

See `docs/postgres_backup_restore_runbook.md` for cron setup, off-server copy,
and emergency restore steps.
For day-to-day ops, we now use `scripts/postgres_maintenance.sh` as a single entry
point for backup, restore-check, and off-site copy jobs.
Run `./scripts/postgres_maintenance.sh preflight` on the droplet before enabling
cron jobs so backup tools, writable paths, off-site SSH access, and optional alert
webhooks are checked once up front.
For DigitalOcean Spaces off-site backups, use `PIXELMANIA_POSTGRES_OFFSITE_METHOD=spaces`,
set the regional endpoint such as `https://tor1.digitaloceanspaces.com`, and use an
S3 target such as `s3://YOUR_SPACE_NAME/postgres`.

## World Snapshot Object Storage

PostgreSQL remains the permanent source of truth for live world state. For large
world snapshot archives, the backend can also upload snapshot JSON files to
DigitalOcean Spaces while storing the checksum and `s3://...` URI in
`world_snapshots`.

Use the same root AWS/Spaces credentials created for off-site backups, then set:

```env
WORLD_SNAPSHOT_STORAGE=spaces
WORLD_SNAPSHOT_SPACES_REGION=tor1
WORLD_SNAPSHOT_SPACES_ENDPOINT=https://tor1.digitaloceanspaces.com
WORLD_SNAPSHOT_SPACES_TARGET=s3://pixelmania-backups/world_snapshots
WORLD_SNAPSHOT_POSTGRES_INLINE=false
```

The server always writes the local snapshot file first. If Spaces upload fails,
the snapshot stays local and PostgreSQL records the local path as the fallback
storage URI.

## Integrity Hash Audit

After backend/security/economy deploys, run the wiring check and optional live
audit from the droplet:

```bash
cd ~/PixelManiaServer
npm run check:integrity-hashes
npm run integrity:hash-audit -- --limit 200
```

The live audit recomputes player inventory hashes, transaction ledger hashes,
and inline world snapshot hashes, then stores the result in
`integrity_audit_runs`. Missing hashes on legacy rows are notices. Hash
mismatches, impossible rare-item states, or vending/inventory collisions should
be investigated before trusting the affected economy state.

## Caddy

Caddy can proxy HTTPS and WSS to the same local Node service:

```caddyfile
api.pixelmaniagame.com {
    encode gzip
    reverse_proxy 127.0.0.1:8080
}
```

Caddy handles WebSocket upgrades automatically, so `wss://api.pixelmaniagame.com/ws` reaches the backend as long as the DNS record points at the droplet.

## Firewall

Only expose public ports:

```bash
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw deny 8080/tcp
sudo ufw enable
sudo ufw status verbose
```

Do not open `8080` in DigitalOcean Cloud Firewall.

## Secrets

Keep production secrets in `~/PixelManiaServer/.env`; do not commit real database or SMTP passwords.

Rotate the local Postgres user password:

```bash
DB_PASS=$(openssl rand -hex 32)
echo "New Postgres password: $DB_PASS"
sudo -u postgres psql -d pixelmania -c "ALTER USER pixelmania WITH PASSWORD '$DB_PASS';"
```

Then put the same value in `~/PixelManiaServer/.env` as `POSTGRES_PASSWORD`.

Minimum SMTP entries:

```env
SMTP_HOST=<smtp host>
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USER=<smtp username>
SMTP_PASS=<smtp password or app password>
SMTP_FROM=PixelMania <no-reply@pixelmaniagame.com>
TEST_EMAIL_TO=<your test inbox>
```

Test email delivery:

```bash
cd ~/PixelManiaServer
npm run email:test -- your@email.com
```

## Client

Godot should use the public domain only:

```gdscript
const API_BASE := "https://api.pixelmaniagame.com"
const WS_URL := "wss://api.pixelmaniagame.com/ws"
```

The client should never connect to the droplet IP or `:8080` directly in production.
