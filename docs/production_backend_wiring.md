# PixelMania Production Backend Wiring

For backend persistence policy, see `docs/backend_persistence_rules.md`.
Short version: PostgreSQL is durable truth, Redis is temporary live
coordination, and DigitalOcean Spaces is file/object storage for backups and
large snapshots.

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
SELECT 'punishments', count(*) FROM punishments
UNION ALL
SELECT 'inventory', count(*) FROM inventory
UNION ALL
SELECT 'item_transactions', count(*) FROM item_transactions
ORDER BY table_name;"
```

`item_instances` rows are created for tracked equipment/tool-style inventory
during startup reconciliation and whenever player state is saved. `punishments`
rows stay at zero until admin ban/mute commands or moderation tooling call the
Postgres punishment helpers.

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
