# PixelMania Codex Handoff Status

Last updated: 2026-07-02

This document exists so a fresh Codex chat can continue from the current
backend/security state without relying on chat memory.

## Latest Verified Status

### Netfox Movement / Server Handoff (2026-07-02)

Current goal: transition player movement to Netfox while keeping the existing
backend authoritative for login/auth, world loading, inventory, actions,
persistence, drops, moderation, and economy. Netfox should own movement only;
do not replace the whole backend with Netfox.

Production Netfox status:

- A production Netfox movement server process exists on the droplet
  `165.227.33.94` as PM2 app `pixelmania-netfox-start`.
- The current production Netfox server is for world `START` on UDP port `24566`.
- Route registration and lookup were verified after fixing the token/hash
  mismatch. The verifier showed manual route registration `ok: true` and route
  lookup `ok: true` for `START -> 165.227.33.94:24566`.
- Server logs showed successful world loading from the backend with collision
  data present, and route registration similar to
  `Netfox route registered... public=165.227.33.94:24566`.
- Backend `.env` and the PM2 backend environments must use the same
  `NETFOX_SERVER_WORLD_STATE_TOKEN_HASH`, which is the SHA256 hash of the raw
  token passed to the Netfox server via `--netfox-server-token`. Do not commit
  or document the raw token.

Useful verification commands:

```powershell
.\Scripts\verify_netfox_server_route.ps1 -World START -NetfoxHost 165.227.33.94 -Port 24566 -ServerToken $env:NETFOX_TOKEN -Register
ssh root@165.227.33.94 "pm2 list; pm2 logs pixelmania-netfox-start --lines 120 --nostream"
ssh root@165.227.33.94 "cd ~/PixelManiaServer && grep -n '^NETFOX_' .env && pm2 env 6 | grep NETFOX_SERVER_WORLD_STATE_TOKEN_HASH && pm2 env 1 | grep NETFOX_SERVER_WORLD_STATE_TOKEN_HASH && pm2 env 2 | grep NETFOX_SERVER_WORLD_STATE_TOKEN_HASH"
ssh root@165.227.33.94 "pm2 restart pixelmania pixelmania-a pixelmania-b --update-env && pm2 restart pixelmania-netfox-start --update-env && pm2 save"
```

PM2 ids can change; prefer PM2 app names when restarting, and only use ids when
you have just checked `pm2 list`.

Active issues to resume from:

- The client can still fall back to WebSocket movement when the backend route is
  missing, expired, or resolves to `127.0.0.1:24566`. In production, a healthy
  client should target `165.227.33.94:24566`.
- The latest observed blocker was severe 1 FPS lag caused by log spam, including
  repeated `NETFOX_STATUS` lines and repeated `[PM_DROP_PICKUP_DIAG] no_player`
  entries. Fix log throttling first before deeper movement/collision work.
- Collision is still unresolved: players can walk/pass through many blocks.
  Earlier collision/tilemap changes caused major FPS drops and were reverted.
  Do not guess here; inspect TileMap/TileSet collision, NetfoxPlayer
  layer/mask, and server collision generation with fresh evidence.
- Re-entering a world can still get stuck on `Preparing player...` when route,
  ticket, or spawn readiness fails.
- Late join / remote player positioning and world isolation had visual issues
  during transition and should be re-verified once Netfox connection is stable.

Recommended next steps:

1. Flush/restart `pixelmania-netfox-start`, verify the route with the script
   above, then launch exactly one client and collect fresh logs.
2. Fix log spam only. Likely files to inspect are
   `Scripts/networking/netfox_real_manager.gd`, `Scripts/network_manager.gd`,
   and `Scripts/drop_manager.gd`. Do not change movement, collision, or routing
   behavior while doing this.
3. Fix route/fallback next: prove the backend route exists before ENet connect,
   ensure production clients never connect to `127.0.0.1:24566`, and honor
   `NETFOX_MOVEMENT_ALLOW_STATIC_FALLBACK=false`.
4. Fix collision only after Netfox connection and logging are stable, using a
   minimal reproduction and concrete collision-layer/mask/tile data.

Do not:

- Do not commit or paste the raw Netfox server token.
- Do not trust stale Godot Output or PM2 logs. Flush logs before verifying.
- Do not re-enable static fallback as a hidden fix.
- Do not make broad collision/tilemap rewrites without measuring FPS.
- Do not revert unrelated dirty worktree files.

### Latest Multiplayer Scaling Handoff

As of 2026-06-26, the multiplayer scale-readiness work in this Codex window is
implemented locally and verified with local/static checks. Treat it as ready for
staging or Redis-enabled multi-instance validation before production rollout:

- Phase 1: `MAX_PLAYERS_PER_WORLD` defaults to 50 and is enforced on
  `join_world` and cross-world `door_enter`.
- Phase 2: backend world fanout uses a per-world player index
  (`socketByPlayerId` / `worldPlayers`) instead of scanning all sockets.
- Phase 3: Redis-backed world admission reservations are wired with
  `WORLD_ADMISSION_TTL_MS`, refresh on live presence, and cleanup on leave,
  disconnect, and session replacement.
- Phase 4: `backend/scripts/multi_instance_world_cap_smoke.js` can prove two
  backend instances share one Redis world cap. It skips cleanly with
  `--allow-skip` when Redis is not available locally.
- Phase 5: Redis-backed world route ownership is wired through
  `SERVER_INSTANCE_ID`, `SERVER_INSTANCE_WS_URL`, `WORLD_ROUTE_TTL_MS`, and
  `WORLD_ROUTE_ENFORCEMENT_ENABLED`. The server can reject with
  `reason: "world_route_redirect"` and includes `redirect_ws_url` plus
  `owner_instance_id`.
- Phase 6: the Godot client handles `world_route_redirect`: it validates the
  redirect WebSocket URL, preserves the saved session during the route hop,
  reconnects to the owner, and retries the pending world join. Production builds
  only follow trusted URLs from `SERVER_URLS` or
  `pixelmania/network/world_route_ws_urls`; editor/debug builds can follow dev
  overrides for local tests.
- Test harness: `backend/scripts/multiplayer_scaling_smoke.js` and npm scripts
  `test:multiplayer-scaling`, `test:multiplayer-scaling:fast`, and
  `test:multiplayer-scaling:redis` now run the completed multiplayer checks
  from one command.

Latest local verification from this window:

- `npm run check:scale-readiness` passed.
- `npm run check:security` passed.
- `npm run test:multiplayer-scaling` passed locally; Redis-specific smokes
  skipped because Redis was not reachable at `127.0.0.1:6379`.
- `npm run test:multiplayer-scaling:fast` passed locally after the client route
  redirect change.
- `node --check backend/scripts/multiplayer_scaling_smoke.js` passed.
- PowerShell parse check for `backend/deploy_to_droplet.ps1` passed.

Continuation verification on 2026-06-26:

- `npm run test:multiplayer-scaling:fast` passed locally.
- `npm run smoke:world-cap:multi -- --redis-url redis://127.0.0.1:6379
  --redis-connect-timeout-ms 500 --cap 2 --ports 18570,18571 --world
  MULTI_INSTANCE_CAP_SMOKE` failed before starting the multi-instance assertion
  because Redis was not reachable at `127.0.0.1:6379`.
- A follow-up attempt using `redis://127.0.0.1:8080` also failed with
  `ECONNREFUSED`; from this Codex process, port `8080` was not listening as a
  Redis endpoint.
- This Windows environment did not have `redis-server`, Docker, a Redis service,
  or an installed WSL Linux environment available, so the Redis-required smoke
  still needs a Redis-enabled local machine or staging server.
- Redis-enabled validation later passed on the DigitalOcean droplet from
  `~/PixelManiaServer` with Redis at `redis://127.0.0.1:6379`.
  `npm run test:multiplayer-scaling:redis -- --redis-url
  redis://127.0.0.1:6379` completed with `syntax`, `static_gates`,
  `local_single_instance`, `redis_world_cap`, and `redis_route_conflict` all
  reporting `ok`.
- Route-staging helper scripts were added locally after the Redis pass:
  `npm run stage:world-route` starts two non-production PM2 route instances
  (`pixelmania-route-a` and `pixelmania-route-b`) on ports `18081` and `18082`
  with PostgreSQL disabled, Redis enabled, and world route enforcement enabled.
  `npm run smoke:world-route:public` validates public shard URLs such as
  `wss://api.pixelmaniagame.com/staging-ws-a` and
  `wss://api.pixelmaniagame.com/staging-ws-b`.
- The route-staging helper must run those temporary route apps with
  `ENVIRONMENT=development` and `PIXELMANIA_ENABLE_DEV_BACKEND_LOGIN=true`,
  because the public route smoke uses `dev_backend_login`. Keep these apps
  isolated from production durable data and remove them after validation.
- Public route staging validation passed on the droplet:
  `npm run smoke:world-route:public -- --owner-url
  wss://api.pixelmaniagame.com/staging-ws-a --other-url
  wss://api.pixelmaniagame.com/staging-ws-b --follow-redirect` returned
  `ok: true`, `redirect_reason: "world_route_redirect"`,
  `redirect_ws_url: "wss://api.pixelmaniagame.com/staging-ws-a"`,
  `owner_instance_id: "route-stage-a"`, and `followed_redirect: true`.
  This proves the public Caddy shard paths can route to two backend instances
  and the redirect payload points clients back to the owner route.
- Cleanup after public route staging: remove or comment the Caddy
  `/staging-ws-a*` and `/staging-ws-b*` handles, run
  `sudo caddy validate --config /etc/caddy/Caddyfile`, reload Caddy, and stop
  the temporary PM2 apps with `pm2 delete pixelmania-route-a
  pixelmania-route-b && pm2 save`.
- Client route trust is now configured locally in `project.godot` under
  `pixelmania/network/world_route_ws_urls` for the intended production shard
  URLs `wss://api.pixelmaniagame.com/ws-a` and
  `wss://api.pixelmaniagame.com/ws-b`. The scale-readiness wiring check now
  verifies these URLs are present, and the deploy helper copies `project.godot`
  to `~/pixel-mania/project.godot` for droplet-side static checks.
- A guarded production-route helper is now available locally:
  `npm run prod:world-route` starts `pixelmania-a` on `127.0.0.1:18091` and
  `pixelmania-b` on `127.0.0.1:18092` using production PostgreSQL/Redis,
  dev-login disabled, snapshots disabled on the route apps, and
  `WORLD_ROUTE_ENFORCEMENT_ENABLED=false` by default. Set
  `ROUTE_PRODUCTION_ENFORCEMENT_ENABLED=true` only when intentionally testing
  redirect enforcement on those route apps.
- `npm run smoke:world-route:public` now supports production token auth through
  `--token-file ./load_tokens.json`, writes rotated tokens to
  `./load_tokens.next.json` by default, and can validate
  `wss://api.pixelmaniagame.com/ws-a` -> `wss://api.pixelmaniagame.com/ws-b`
  redirects with `--owner-instance-id pixelmania-a --follow-redirect` after
  enforcement is enabled.
- Production route dry-run is in progress with enforcement still disabled:
  `pixelmania-a` and `pixelmania-b` are online behind Caddy `/ws-a*` and
  `/ws-b*`, local health checks on `18091`/`18092` are healthy, and `/ws-b`
  can authenticate/join with disposable load-test tokens. `/ws-a` initially
  returned `Saved login expired. Sign on again.` for multiple fresh token rows,
  and direct `ws://127.0.0.1:18091` showed the same failure. Route-a logs showed
  `[postgres] initialization failed ... tuple concurrently updated` followed by
  JSON fallback, so route-a was not reading the production sessions table.
  Restarting `pixelmania-a` restored Postgres readiness and direct/public
  `/ws-a` token auth passed. Public `/ws-b` token auth also passed. After
  route-app reload, both `pixelmania-a` and `pixelmania-b` reported
  `postgres_ready:true` and `postgres_authoritative:true`, and fresh public
  token load tests passed against both `wss://api.pixelmaniagame.com/ws-a` and
  `wss://api.pixelmaniagame.com/ws-b` with `auth=1 joined=1`.
  A controlled route-enforcement redirect smoke also passed with
  `ROUTE_PRODUCTION_ENFORCEMENT_ENABLED=true`: the owner joined
  `wss://api.pixelmaniagame.com/ws-a`, the other route returned
  `reason:"world_route_redirect"`, `redirect_ws_url:"wss://api.pixelmaniagame.com/ws-a"`,
  `owner_instance_id:"pixelmania-a"`, and `followed_redirect:true`. Enforcement
  was then set back to `false`; leave it off until an exported client build
  that trusts `/ws-a` and `/ws-b` has been tested.
- Exported client validation: after `project.godot` was updated with trusted
  route URLs for `/ws-a` and `/ws-b`, the user exported a client build,
  connected to the live game, and confirmed normal gameplay. This validates the
  exported client baseline against the current backend route setup. The user
  also tested the exported client with route enforcement enabled and confirmed
  normal gameplay, completing the production route-enforcement canary.
- Load-test follow-up: attempted 500/100 synthetic load from the production
  droplet itself did not prove 500 active players. The first run was limited by
  the shared login IP throttle (`LOGIN_ATTEMPT_LIMIT_IP=20` by default). A
  follow-up 50+50 local route test with separate token pools kept PM2, Redis,
  Postgres, and pending queues healthy, but each route plateaued at
  `auth=24/joined=24` because `account_token_login` is also protected by the
  shared Redis message limiter (`8` per `15s` per IP before authentication).
  Treat these as rate-limit/load-generator-shaping results, not capacity
  failures. For one-host synthetic tests, either ramp auth below that limit
  or add a guarded load-test-only config knob before trying 500 active clients.
- Later 250-client local route attempts used five 50-client workers against
  direct route ports `18091`/`18092`. The server processes stayed online and
  reported no load-script errors/rejections, but it was not a clean 250-player
  pass: final worker auth counts were partial (`40`, `28`, `2`, `2`, `0`) and
  a repeat attempt ended partial again (`47`, `12`, `0`, `2`, `11`). Several
  workers stayed connected without authenticating. This again points at the
  shared pre-auth `account_token_login` message limiter and/or one-droplet load
  generator shaping from a single source IP, not a gameplay-loop failure. Do
  not cite 250 as verified until auth reaches 50/50 on each worker during the
  hold window.
- The staged WebSocket load test now supports `--token-offset` and prints the
  token row/user range it is using; combine it with `--verbose` when diagnosing
  one failing production shard URL.
- `postgres_store.js` now retries retryable Postgres startup failures,
  including the observed `tuple concurrently updated` conflict, so one route app
  should not stay in JSON fallback after a transient concurrent bootstrap race.
- The local deploy helper now copies `Scripts/block_manager.gd`,
  `Scripts/world_tilemap_renderer.gd`, `scripts/start_route_staging_instances.sh`,
  and `scripts/public_world_route_smoke.js` so the droplet scale gates and route
  staging helpers are present after deployment.

Known local test limits:

- Redis is not installed/running locally, so the true Redis multi-instance cap
  and route-conflict/redirect smokes still need to be run on a Redis-enabled
  machine or staging with:

```powershell
cd G:\PixelMania\pixel-mania\backend
npm run test:multiplayer-scaling:redis -- --redis-url redis://127.0.0.1:6379
```

- No Godot executable was found on PATH in this Codex environment, so the
  Godot client route redirect code was verified by static scale-readiness checks
  and source inspection, not by launching the editor/runtime.

Recommended next phase in a fresh Codex window:

1. Run the Redis-required multiplayer scaling smoke on a machine/staging server
   with Redis available.
2. If it passes, deploy to staging with two backend instances, unique
   `SERVER_INSTANCE_ID` values, and route-specific `SERVER_INSTANCE_WS_URL`
   values.
3. Add the shard WebSocket URLs to `pixelmania/network/world_route_ws_urls` for
   exported clients before enabling `WORLD_ROUTE_ENFORCEMENT_ENABLED=true`.
4. Only after staging proves redirects and world caps, decide whether to deploy
   the multi-instance route enforcement path to production.

### Backend Security Foundation

As of the latest 2026-06-10 production work in this chat, the backend security
foundation through checklist item 10 is implemented, deployed, and user-tested.
Checklist items 11, 12, 13, and 14 are implemented locally and ready for
deployment/testing:

- PostgreSQL is the authoritative durable database for account, player, world,
  inventory, economy, audit, session, punishment, transaction, rollback, and
  journal data.
- Redis is the live helper layer for rate limits, presence, active sessions,
  cooldowns, locks, and short-lived multiplayer coordination.
- DigitalOcean Spaces is configured for off-site backups and large snapshot
  files. The Spaces CLI/key issue was fixed by installing AWS CLI v2 and
  configuring a matching DigitalOcean Spaces access key/secret pair; a manual
  `put-object` test succeeded with an `ETag` and lifecycle `Expiration`.
- PostgreSQL backup, restore-check, maintenance, and off-site copy scripts are
  present. Backup/restore-check has been run successfully on production.
- Item instance tracking is wired for valuable/rare/equipment/tool/lock items
  with exact `PM-ITEM-*` movement and dev-panel lookup/history tools.
- Session validation reads the PostgreSQL `sessions` table.
- Punishments, bans, and mutes are stored in PostgreSQL and enforced by login,
  chat, request-pipeline, and admin/dev tooling.
- Transaction ledger rows are written for valuable economy actions, failed
  valuable attempts, and rollback/reversal paths.
- Gem ledger rows are written for gem balance changes through the shared
  authoritative inventory/economy paths.
- World block/object journals are wired for rollback and investigation.
- Rollback tooling supports player, world, item, and transaction rollback, with
  exact-time world restore and explicit crash recovery through
  `npm run world:recover`.
- Snapshot + action-log tooling is wired. Production snapshot scheduling is
  throttled for the 1GB droplet.
- Server-side validation is wired for valuable actions. The client requests;
  the server validates permissions, world locks, reach, cooldowns, ownership,
  capacity, balances, roles, and contested state.
- Anti-dupe transaction locking is wired for trades, vending, drops, shared
  inventory commits, and safe/vending object mutations using live locks plus
  PostgreSQL transaction/row locks.
- Admin action logging is wired, deployed, and user-tested. Admin/dev actions
  now include actor, target, role, IP/session/device context, reason, affected
  item/world, before/after values or hashes, denied attempts, and success/fail
  metadata in PostgreSQL `admin_actions`.
- Account/session security hardening is wired in code: explicit scrypt password
  algorithm metadata, hashed session/refresh tokens, refresh rotation,
  one-active-session enforcement, IP/user-agent/device tracking, durable login
  attempt rows, Redis/local login throttling, optional admin TOTP 2FA, optional
  admin confirmation tokens, and admin command cooldowns.
- Bot/rate-limit protection is wired in code: Redis/local server-side buckets
  for block places, block breaks/hits, pickup attempts, chat messages, trade
  requests, world joins, login attempts, and vending purchases, with throttled
  `security_events` evidence for blocked bot-limit attempts.
- Integrity hashes are wired in code: player inventory hashes are stored on
  `players`, transaction ledger rows get deterministic `transaction_hash`
  values, world snapshots get stable `snapshot_hash` values, rollback updates
  hashes after legitimate reversals/corrections, and
  `npm run integrity:hash-audit` records PostgreSQL audit summaries in
  `integrity_audit_runs`.
- Monitoring dashboard is wired in code: an admin/PIN-gated developer panel
  Monitor tab requests server-authoritative dashboard data, logs access to
  `admin_actions`, shows live online/world/server-loop/memory/snapshot state,
  and reads top gem gainers, top item gainers, suspicious accounts, dupe
  warnings, and latest integrity audit status from PostgreSQL.

Future backend/economy/security work must keep using these patterns: durable
state in PostgreSQL, temporary coordination in Redis, large/off-site files in
Spaces, exact `PM-ITEM-*` rows for valuable items, transaction/gem ledger rows
for economy movement, world journal rows for world edits, and admin action rows
for privileged operations. Important mutable state should also keep integrity
hashes so manual edits, corruption, and bad migrations can be audited.

## Core Architecture

PixelMania production backend uses:

- PostgreSQL as the permanent source of truth for durable game data.
- Redis as a temporary live helper for locks, rate limits, presence,
  active-session markers, cooldowns, and multiplayer coordination.
- DigitalOcean Spaces as file/object storage for off-site backups and large
  world snapshot JSON files.
- Local JSON only for development, migration fallback, or emergency recovery.

When adding any durable backend feature, wire it to PostgreSQL as part of the
feature.

## Production Services

Known production droplet:

- SSH target used in this project: `root@165.227.33.94`
- Backend directory on droplet: `~/PixelManiaServer`
- Public API base: `https://api.pixelmaniagame.com`
- Public WebSocket: `wss://api.pixelmaniagame.com/ws`
- PM2 app name: `pixelmania`

10,000-player readiness notes live in `docs/scale_readiness_10k.md`. The
current small single-node droplet is not a 10,000-concurrent-player target by
itself; use the scale runbook, load tests, and horizontal/world-sharding plan
before treating that number as production capacity.

The health endpoint should show:

- `persistence.postgres_ready: true`
- `persistence.postgres_authoritative: true`
- `persistence.redis_ready: true`
- `persistence.redis_stats`
- `persistence.world_snapshot_storage.mode: "spaces"` when Spaces is enabled
- `persistence.world_snapshot_storage.mode: "local"` is expected while Spaces
  snapshot uploads are intentionally paused for stability

## PostgreSQL Coverage

PostgreSQL is wired as the authoritative durable store for:

- accounts
- players
- worlds
- world_members / world access data
- world_locks and lock access state
- inventory
- item_instances
- item_instance_events
- item_transactions
- transaction_ledger
- gem_ledger
- trades
- vending_transactions
- shop_purchases
- admin_actions
- world_block_changes
- world_object_changes
- world_snapshots metadata
- security_events
- account_login_attempts
- sessions
- punishments / bans / mutes
- integrity_audit_runs

Session validation has been hardened to read from the sessions table instead of
only relying on compatibility account-state logic.

## Redis Coverage

Redis is enabled as the live helper layer. It is used for:

- message/action rate limits
- live presence markers
- active-session markers
- drop pickup locks
- vending buy locks
- world admission reservations for shared 50-player caps across instances
- world route ownership keys for temporary per-world backend ownership
- short-lived live coordination

Redis is not permanent truth. Any Redis state must be safe to lose or rebuild
from PostgreSQL/player reconnects.

## DigitalOcean Spaces Coverage

Spaces bucket used in production work:

- Bucket: `pixelmania-backups`
- Region/endpoint: `tor1`, `https://tor1.digitaloceanspaces.com`

Spaces is wired for:

- off-site PostgreSQL backup copies under `postgres/`
- large world snapshot JSON files under `world_snapshots/`
- lifecycle cleanup policy:
  - expire `postgres/` objects after 90 days
  - expire `world_snapshots/` objects after 180 days
  - abort incomplete multipart uploads after 7 days

Do not commit Spaces keys. If keys appear in chat/logs, rotate them in
DigitalOcean and update only the droplet config files.

Production incident note from 2026-06-10:

- Repeated world snapshot uploads to Spaces caused log spam and likely PM2
  instability on the 1GB droplet.
- Logs showed repeated `[snapshots] Spaces upload failed` lines, and a manual
  `aws ... s3api put-object` test failed with
  `argument of type 'NoneType' is not a container or iterable`.
- The server stabilized after setting `WORLD_SNAPSHOT_STORAGE=local` and
  restarting PM2 with `--update-env`.
- The Spaces CLI/key issue was later fixed by installing AWS CLI v2 and
  configuring a matching DigitalOcean Spaces access key/secret pair. A manual
  `aws ... s3api put-object` test then succeeded and returned an `ETag` plus a
  lifecycle `Expiration`.
- Spaces-backed world snapshots can be used only when `/health` confirms the
  expected snapshot storage mode and PM2 logs show no new Spaces upload errors
  for at least one snapshot cycle. If upload failures return, switch snapshots
  back to local storage first. PostgreSQL remains authoritative, and PostgreSQL
  backup/off-site copy handling is separate from world snapshot upload mode.

Temporary stability command on the droplet:

```bash
cd ~/PixelManiaServer
grep -q '^WORLD_SNAPSHOT_STORAGE=' .env && sed -i 's/^WORLD_SNAPSHOT_STORAGE=.*/WORLD_SNAPSHOT_STORAGE=local/' .env || echo 'WORLD_SNAPSHOT_STORAGE=local' >> .env
pm2 startOrReload ecosystem.config.js --env production --update-env
```

Before enabling or re-enabling Spaces-backed world snapshots, this manual
upload test must succeed without AWS CLI errors:

```bash
cd ~/PixelManiaServer
echo "pixelmania spaces test $(date -u)" > /tmp/pixelmania-space-test.txt

AWS_REQUEST_CHECKSUM_CALCULATION=when_required \
AWS_RESPONSE_CHECKSUM_VALIDATION=when_required \
aws --endpoint-url https://tor1.digitaloceanspaces.com s3api put-object \
  --bucket pixelmania-backups \
  --key world_snapshots/test/pixelmania-space-test.txt \
  --body /tmp/pixelmania-space-test.txt
```

## Backup And Recovery

PostgreSQL backup/recovery scripts are in `backend/scripts/`:

- `postgres_backup.sh`
- `postgres_restore_check.sh`
- `postgres_maintenance.sh`

NPM shortcuts:

- `npm run db:backup`
- `npm run db:restore-check`
- `npm run db:maintenance`
- `npm run db:maintenance:preflight`
- `npm run db:maintenance:copy`
- `npm run db:maintenance:alert-test`

Production cron jobs were added for periodic backup and restore checks. Off-site
copy cron was also added once Spaces upload worked.

The restore check includes table counts, including `transaction_ledger`.

## Item Instance Tracking

Stackable/common items are tracked as inventory counts.

Valuable, rare, equipment, locks, tools, event, shop, quest, crafting, vending,
trade, or admin-created items must use `item_instances` rows with stable
`PM-ITEM-*` public IDs.

Completed rare-item movement work:

- admin give/remove uses explicit item instance source labels
- shop, crafting, and fishing rewards use explicit sources
- trades move exact tracked item instances
- vending list/buy/payment paths move exact tracked item instances
- world drop and pickup paths use tracked instance rows
- raw inventory mirrors do not mint missing tracked items
- dev panel can look up item instances and instance history
- anti-dupe audit can detect duplicate IDs, impossible state/location
  combinations, and inventory count mismatches

Old legacy items may still show `unknown` or `reconcile` as the source because
they existed before full tracking was wired.

## Transaction Ledger

`transaction_ledger` is now the canonical investigation trail for valuable
economy actions.

Completed transaction ledger work:

- schema/table and indexes exist in bootstrap SQL and startup migration
- Postgres helper writes canonical ledger rows
- generic inventory commits write ledger rows
- drop pickup writes ledger rows
- trade finalization writes ledger rows
- vending buy writes ledger rows
- rejected/failed valuable attempts write `status = failed` rows through the
  shared action rejection path
- rollback snapshot restores write `ROLLBACK_RESTORE` rows with
  `status = reversed`
- dev panel can look up transaction ledger rows by player, item instance, item
  type, transaction type, or status
- server passes IP/session/device context where available
- `npm run check:transaction-ledger` validates static wiring

Examples of ledgered actions:

- `SHOP_PURCHASE`
- `TRADE_COMPLETE`
- `VENDING_BUY`
- `ADMIN_GIVE_ITEM`
- `ADMIN_REMOVE_ITEM`
- `CRAFT_OUTPUT`
- `FURNACE_OUTPUT`
- `FISHING_REWARD`
- `WORLD_LOCK_PLACE`
- `ITEM_DROP`
- `ITEM_PICKUP`

Ledger rows support statuses `success`, `failed`, and `reversed`. Current live
gameplay paths write `success` rows for completed valuable actions, failed rows
for rejected valuable action attempts, and rollback restore rows for snapshot
restore reversals.

## Gem Ledger

`gem_ledger` is the canonical trail for gem balance movement. Gems must not be
changed silently.

Completed gem ledger work:

- generic authoritative inventory commits write `gem_ledger` rows when the item
  is `gem` or the category is `currency`
- shop purchases write negative gem rows with before/after balance through the
  shared commit path
- admin give/remove writes gem rows through the shared commit path
- fish/fishing/crafting style rewards that add gems write rows through the
  shared commit path
- drop pickup gem rewards write `drop_pickup` gem rows and link them to
  `ITEM_PICKUP` transaction ledger rows
- trade gem sends/receives write `trade_send` / `trade_receive` gem rows and
  link them to `TRADE_COMPLETE` transaction ledger rows
- legacy JSON gem ledger writes still mirror into PostgreSQL when the shared
  commit path did not already write the row
- `npm run check:gem-ledger` validates static wiring

Every future gem source such as quests, events, loot boxes, vending gem flows,
rollback adjustments, or reward systems must create a `gem_ledger` row with a
clear reason/source and before/after balances.

## World Change Journal

World change journaling is wired for rollback/investigation support.

Completed world journal work:

- `world_block_changes` records block edits with actor, world, layer, x/y,
  action, old block type, new block type, source/request metadata, and time
- `world_object_changes` records durable interactive object edits with actor,
  world, object type, object ID, x/y, action, old JSON data, new JSON data,
  source/request metadata, and time
- interaction updates for world locks, wooden entrances, doors, signs, and
  toggles commit through the Postgres world-change path instead of only using a
  delayed world save
- vending list/buy/collect/cancel and safe-style world state saves are captured
  by explicit object rows or old/new world-state diff inference
- reciprocal door links write their own object journal rows
- block place/break rows now include `block_type_before` and `block_type_after`
- `npm run check:world-journal` validates static wiring

Old `world_block_changes` rows from before this pass may have `NULL`
`block_type_before` values. New world object rows start from the deployment time
of this feature; older door/sign/vending edits cannot be reconstructed unless
separate logs/snapshots already captured them.

## Rollback System

Rollback tooling is wired as an auditable PostgreSQL correction layer. It does
not delete investigation records.

Completed rollback work:

- `rollback_jobs` stores every applied rollback plan/result
- player rollback reverses one player's inventory/gem movements after a chosen
  timestamp
- world rollback restores one world from a PostgreSQL, local, or Spaces-backed
  snapshot and writes a `world_object_changes` rollback row
- world rollback also supports exact timestamp recovery with `--at` / `--to` /
  `--target-time`: the tool chooses the newest snapshot at or before that
  timestamp, replays `world_block_changes` and `world_object_changes` up to the
  target time, then applies the replayed state
- `--safe-only` is now supported on world rollbacks to ignore unsafe journal
  events during replay
- explicit crash recovery now exists as `npm run world:recover`. It wraps the
  same snapshot + journal replay path, defaults to dry-run, supports one world
  or all worlds, and requires `--confirm-server-stopped` before applying so live
  players cannot race a recovery write
- item rollback can retire, freeze, unfreeze, flag, or transfer one exact
  `PM-ITEM-*` instance
- transaction reversal can reverse one `transaction_ledger` row or a whole
  transaction group by transaction ID
- original transaction ledger rows are marked `status = reversed`
- correction rows use `source = rollback`, `ROLLBACK_*` transaction types,
  `rollback_applied`, `admin_corrected`, `rollback_job_id`, and
  `rollback_reason` metadata
- rollback inventory/gem corrections write `item_transactions` and
  `gem_ledger` rows
- exact rare-item corrections write `item_instance_events`
- `npm run check:rollback` validates rollback static wiring

Production snapshot scheduling is throttled for the 1GB droplet:

- `WORLD_SNAPSHOT_MAX_WORLDS_PER_CYCLE=5` by default
- `WORLD_SNAPSHOT_STARTUP_RUN=false` by default
- each periodic snapshot waits for pending snapshot persistence/upload work
  before starting the next world

If PM2 shows memory restarts or snapshot-related crashes, temporarily set
`WORLD_SNAPSHOT_INTERVAL_MINUTES=0`, restart PM2, and inspect the snapshot
health/log fields before re-enabling.

If Spaces upload errors return, prefer `WORLD_SNAPSHOT_STORAGE=local` before
disabling the scheduler entirely. Local snapshots plus PostgreSQL journal rows
still support rollback/recovery while avoiding failed off-site upload loops.

Rollback command examples on the droplet:

```bash
cd ~/PixelManiaServer

npm run rollback:apply -- player --user uso --since 2026-06-07T00:00:00Z --reason "dupe correction"
npm run rollback:apply -- player --user uso --since 2026-06-07T00:00:00Z --reason "dupe correction" --apply

npm run rollback:apply -- world --world START --latest --reason "restore before grief"
npm run rollback:apply -- world --world START --latest --reason "restore before grief" --apply

TARGET_AT="$(date -u -d '5 minutes ago' +'%Y-%m-%dT%H:%M:%SZ')"
npm run rollback:apply -- world --world START --at "$TARGET_AT" --reason "restore exact time"
npm run rollback:apply -- world --world START --at "$TARGET_AT" --safe-only --reason "restore exact time (safe events only)"
npm run rollback:apply -- world --world START --at "$TARGET_AT" --reason "restore exact time" --apply

npm run world:recover -- --world START --at now
npm run world:recover -- --world START --at now --safe-only
npm run world:recover -- --world START --at now --reason "recover after crash" --confirm-server-stopped --apply
npm run world:recover -- --all-worlds --at now --continue-on-error

npm run rollback:apply -- item --item-instance PM-ITEM-ABC123 --action retire --reason "duplicate copy"
npm run rollback:apply -- item --item-instance PM-ITEM-ABC123 --action transfer --target uso --reason "restore owner" --apply

npm run rollback:apply -- transaction --ledger-id 123 --reason "bad admin action"
npm run rollback:apply -- transaction --transaction-id 00000000-0000-0000-0000-000000000000 --reason "bad trade" --apply
```

Dry-run is the default. Use `--apply` only after reviewing the plan. Applying a
rollback requires `--reason`.

## Server-Side Validation

Server-side validation is wired as the authority layer for valuable actions:

- block break/place validates server world state, reach, permissions, world
  locks, cooldown/pacing, item breakability/placeability, and inventory cost
- world-based inventory actions enforce world bans consistently
- trade finalization rechecks both players are online, in the same trade world,
  still close enough, and still have the offered inventory before PostgreSQL
  moves anything
- vending list/buy/collect/cancel validate ownership, stock, vendability,
  capacity, and use live vending locks
- safe deposit/withdraw validate ownership, storable item rules, capacity, and
  use live safe locks
- shop, station crafting/furnace, fishing, fish monger, drops, and seeds use
  server item definitions and inventory/capacity checks
- admin/developer actions require admin/developer role and developer PIN unlock

Deploy checks include `npm run check:server-validation`, and that check is part
of `npm run check:security`.

## Anti-Dupe Transaction Locking

Anti-dupe transaction locking is wired for the main valuable movement paths:

- shared inventory commits acquire a live player inventory lock before
  PostgreSQL inventory writes and release in `finally`
- trade finalization sets `_finalizing`, locks both player inventories in a
  sorted order, validates both offers, runs one PostgreSQL transaction, and
  unlocks in `finally`
- vending buys lock the vending machine plus buyer/owner inventories before the
  PostgreSQL vending transaction; the database locks buyer payment/item rows and
  exact tracked item instances
- drop pickup locks the world drop plus picker inventory before the PostgreSQL
  pickup transaction; the database locks inventory and exact world-drop
  `PM-ITEM-*` rows
- vending/safe object mutations already use live object locks and then pass
  through the shared inventory commit lock when inventory changes

PostgreSQL transaction paths use row-level `FOR UPDATE` locks and exact
`PM-ITEM-*` movement helpers for tracked items. If a step fails, the DB
transaction rolls back and live locks release in `finally`.

Deploy checks include `npm run check:anti-dupe`, and that check is part of
`npm run check:security`.

## Admin Action Logs

Admin/dev actions are logged through `logAdminAction()` into local
`admin_actions.log` and mirrored into PostgreSQL `admin_actions`.

Completed admin action logging work:

- deployed and live-tested on production after checklist item 10; user confirmed
  admin action logging works
- admin action rows include admin username/id, role, IP, session token hash,
  user agent, device info, action type, target type/id, target username/world,
  affected item/world, amount, reason, request id, timestamp, success/denied
  status, and message
- developer commands require server-side `isAdmin()` and developer PIN unlock
  before execution
- denied developer/admin attempts are logged and mirrored to PostgreSQL
- admin give/remove logs inventory before/after hashes and before/after item
  counts
- health, teleport, noclip, clear world, reset world, snapshot world, clear
  drops, and spawn commands include before/after values or affected-world
  summaries where relevant
- punishment issue/revoke logs target, type, scope/world, reason, active
  before/after state, and revoke counts
- item instance freeze/unfreeze/retire/transfer/flag logs exact instance ID,
  item type/category, previous state/location/owner, new state/location/owner,
  reason, and inventory effects
- admin lookup tools log both successful and denied lookup attempts
- `npm run check:admin-actions` validates static admin-action logging wiring

Any future admin/dev command must call `logAdminAction()` for success and
denied/failed paths, and must include enough metadata to investigate what
changed and why.

## Account / Session Security

Checklist item 11 is implemented in local code and should be deployed/tested
before marking it production-verified.

Completed account/session security work:

- passwords use Node `crypto.scryptSync` with explicit algorithm metadata stored
  as `password_algorithm`; legacy rows default to `legacy_scrypt` and upgrade on
  successful login
- raw session tokens and refresh tokens are never stored; PostgreSQL stores
  `session_token_hash` and `refresh_token_hash`
- auth responses remain backward-compatible with `session_token` and also
  include `refresh_token` / `refresh_token_expires_at` for newer clients
- saved-login/token login accepts `refresh_token` or legacy `session_token`,
  rotates to fresh tokens, and revokes the old token hash
- one-active-session mode is controlled by `ACCOUNT_ONE_ACTIVE_SESSION` and is
  enforced in memory/Redis and PostgreSQL session revocation
- sessions track IP, user agent, device info, issue time, expiry time,
  refresh expiry, token family, rotated-from session, revoked time, and revoked
  reason
- login attempts are rate-limited by IP/account with Redis when ready and local
  fallback otherwise
- login successes/failures are written to PostgreSQL `account_login_attempts`
  and mirrored to the existing `security_events` stream
- admin/developer unlock can require TOTP 2FA through `ADMIN_2FA_REQUIRED`,
  `ADMIN_2FA_SECRET`, or per-user `ADMIN_2FA_SECRETS`
- developer/admin commands now use combined PIN + optional 2FA security,
  optional confirmation tokens for dangerous commands, admin command cooldowns,
  and existing `admin_actions` audit rows
- `npm run check:account-security` validates static wiring and is part of
  `npm run check:security`

Important production note: `ADMIN_2FA_REQUIRED` and
`ADMIN_COMMAND_CONFIRMATION_REQUIRED` default to `false` so deployment will not
lock out the current admin UI. Enable them only after setting a real TOTP
secret and confirming the client/dev panel sends the required code/token fields.

## Bot / Rate-Limit Protection

Checklist item 12 is implemented in local code and should be deployed/tested
before marking it production-verified.

Completed bot/rate-limit work:

- broad message-level throttling still runs for all WebSocket messages
- action-specific Redis/local throttles now run before expensive validation or
  database work
- block places are limited separately from block breaks/hits
- drop pickup attempts are limited per second
- chat messages are limited per second
- trade requests are limited per minute
- world joins are limited per minute
- login attempts remain limited by IP/account through the account security path
- vending purchases are limited per second through the `vend_buy` transaction
  action
- Redis is used when ready; local per-socket buckets are used as fallback
- blocked bot/rate-limit attempts send a `rate_limited` response and write
  throttled `security_events` evidence
- limits are tunable through `.env` using `BOT_*` variables
- `npm run check:bot-rate-limits` validates static wiring and is part of
  `npm run check:security`

Default bot/rate-limit knobs:

```env
BOT_BLOCK_PLACE_LIMIT=12
BOT_BLOCK_PLACE_WINDOW_SECONDS=1
BOT_BLOCK_BREAK_LIMIT=16
BOT_BLOCK_BREAK_WINDOW_SECONDS=1
BOT_PICKUP_ATTEMPT_LIMIT=12
BOT_PICKUP_ATTEMPT_WINDOW_SECONDS=1
BOT_CHAT_MESSAGE_LIMIT=3
BOT_CHAT_MESSAGE_WINDOW_SECONDS=1
BOT_TRADE_REQUEST_LIMIT=20
BOT_TRADE_REQUEST_WINDOW_SECONDS=60
BOT_WORLD_JOIN_LIMIT=20
BOT_WORLD_JOIN_WINDOW_SECONDS=60
BOT_VENDING_PURCHASE_LIMIT=5
BOT_VENDING_PURCHASE_WINDOW_SECONDS=1
BOT_RATE_LIMIT_SECURITY_LOG_WINDOW_MS=5000
```

## Moderation / Punishments

Punishment storage and behavior are wired:

- `punishments` table
- Postgres helper code
- admin commands for ban/mute/unban/unmute style behavior
- login checks for active bans
- chat checks for active mutes
- request-pipeline enforcement for relevant actions
- dev/admin visibility hooks

## Admin / Dev Tools

Developer/admin tooling includes:

- inventory lookup
- item instance lookup
- item instance history lookup
- transaction ledger lookup
- item instance audit
- item instance moderation helpers such as freeze/retire/transfer-style
  management where available
- punishment management
- monitoring dashboard for online players, world counts, loop health, dupe
  warnings, economy gainers, and suspicious accounts
- snapshot commands

Admin and security actions should continue to write to PostgreSQL audit tables.

## Deployment

Preferred backend deploy command from Windows PowerShell:

```powershell
cd G:\PixelMania\pixel-mania\backend
powershell -ExecutionPolicy Bypass -File .\deploy_to_droplet.ps1 -RemoteIp 165.227.33.94
```

Manual deploy fallback:

```powershell
$SERVER = "root@165.227.33.94"
$ROOT = "G:\PixelMania\pixel-mania"
$LOCAL = "G:\PixelMania\pixel-mania\backend"

scp "$LOCAL\server.js" "$LOCAL\postgres_store.js" "$LOCAL\redis_store.js" "$LOCAL\server_item_database.js" "$LOCAL\ecosystem.config.js" "$LOCAL\package.json" "${SERVER}:~/PixelManiaServer/"
scp "$LOCAL\docs\postgres_security_foundation.sql" "$ROOT\docs\backend_persistence_rules.md" "$ROOT\docs\codex_handoff_status.md" "$ROOT\docs\production_backend_wiring.md" "${SERVER}:~/PixelManiaServer/docs/"
scp "$LOCAL\scripts\check_item_instance_wiring.js" "$LOCAL\scripts\check_transaction_ledger_wiring.js" "$LOCAL\scripts\check_gem_ledger_wiring.js" "$LOCAL\scripts\check_world_journal_wiring.js" "$LOCAL\scripts\check_rollback_wiring.js" "$LOCAL\scripts\check_server_validation_wiring.js" "$LOCAL\scripts\check_anti_dupe_locking_wiring.js" "$LOCAL\scripts\check_admin_action_wiring.js" "$LOCAL\scripts\check_account_session_security_wiring.js" "$LOCAL\scripts\check_bot_rate_limit_wiring.js" "$LOCAL\scripts\check_integrity_hash_wiring.js" "$LOCAL\scripts\check_monitoring_dashboard_wiring.js" "$LOCAL\scripts\rollback_plan.js" "$LOCAL\scripts\rollback_apply.js" "$LOCAL\scripts\world_recover_at_crash.js" "$LOCAL\scripts\world_snapshot_tool.js" "$LOCAL\scripts\postgres_backup.sh" "$LOCAL\scripts\postgres_restore_check.sh" "$LOCAL\scripts\postgres_maintenance.sh" "${SERVER}:~/PixelManiaServer/scripts/"
ssh $SERVER "cd ~/PixelManiaServer && chmod +x scripts/*.sh && npm install && node --check server.js && node --check postgres_store.js && npm run check:security && pm2 startOrReload ecosystem.config.js --env production --update-env"
```

Do not deploy placeholder hostnames such as `YOUR_DROPLET_IP`.

## Verification Commands

Backend local checks:

```powershell
cd G:\PixelMania\pixel-mania\backend
node --check server.js
node --check postgres_store.js
node --check redis_store.js
node --check server_item_database.js
npm run check:security
npm run check:gem-ledger
npm run check:world-journal
npm run check:rollback
npm run check:server-validation
npm run check:anti-dupe
npm run check:admin-actions
npm run check:account-security
npm run check:bot-rate-limits
npm run check:integrity-hashes
npm run check:monitoring-dashboard
npm run check:scale-readiness
npm run test:multiplayer-scaling
npm run test:multiplayer-scaling:fast
```

Redis-enabled multiplayer checks:

```powershell
cd G:\PixelMania\pixel-mania\backend
npm run test:multiplayer-scaling:redis -- --redis-url redis://127.0.0.1:6379
npm run smoke:world-cap:multi -- --redis-url redis://127.0.0.1:6379 --cap 2 --ports 18570,18571
```

Production health:

```bash
curl -s https://api.pixelmaniagame.com/health | python3 -m json.tool
```

PM2 logs:

```bash
cd ~/PixelManiaServer
pm2 logs pixelmania --lines 120
```

Transaction ledger summary:

```bash
sudo -u postgres psql -d pixelmania -c "
SET search_path TO pixelmania, public;
SELECT transaction_type, status, count(*)
FROM transaction_ledger
GROUP BY transaction_type, status
ORDER BY transaction_type, status;"
```

Recent rollback jobs:

```bash
sudo -u postgres psql -d pixelmania -c "
SET search_path TO pixelmania, public;
SELECT rollback_type, status, target_username, target_world, target_item_instance_id, created_at, applied_at
FROM rollback_jobs
ORDER BY created_at DESC
LIMIT 20;"
```

Recent world object changes:

```bash
sudo -u postgres psql -d pixelmania -c "
SET search_path TO pixelmania, public;
SELECT object_type, object_id, action, block_x, block_y, created_at
FROM world_object_changes
ORDER BY created_at DESC
LIMIT 20;"
```

Recent rare-item ledger rows:

```bash
sudo -u postgres psql -d pixelmania -c "
SET search_path TO pixelmania, public;
SELECT public_item_instance_id, transaction_type, source, action, quantity, server_time
FROM transaction_ledger
WHERE public_item_instance_id IS NOT NULL
ORDER BY server_time DESC
LIMIT 20;"
```

Recent admin actions:

```bash
sudo -u postgres psql -d pixelmania -c "
SET search_path TO pixelmania, public;
SELECT action_type, target_type, target_id, target_username, affected_item_id,
       affected_world, ok, created_at
FROM admin_actions
ORDER BY created_at DESC
LIMIT 20;"
```

Recent login attempts:

```bash
sudo -u postgres psql -d pixelmania -c "
SET search_path TO pixelmania, public;
SELECT username, action, success, reason, ip_address, created_at
FROM account_login_attempts
ORDER BY created_at DESC
LIMIT 30;"
```

Spaces snapshot listing:

```bash
aws --endpoint-url https://tor1.digitaloceanspaces.com s3api list-objects-v2 \
  --bucket pixelmania-backups \
  --prefix world_snapshots/ \
  --output json
```

## Known Caveats

- The worktree may contain unrelated Godot/frontend changes. Do not revert user
  changes unless explicitly requested.
- Spaces access keys were exposed in screenshots/chat during setup. Rotate or
  delete exposed keys in DigitalOcean, then update only droplet config files.
- Old legacy item rows can have source labels such as `unknown` or `reconcile`.
- Any future rare item source such as quests, events, loot boxes, rewards,
  crafting, or admin tools must create/move exact `PM-ITEM-*` instances and
  write transaction ledger rows.
- Admin TOTP 2FA and admin command confirmation are implemented but env-disabled
  by default. Enable carefully after configuring secrets and confirming the
  client/dev panel sends the expected fields.
- Bot/rate-limit values are intentionally configurable through env variables.
  Raise them gradually only after checking normal gameplay, `/health`, and PM2
  logs for new `rate_limit_exceeded` noise.
- Multiplayer route enforcement needs Redis plus a tested route strategy. Do
  not enable `WORLD_ROUTE_ENFORCEMENT_ENABLED=true` in production until the
  Redis-required multiplayer smoke passes and exported clients trust the shard
  WebSocket URLs through `pixelmania/network/world_route_ws_urls`.
- This Codex environment did not have Redis running locally and did not have a
  Godot executable on PATH. Redis-specific smokes and Godot runtime validation
  still need a Redis/Godot-capable machine or staging server.
- Rollbacks should be dry-run first, then applied with a clear reason. They
  leave correction records instead of deleting history.
