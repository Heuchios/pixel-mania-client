# Multiplayer block-break synchronization fix

## Findings

1. **Confirmed updates were queued behind world-event tiles.** `NetworkManager.queue_world_block_update_behind_pending_event_updates()` appended ordinary hits, breaks and placements to the tail of the snow/world-event queue. That queue has a 2.5 ms/frame work budget. The server could already have committed a removal while the client still displayed and collided with that tile. A subsequent hit then received `already_broken`. This is a concrete reproducible source of the reported mismatch; production latency was not measured during this task.
2. **Pending breaks were booleans without response identity or recovery.** The server can turn a requested `break` into a `hit` when its damage total is lower than the client's. A returned hit, or most rejection reasons, did not release the pending key. Continued punching refreshed the damage-expiry timer before noticing the pending key, so holding could keep it stuck indefinitely. Stopping allowed the 3-second timer to clear it, explaining the stop/start symptom. Conversely, damage expiry could unlock an unacknowledged request and allow another destruction request.
3. **Already-broken errors did not repair the tile.** The rejection only sent an error. It now also sends the authoritative cell through the existing reconciliation channel, without executing drops or inventory changes.
4. **Reconciliation could expose uncommitted state.** The server mutates its in-memory world before awaiting PostgreSQL. The reconcile handler previously always returned `authoritative_pending: false`. It now checks the same tile-action lock, and the client does not apply pending snapshots.

## Flow inspected

| Stage | Implementation / behavior |
|---|---|
| Mouse/touch and hold | `input_manager.gd`: immediate press, 0.30 s repeat; `mobile_controls.gd` punch hold |
| Targeting/reach | `block_manager.gd`: pointer/facing target, multi-tile anchor, foreground/background selection, local permission checks |
| Damage/cadence | `hit_block_grid`, `hit_background_block_grid`, 300 ms input cadence, local cracks, 3 s damage recovery |
| Request | `send_network_block_update` -> `NetworkManager.send_world_block_update`, authenticated WebSocket, action request ID and position flush |
| Server | `handleWorldBlockUpdate`: authentication, world/ownership/reach checks, per-tile lock, server tool/damage/cooldown checks |
| Authoritative mutation | `validateBlockUpdateAgainstServerState`, `applyBlockUpdateToWorldState`; only server computes removal and rewards |
| Persistence | `commitWorldStateWithBlockChanges` or deferred inventory/world transaction; PostgreSQL commit precedes success broadcast |
| Response | Requester sent directly; observers use the existing bounded broadcast batch (default 16 ms) |
| Client dispatch | Normal live updates now bypass event backlog; earlier queued event updates for the same world/layer/cell become obsolete |
| Render/collision | `apply_network_block_update` -> `remove_block_without_drop` / background equivalent; erases cached TileMap cells and foreground collision, disables node collision before deferred freeing |
| Reconnect | Authoritative snapshots and existing per-cell revision tracking remain in place; no client reward/persistence prediction introduced |

## Changes

- `Scripts/network_manager.gd`: per-cell event generations discard obsolete queued tiles; confirmed live edits and reconciliation apply without waiting for unrelated event tiles. Later newly received events remain valid.
- `Scripts/block_manager.gd`: pending breaks carry request ID, world, layer, coordinate and reconciliation time. Guards run before local hit/timer increments and centrally before network send. Matching hit/rejection responses release the key; stale responses cannot cancel a newer pending break. Damage decay no longer unlocks unacknowledged destruction. After 1.5 seconds without a conclusive reply, request the authoritative cell, not another break.
- `Scripts/world_state_sync_manager.gd`: resolve matching pending requests on hit and reconcile responses; ignore in-progress persistence snapshots.
- `src/server.ts` and generated `server.js`: already-broken rejection also returns authoritative reconciliation; read-only reconciliation advertises a held tile lock.

## Durability and performance

Persistence remains on the confirmation path intentionally. A normal successful break serializes the world and awaits `saveWorldStateWithWorldChanges`; that path can read the previous snapshot, upsert the world, mirror drops/locks and write journal entries under per-world transaction serialization. This is a potential remaining latency bottleneck, not a measured production timing claim. Sending committed success before these writes finish would permit visible success followed by rollback/data loss. This patch does not weaken that guarantee or asynchronously award drops.

No break speed, server damage, cooldown, permission, reward or duplicate-request security rules were relaxed. The queue fix eliminates client-side head-of-line delay while keeping accepted removals authoritative.

## Diagnostics

Client: set `PIXELMANIA_BREAK_TRACE=1` when launching a diagnostic build. `[BLOCK_BREAK_TRACE]` logs monotonic microseconds for hit start, local threshold, request send, matching response and visual/collision removal. Request IDs and cell coordinates connect the stages.

Server: existing `BLOCK_ACTION_PROFILE_LOGS=1` logs `BLOCK_BREAK_PROFILE` stages: request_received, validation_complete, world_mutation_complete, persistence_queued, database_completed and broadcast_sent. Compare durations within each process; client and server clocks are not synchronized. Both switches are off by default.

## Validation

Passed:
- `tests/break_sync_test.gd`: 4,096 queued event tiles, immediate live break dispatch, stale queued cell cannot resurrect it, later events still apply, hold does not advance pending damage, timer expiry does not unlock the request, stale IDs are ignored, matching pending/complete replies handled.
- `tests/block_break_renderer_test.gd`: erase/reconcile across adjacent chunk-boundary coordinates, renderer-cache removal, collision layer/mask and shape disabling, existing visual-reconciliation behavior.
- `tests/block_placement_reconciliation_test.gd`: existing placement behavior; refreshed its stale test double to expose the current `last_confirmed_place_visual_applied` property.
- `scripts/check_block_break_reconciliation.js`: actual compiled validation/reconcile functions with two simulated players targeting an already-removed tile; exact request/coordinates repaired, no reward code executed, persistence lock gates reconciliation.
- `scripts/check_block_break_commit_race.js`: actual action route with controlled delayed persistence; second player rejected while the same tile is locked; one removal, one drop-generation pass, one confirmed broadcast; no success before commit; later duplicate produces no additional rewards.
- Backend server-entry TypeScript build/check and phase-8 action-route build/check.
- Client scripts compile in Godot; changed files pass whitespace checks.

Not performed: real-device input testing, a live two-account play session, a production latency capture, or a live reconnect durability test. The simulated tests do not replace those checks. Changes are saved locally and have not been deployed or exported by this task.
