# PixelMania Postgres Backup + Restore Runbook

PostgreSQL is the permanent source of truth for accounts, player state, worlds,
inventory, ledgers, trades, vending, shop purchases, admin actions, security
events, sessions, and punishments. Redis is a live helper layer only, so Redis
does not need permanent backups for game recovery.

## Backup Now

Run this on the droplet:

```bash
cd ~/PixelManiaServer
./scripts/postgres_backup.sh
```

Default backup location:

```text
/var/backups/pixelmania/postgres
```

The script writes a timestamped `.dump`, updates `latest.dump`, writes a
SHA-256 file when `sha256sum` is available, and prunes backups older than 14
days.

## Restore Test

Run this on the droplet after creating a backup:

```bash
cd ~/PixelManiaServer
./scripts/postgres_restore_check.sh
```

The restore check creates a separate database named
`pixelmania_restore_check`, restores the latest backup there, prints counts for
core tables, then drops the test database. It does not touch the production
`pixelmania` database.

To test a specific backup:

```bash
cd ~/PixelManiaServer
./scripts/postgres_restore_check.sh /var/backups/pixelmania/postgres/pixelmania_postgres_pixelmania_YYYYMMDDTHHMMSSZ.dump
```

To keep the restored test database for manual inspection:

```bash
cd ~/PixelManiaServer
PIXELMANIA_KEEP_RESTORE_CHECK_DB=true ./scripts/postgres_restore_check.sh
```

Drop it later:

```bash
sudo -u postgres dropdb --if-exists pixelmania_restore_check
```

## Schedule Backups

Use the new maintenance script for cron-friendly operations:

```bash
cd ~/PixelManiaServer

# Check local backup tools/directories, latest dump, optional off-site target,
# and optional alert webhook readiness
./scripts/postgres_maintenance.sh preflight

# One-off backup
./scripts/postgres_maintenance.sh backup

# Restore-check using latest backup
./scripts/postgres_maintenance.sh restore-check

# Copy-only task (uses PIXELMANIA_POSTGRES_OFFSITE_TARGET if set)
./scripts/postgres_maintenance.sh copy-only

# Send a real test alert to PIXELMANIA_POSTGRES_MAINT_ALERT_WEBHOOK
./scripts/postgres_maintenance.sh alert-test
```

Ensure the script is executable:

```bash
cd ~/PixelManiaServer
chmod +x scripts/postgres_maintenance.sh
```

## Preflight Before Cron

Before enabling unattended cron jobs, run a preflight check on the droplet:

```bash
cd ~/PixelManiaServer
./scripts/postgres_maintenance.sh preflight
```

For off-server copy checks, pass the same off-site target you plan to use in
cron:

```bash
cd ~/PixelManiaServer
PIXELMANIA_POSTGRES_OFFSITE_TARGET='user@backup-host:/srv/pixelmania-backups' ./scripts/postgres_maintenance.sh preflight
```

If you use an SSH key:

```bash
cd ~/PixelManiaServer
PIXELMANIA_POSTGRES_OFFSITE_TARGET='user@backup-host:/srv/pixelmania-backups' \
PIXELMANIA_POSTGRES_OFFSITE_KEY_PATH='/root/.ssh/pixelmania_backup_key' \
./scripts/postgres_maintenance.sh preflight
```

The preflight mode checks:

- PostgreSQL client tools (`pg_dump`, `pg_restore`, `psql`, `createdb`, `dropdb`)
- backup script executability
- primary/fallback backup directory write access
- latest backup presence
- off-site `scp` or `rsync` tool availability
- remote off-site SSH reachability and write/delete access, when configured
- DigitalOcean Spaces/AWS CLI write/list/delete access, when configured
- alert webhook configuration

To send a real webhook test during preflight:

```bash
cd ~/PixelManiaServer
PIXELMANIA_POSTGRES_MAINT_ALERT_WEBHOOK='https://your-webhook.example/hook' \
PIXELMANIA_POSTGRES_PREFLIGHT_SEND_ALERT=true \
./scripts/postgres_maintenance.sh preflight
```

Or send only the alert test:

```bash
cd ~/PixelManiaServer
PIXELMANIA_POSTGRES_MAINT_ALERT_WEBHOOK='https://your-webhook.example/hook' ./scripts/postgres_maintenance.sh alert-test
```

Preflight output is written to:

```text
/var/log/pixelmania-postgres-maintenance.log
```

The command also prints the log path when it finishes.

Install cron jobs on the droplet:

```bash
sudo crontab -e
```

Add:

```cron
# Keep backups hourly
15 * * * * cd /root/PixelManiaServer && ./scripts/postgres_maintenance.sh backup >> /var/log/pixelmania-postgres-backup.log 2>&1

# Weekly restore validation (light check to confirm dump can be replayed to a temp DB)
30 4 * * 0 cd /root/PixelManiaServer && PIXELMANIA_POSTGRES_BACKUP_DIR=/var/backups/pixelmania/postgres ./scripts/postgres_maintenance.sh restore-check >> /var/log/pixelmania-postgres-restore-check.log 2>&1

# Daily remote copy of latest dump (if PIXELMANIA_POSTGRES_OFFSITE_TARGET is defined)
45 3 * * * cd /root/PixelManiaServer && PIXELMANIA_POSTGRES_OFFSITE_TARGET='user@backup-host:/srv/pixelmania-backups' ./scripts/postgres_maintenance.sh copy-only >> /var/log/pixelmania-postgres-offsite.log 2>&1
```

Check recent backup logs:

```bash
sudo tail -n 80 /var/log/pixelmania-postgres-backup.log
sudo tail -n 80 /var/log/pixelmania-postgres-restore-check.log
sudo tail -n 80 /var/log/pixelmania-postgres-offsite.log
ls -lah /var/backups/pixelmania/postgres
```

## Configure DigitalOcean Spaces Off-Site Copy

DigitalOcean Spaces is S3-compatible object storage. The maintenance script
supports it through the AWS CLI.

Create a Space in the DigitalOcean control panel, then create a Spaces access
key. Keep the secret key private; DigitalOcean shows it only once.

Install the AWS CLI on the droplet:

```bash
cd /tmp
sudo apt update
sudo apt install -y unzip curl
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip -q awscliv2.zip
sudo ./aws/install --update
aws --version
```

Configure credentials for the root user on the droplet:

```bash
mkdir -p /root/.aws
read -rp "Spaces access key: " DO_SPACES_KEY
read -rsp "Spaces secret key: " DO_SPACES_SECRET
echo
cat > /root/.aws/credentials <<EOF
[default]
aws_access_key_id = $DO_SPACES_KEY
aws_secret_access_key = $DO_SPACES_SECRET
EOF
cat > /root/.aws/config <<EOF
[default]
region = tor1
request_checksum_calculation = when_required
response_checksum_validation = when_required
EOF
chmod 700 /root/.aws
chmod 600 /root/.aws/credentials /root/.aws/config
unset DO_SPACES_KEY DO_SPACES_SECRET
```

Use the region where you created the Space, such as `nyc3`, `sfo3`, `ams3`,
`sgp1`, `fra1`, or `tor1`.

Set these values for one-off tests:

```bash
SPACE_NAME='YOUR_SPACE_NAME'
export PIXELMANIA_POSTGRES_OFFSITE_METHOD='spaces'
export PIXELMANIA_POSTGRES_OFFSITE_REGION='tor1'
export PIXELMANIA_POSTGRES_OFFSITE_ENDPOINT='https://tor1.digitaloceanspaces.com'
export PIXELMANIA_POSTGRES_OFFSITE_TARGET="s3://${SPACE_NAME}/postgres"
export AWS_REQUEST_CHECKSUM_CALCULATION='when_required'
export AWS_RESPONSE_CHECKSUM_VALIDATION='when_required'
```

Run preflight and copy tests:

```bash
cd ~/PixelManiaServer
./scripts/postgres_maintenance.sh preflight
./scripts/postgres_maintenance.sh copy-only
aws --endpoint-url "$PIXELMANIA_POSTGRES_OFFSITE_ENDPOINT" s3api list-objects-v2 \
  --bucket "$SPACE_NAME" \
  --prefix postgres/ \
  --output json
```

The upload writes:

```text
s3://YOUR_SPACE_NAME/postgres/pixelmania_postgres_pixelmania_YYYYMMDDTHHMMSSZ.dump
s3://YOUR_SPACE_NAME/postgres/pixelmania_postgres_pixelmania_YYYYMMDDTHHMMSSZ.dump.sha256
s3://YOUR_SPACE_NAME/postgres/latest.dump
s3://YOUR_SPACE_NAME/postgres/latest.dump.sha256
```

After testing, add the daily off-site copy cron job:

```bash
( crontab -l 2>/dev/null | grep -v 'postgres_maintenance.sh copy-only'; cat <<'CRON'
45 3 * * * cd /root/PixelManiaServer && PIXELMANIA_POSTGRES_OFFSITE_METHOD='spaces' PIXELMANIA_POSTGRES_OFFSITE_REGION='tor1' PIXELMANIA_POSTGRES_OFFSITE_ENDPOINT='https://tor1.digitaloceanspaces.com' PIXELMANIA_POSTGRES_OFFSITE_TARGET='s3://YOUR_SPACE_NAME/postgres' AWS_REQUEST_CHECKSUM_CALCULATION='when_required' AWS_RESPONSE_CHECKSUM_VALIDATION='when_required' ./scripts/postgres_maintenance.sh copy-only >> /var/log/pixelmania-postgres-offsite.log 2>&1
CRON
) | crontab -
```

Check off-site logs:

```bash
sudo tail -n 80 /var/log/pixelmania-postgres-offsite.log
aws --endpoint-url https://tor1.digitaloceanspaces.com s3api list-objects-v2 \
  --bucket "$SPACE_NAME" \
  --prefix postgres/ \
  --output json
```

## Configure DigitalOcean Spaces World Snapshots

PostgreSQL remains the permanent truth database for live world state. This
optional mode uploads full world snapshot JSON archives to Spaces and stores the
snapshot checksum plus `s3://...` storage URI in the `world_snapshots` table.

Use the same Spaces credentials configured above. Add these values to
`~/PixelManiaServer/.env`:

```env
WORLD_SNAPSHOT_STORAGE=spaces
WORLD_SNAPSHOT_SPACES_REGION=tor1
WORLD_SNAPSHOT_SPACES_ENDPOINT=https://tor1.digitaloceanspaces.com
WORLD_SNAPSHOT_SPACES_TARGET=s3://pixelmania-backups/world_snapshots
WORLD_SNAPSHOT_POSTGRES_INLINE=false
```

Reload the backend:

```bash
cd ~/PixelManiaServer
pm2 startOrReload ecosystem.config.js --env production --update-env
```

Confirm the health payload reports Spaces snapshot config:

```bash
curl -s https://api.pixelmaniagame.com/health | python3 -m json.tool
```

Expected fields:

```json
{
  "persistence": {
    "world_snapshot_storage": {
      "mode": "spaces",
      "spaces_enabled": true,
      "spaces_target_configured": true,
      "spaces_endpoint_configured": true,
      "postgres_inline": false
    }
  }
}
```

Create a manual snapshot from the in-game developer/admin command panel:

```text
/snapshot START
```

Replace `START` with another world name when needed. Then verify the uploaded
objects:

```bash
aws --endpoint-url https://tor1.digitaloceanspaces.com s3api list-objects-v2 \
  --bucket pixelmania-backups \
  --prefix world_snapshots/ \
  --output json
```

If Spaces upload fails, the server still keeps the local snapshot under
`WORLD_SNAPSHOT_FOLDER` and records that local path in PostgreSQL.

## Configure DigitalOcean Spaces Retention

Use lifecycle rules so backup/snapshot objects do not grow forever.

Recommended starting policy:

- `postgres/`: expire objects after 90 days
- `world_snapshots/`: expire objects after 180 days
- incomplete multipart uploads: remove after 7 days

Apply the lifecycle policy:

```bash
cat > /tmp/pixelmania-spaces-lifecycle.json <<'JSON'
{
  "Rules": [
    {
      "ID": "expire-postgres-backups-after-90-days",
      "Status": "Enabled",
      "Filter": {
        "Prefix": "postgres/"
      },
      "Expiration": {
        "Days": 90
      }
    },
    {
      "ID": "expire-world-snapshots-after-180-days",
      "Status": "Enabled",
      "Filter": {
        "Prefix": "world_snapshots/"
      },
      "Expiration": {
        "Days": 180
      }
    },
    {
      "ID": "abort-incomplete-multipart-uploads-after-7-days",
      "Status": "Enabled",
      "Filter": {
        "Prefix": ""
      },
      "AbortIncompleteMultipartUpload": {
        "DaysAfterInitiation": 7
      }
    }
  ]
}
JSON

AWS_REQUEST_CHECKSUM_CALCULATION='when_required' \
AWS_RESPONSE_CHECKSUM_VALIDATION='when_required' \
aws --endpoint-url https://tor1.digitaloceanspaces.com s3api put-bucket-lifecycle-configuration \
  --bucket pixelmania-backups \
  --lifecycle-configuration file:///tmp/pixelmania-spaces-lifecycle.json
```

Verify the lifecycle policy:

```bash
AWS_REQUEST_CHECKSUM_CALCULATION='when_required' \
AWS_RESPONSE_CHECKSUM_VALIDATION='when_required' \
aws --endpoint-url https://tor1.digitaloceanspaces.com s3api get-bucket-lifecycle-configuration \
  --bucket pixelmania-backups \
  --output json
```

If AWS CLI returns `argument of type 'NoneType' is not a container or iterable`
for lifecycle commands, configure the same rules with `s3cmd` instead:

```bash
sudo apt update
sudo apt install -y s3cmd

DO_SPACES_KEY="$(awk -F= '/aws_access_key_id/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}' /root/.aws/credentials)"
DO_SPACES_SECRET="$(awk -F= '/aws_secret_access_key/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}' /root/.aws/credentials)"

cat > /root/.s3cfg <<EOF
[default]
access_key = $DO_SPACES_KEY
secret_key = $DO_SPACES_SECRET
host_base = tor1.digitaloceanspaces.com
host_bucket = %(bucket)s.tor1.digitaloceanspaces.com
use_https = True
check_ssl_certificate = True
check_ssl_hostname = True
signature_v2 = False
EOF

chmod 600 /root/.s3cfg
unset DO_SPACES_KEY DO_SPACES_SECRET

cat > /tmp/pixelmania-spaces-lifecycle.xml <<'XML'
<LifecycleConfiguration xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <Rule>
    <ID>expire-postgres-backups-after-90-days</ID>
    <Status>Enabled</Status>
    <Prefix>postgres/</Prefix>
    <Expiration>
      <Days>90</Days>
    </Expiration>
  </Rule>
  <Rule>
    <ID>expire-world-snapshots-after-180-days</ID>
    <Status>Enabled</Status>
    <Prefix>world_snapshots/</Prefix>
    <Expiration>
      <Days>180</Days>
    </Expiration>
  </Rule>
  <Rule>
    <ID>abort-incomplete-multipart-uploads-after-7-days</ID>
    <Status>Enabled</Status>
    <Prefix></Prefix>
    <AbortIncompleteMultipartUpload>
      <DaysAfterInitiation>7</DaysAfterInitiation>
    </AbortIncompleteMultipartUpload>
  </Rule>
</LifecycleConfiguration>
XML

s3cmd --config=/root/.s3cfg setlifecycle /tmp/pixelmania-spaces-lifecycle.xml s3://pixelmania-backups
s3cmd --config=/root/.s3cfg getlifecycle s3://pixelmania-backups
```

## Configure SSH Off-Server Copy

The maintenance job supports simple `scp` or `rsync` target sync.

Set these envs in the cron line (or in a small shell wrapper file):

```bash
export PIXELMANIA_POSTGRES_OFFSITE_TARGET="user@backup-host:/srv/pixelmania/postgres"
export PIXELMANIA_POSTGRES_OFFSITE_METHOD="scp"
```

Example cron line for off-server copy with SSH key:

```cron
45 3 * * * cd /root/PixelManiaServer && PIXELMANIA_POSTGRES_OFFSITE_TARGET='root@backup-host:/srv/pixelmania/postgres' PIXELMANIA_POSTGRES_OFFSITE_KEY_PATH='/root/.ssh/pixelmania_backup_key' /root/PixelManiaServer/scripts/postgres_maintenance.sh copy-only >> /var/log/pixelmania-postgres-offsite.log 2>&1
```

On the droplet, backups protect against bad deploys/patch errors. Off-server
copies protect against droplet loss.

Tip: if you use the backup script directly (not maintenance), pass
`PIXELMANIA_POSTGRES_BACKUP_DIR` and `PIXELMANIA_POSTGRES_BACKUP_FALLBACK_DIR`
in the same way and copy `latest.dump` after each run.

## Emergency Production Restore

Only do this when you intentionally want to replace production data.

1. Stop the game server:

```bash
pm2 stop pixelmania
```

2. Backup current production first:

```bash
cd ~/PixelManiaServer
./scripts/postgres_backup.sh
```

3. Restore into a test database first:

```bash
./scripts/postgres_restore_check.sh /path/to/backup.dump
```

4. Replace production:

```bash
sudo -u postgres dropdb --if-exists pixelmania
sudo -u postgres createdb pixelmania
sudo -u postgres pg_restore --dbname=pixelmania --no-owner --no-privileges /path/to/backup.dump
```

5. Restart and verify:

```bash
pm2 startOrReload ecosystem.config.js --env production --update-env
curl -s https://api.pixelmaniagame.com/health
pm2 logs pixelmania --lines 80
```

## Optional Alerting

Maintenance failures can be posted to a webhook (for example, Discord webhook or
internal chat bot) by setting:

```bash
export PIXELMANIA_POSTGRES_MAINT_ALERT_WEBHOOK='https://your-webhook.example/hook'
```

If set, failures in `postgres_maintenance.sh` post a short JSON payload.

Example:

```json
{"text":"PixelMania postgres maintenance failed: mode=full failed (exit 1)"}
```
