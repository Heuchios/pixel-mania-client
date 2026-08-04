# PixelMania 10k Player Readiness

This is the production scale target for running PixelMania toward 10,000
concurrent players. It is not a claim that the current single droplet can hold
10,000 real players by itself.

## Current Code-Level Readiness

The current runtime has the required foundations for a staged scale test:

- Client world rendering uses TileMapLayer for ordinary foreground/background
  tiles and replacement TileMapLayer collision for simple solid blocks.
- Player position traffic is interest-managed and batched.
- Player action effects can be interest-managed around nearby actors.
- Drop/world update traffic is batched, and drops are interest-managed.
- Pickup responses use inventory deltas instead of full player-state payloads.
- WebSocket receive payloads are capped at 64 KB and send-side backpressure
  skips slow-client writes after `SERVER_WEBSOCKET_MAX_BUFFERED_AMOUNT`.
- Worlds have a configurable `MAX_PLAYERS_PER_WORLD` cap, with Redis-backed
  temporary occupancy reservations for multi-instance tests.
- Backend instances can claim Redis-backed world route ownership. Health reports
  the local route owner snapshot so sharding can be tested before enforcement.
- The client understands `world_route_redirect` responses and can reconnect to
  an allowlisted WebSocket route before retrying the world join.
- Durable economy, inventory, world, session, rollback, and audit data stay in
  PostgreSQL. Redis remains temporary live coordination only.
- `npm run check:scale-readiness` verifies the scale-critical wiring before
  deploy.

## Known 10k Blockers

The known production droplet is a small single-node deployment. That is fine for
the current test population, but it is not a 10,000-player target.

Before advertising or planning around 10,000 concurrent players, production
needs:

- Load testing at 100, 500, 1,000, 2,500, 5,000, and 10,000 simulated clients.
- More CPU/RAM than the current 1 GB droplet.
- Horizontal capacity through world sharding or multiple app instances behind a
  WebSocket-aware load balancer.
- Enabling and proving `WORLD_ROUTE_ENFORCEMENT_ENABLED=true` with Redis ready
  and a load balancer/client route strategy so a player and their world stay on
  the same authoritative process.
- Redis enabled and monitored for live locks, presence, rate limits, and session
  coordination.
- PostgreSQL sized with enough connections, storage IOPS, backups, and restore
  drills for the tested player count.
- Server process/file-descriptor limits raised for thousands of sockets.
- Live monitoring and alerts for memory, event-loop lag, send backpressure,
  Redis health, Postgres pool pressure, and PM2 restarts.

Do not treat PM2 `instances: 1`, `exec_mode: "fork"`, and
`max_memory_restart: "512M"` as a 10k production deployment. Those settings are
safe for the current small droplet and should be changed only as part of a
tested sharding/load-balancing rollout.

## Required Health Targets During Load Tests

Use `/health`, PM2 logs, and host metrics during each load step. A rollout step
is not passed unless:

- `persistence.postgres_ready` is true.
- `persistence.postgres_authoritative` is true.
- `persistence.redis_ready` is true for any multi-node or larger live test.
- `persistence.world_route.enforcement_enabled` matches the test plan, and
  `persistence.world_route.local_owned_world_count` lines up with the worlds
  intentionally hosted by that instance.
- Server tick p95 lag stays below the gameplay budget chosen for launch.
- WebSocket backpressure skips are rare and do not climb continuously.
- `pending_position_updates` and `pending_world_updates` return to near zero
  between spikes.
- PostgreSQL pool waits and transaction retries remain low.
- Redis lock near-expiry/stale counts do not trend upward.
- Memory does not grow without returning after players disconnect.
- No duplicate-item, ledger, rollback, integrity, or validation checks fail.

## Pre-Deploy Gate

From `backend`:

```bash
npm run check:security
```

This includes:

- item database sync
- item instance wiring
- transaction/gem/world journals
- rollback wiring
- server validation
- anti-dupe locking
- admin action logging
- account/session security
- bot/rate-limit wiring
- integrity hashes
- monitoring dashboard wiring
- scale readiness wiring

For a focused scale gate:

```bash
npm run check:scale-readiness
```

To test all multiplayer scaling phases completed so far from one command:

```bash
npm run test:multiplayer-scaling
```

For a faster local pass that skips the full security gate:

```bash
npm run test:multiplayer-scaling:fast
```

This command always runs syntax checks, the scale-readiness gate, and a local
single-instance smoke that verifies the 50-player-cap path, per-world player
index, route ownership health, and same-world chat isolation. If Redis is
reachable, it also runs the multi-instance world-cap smoke and the world-route
conflict/redirect smoke. To require Redis and fail if it is not reachable:

```bash
npm run test:multiplayer-scaling:redis -- --redis-url redis://127.0.0.1:6379
```

## Staged WebSocket Load Test

Use a staging server first. Do not enable dev backend login on the live
production server.

Local or staging with dev login enabled:

```bash
cd backend
npm run load:staged -- --url ws://127.0.0.1:8080 --dev-login --clients 100 --step 25 --step-ms 30s --hold-ms 2m --world LOAD_TEST
```

Before running multiple backend instances, prove Redis is enforcing one shared
world cap across processes:

```bash
cd backend
npm run smoke:world-cap:multi -- --redis-url redis://127.0.0.1:6379 --cap 2 --ports 18570,18571
```

On a local machine without Redis, use the optional preflight form only to verify
the script is runnable:

```bash
npm run smoke:world-cap:multi:optional
```

Before enabling route enforcement in production, test with two backend
instances that set unique `SERVER_INSTANCE_ID` values and route-specific
`SERVER_INSTANCE_WS_URL` values. Keep enforcement disabled while validating that
`/health` shows `persistence.world_route.sample_owned_worlds` on the expected
instance, then enable:

```env
WORLD_ROUTE_ENFORCEMENT_ENABLED=true
WORLD_ROUTE_TTL_MS=45000
```

A rejected cross-instance join should return `reason: "world_route_redirect"`
with `redirect_ws_url` and `owner_instance_id`.

Exported clients only follow route redirects to trusted WebSocket URLs. Add the
public shard URLs to the `pixelmania/network/world_route_ws_urls` ProjectSetting
or compile them into `SERVER_URLS` before enabling route enforcement. Do not set
every instance's `SERVER_INSTANCE_WS_URL` to the same generic load-balancer URL
unless that load balancer can route the reconnect to the owning instance.
The current intended production shard URLs are
`wss://api.pixelmaniagame.com/ws-a` and
`wss://api.pixelmaniagame.com/ws-b`.

Production route rollout should happen in two steps. First start route-specific
instances with enforcement disabled:

```bash
cd ~/PixelManiaServer
npm run prod:world-route
```

This starts `pixelmania-a` on `127.0.0.1:18091` and `pixelmania-b` on
`127.0.0.1:18092`, both using production PostgreSQL and Redis, with
`WORLD_ROUTE_ENFORCEMENT_ENABLED=false` by default. Add matching Caddy handles
before the default proxy:

```caddy
handle /ws-a* {
  reverse_proxy 127.0.0.1:18091
}

handle /ws-b* {
  reverse_proxy 127.0.0.1:18092
}
```

After `sudo caddy validate --config /etc/caddy/Caddyfile` and
`sudo systemctl reload caddy`, verify `/health` on each local port and test the
public routes with disposable token accounts. Only then restart the route apps
with `ROUTE_PRODUCTION_ENFORCEMENT_ENABLED=true npm run prod:world-route` and
run:

```bash
npm run smoke:world-route:public -- --owner-url wss://api.pixelmaniagame.com/ws-a --other-url wss://api.pixelmaniagame.com/ws-b --owner-instance-id pixelmania-a --token-file ./load_tokens.json --follow-redirect
```

Use the emitted `.next.json` token file for repeated token-auth tests because
`account_token_login` rotates refresh/session tokens.

Production-style test with disposable token accounts:

Generate the token file on the server/droplet where production PostgreSQL env is
available:

```bash
cd ~/PixelManiaServer
npm run load:tokens -- --count 1000 --out ./load_tokens.json --confirm-production-load-accounts
```

Copy `load_tokens.json` to the machine running the load test. The file contains
plain session/refresh tokens for disposable `LoadTest_*` accounts; do not commit
it or share it.

```bash
cd backend
npm run load:staged -- --url wss://api.pixelmaniagame.com/ws --token-file ./load_tokens.json --clients 100 --step 25 --step-ms 30s --hold-ms 2m --world LOAD_TEST
```

`load_tokens.json` may be either an array or `{ "accounts": [...] }`:

```json
{
  "accounts": [
    {
      "username": "load001",
      "session_token": "SESSION_TOKEN",
      "refresh_token": "REFRESH_TOKEN"
    }
  ]
}
```

The script writes rotated tokens to `load_tokens.next.json` by default. Use that
new file for the next run if token login rotated refresh/session tokens.

Recommended progression:

```text
100 clients, 25 every 30s, hold 2m
500 clients, 50 every 30s, hold 5m
1,000 clients, 100 every 30s, hold 10m
2,500 clients, 250 every 45s, hold 15m
5,000 clients, 500 every 60s, hold 20m
10,000 clients, 500-1,000 every 60s, hold 30m
```

Watch `/health` while the script runs. Stop the ramp if rejections, position
corrections, pending queues, event-loop lag, memory, Redis lock pressure, or
PostgreSQL pool pressure trend upward instead of settling.

## Rollout Rule

Scale one step at a time. If movement, pickup, or world updates become laggy,
do not raise the target player count. Capture `/health`, PM2 logs, Redis health,
Postgres metrics, and a client-side repro first, then fix that bottleneck before
continuing.
