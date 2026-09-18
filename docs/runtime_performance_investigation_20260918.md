# PixelMania runtime and networking investigation

Date: 18 September 2026. Status: implemented and tested locally; not deployed or exported.

The investigation reproduced frame-dependent interaction timing and a client dispatch path that could leave a committed break visibly blocked behind cosmetic world-event work. It also identified pending-break recovery failures and redundant movement payloads. The fixes preserve server validation, inventory transactions, authoritative drops and commit-before-confirmation.

This is evidence from the checked-out code, Godot headless fixtures and a real isolated Node/WebSocket server. It is not a production latency capture or a physical Android/iOS performance benchmark. Related block-break work already present in the shared workspace was completed/validated alongside this investigation; unrelated crafting/UI work was preserved.

## Architecture inspected

| System | Current behavior |
|---|---|
| Client | Godot 4.7.1, GDScript; Mobile renderer with HDR 2D enabled. |
| Active movement | The current project defaults to `WEBSOCKET` / `websocket_v1`. Netfox and custom movement paths exist, but are not the default path tested here. The older handoff document describes a previous Netfox rollout and does not override the current code/configuration. |
| Local movement | Input feeds the existing player physics step immediately; movement does not wait for a server acknowledgement. Physics defaults to 60 Hz. Position sampling follows the physics step. |
| Movement transmission | Base client interval 16 ms; idle heartbeat 100 ms, with adaptive server guidance/backpressure. The Node server validates movement and replicates accepted state. Remote snapshot interpolation defaults to 70 ms, adapts within 45–140 ms, and bounds extrapolation at 120 ms. |
| Server scheduling | Event-driven Node handlers, not a fixed-rate authoritative physics simulation. Movement and world broadcasts default to 16 ms batching with adaptive policies. The 1-second “tick” monitor measures loop scheduling health; its approximately 1 TPS value is not the gameplay tick rate. |
| Transport | Active gameplay uses JSON over WebSocket/TCP: reliable, ordered delivery for movement, blocks, inventory, chat, entities and snapshots. Socket processing also uses an ordered Promise queue. |
| Client dispatch | Up to 96 network packets or 10 ms of dispatch work per render frame. Cosmetic/event tiles have a separate 1,024-tile / 2.5 ms per-frame budget. |
| World rendering | TileMapLayer-based per-cell updates, with 16×16 streaming chunks by default. Bulk operations coalesce dirty chunks. Ordinary edits already update individual cells. |
| Placement | Existing safe prediction for eligible ordinary blocks, request IDs, pending inventory reservation, authoritative confirmation/reconciliation and rejection rollback. Special blocks use their existing authoritative handling. |
| Breaking | Local crack/progress feedback; server determines damage, removal, permission and rewards. Confirmed removal clears visuals and collision through the existing renderer. No speculative client drop/inventory creation. |
| Inventory | Server-owned transactions and inventory deltas; existing client incremental UI refresh. Full state is used for login/recovery and explicit state requests. |
| Persistence | PostgreSQL is durable truth, Redis is temporary coordination, Spaces holds backups/snapshots. Local JSON was used only by the disposable development test server. World/inventory transactions and journal/ledger paths remain intact. |

## 1. Root causes discovered

**Confirmed edits could wait behind cosmetic tile updates.** The old client queue appended ordinary block updates behind pending snow/world-event tiles. A committed server removal could therefore leave both the old visual and collision alive on the client. Sending another punch could legitimately receive `already_broken`. Live edits now apply immediately when dispatched, and older queued event work for that same world/layer/cell is invalidated. Later event updates remain valid.

**Pending break state could remain stuck while holding.** Pending keys lacked sufficient response identity/recovery. A client-requested `break` may return as a server-authoritative `hit` when server damage is lower. That response, or a rejection, could leave the pending guard set. Continued holding refreshed local damage state, while release/restart could let it expire. Pending requests now use exact IDs and recover through the existing cell reconciliation channel. Damage decay cannot release an unacknowledged destruction request and cause another one.

**Rejection alone did not repair an already-broken cell.** The server now also sends authoritative cell reconciliation, without entering the destruction/reward path. Reconciliation reports a held tile-action lock as `authoritative_pending`, preventing an in-memory mutation that is still awaiting persistence from appearing committed to the client.

**Hold timers discarded fractional frame time.** Resetting timers to zero after every action accumulated frame rounding error. This affected both mobile and pointer holds, and repeated placement. Timers now preserve fractional remainder, with one action per frame and no replay burst after a long stall. The separate block-input cadence also preserves a bounded amount of lateness.

**Movement contained duplicate appearance fields.** Batch records carried `equipment_slots` plus redundant legacy equipment aliases. Removing those aliases from batch records reduced captured JSON payload size by 22–23%. Complete slot snapshots, including unequips, remain in every batch record.

These are reproduced defects and measured redundancy. They do not establish that every production lag report has the same cause.

## 2. Why mobile was affected more severely

At lower frame rates, rounding a repeat to the next render frame and discarding the remainder produces larger timing errors. The same per-frame event budget also takes more wall-clock time to drain at 30 FPS than at 60 FPS. Network parsing, scene updates and rendering share the client frame budget, so large movement batches can further amplify delay on a slower CPU.

Touch cancellation and focus loss now terminate the appropriate hold. Touch ownership is preserved: canceling a punch finger does not release a separate movement finger, and a canceled event cannot restart the hold through GUI dispatch. Existing inventory/modal input behavior was regression-tested.

The Mobile renderer, HDR, effects, texture atlases and collision paths were inspected. A 3,000-call layout microbenchmark averaged about 0.020 ms per layout on this PC; it did not justify a speculative HUD rewrite. Physical-device GPU time, overdraw, thermal throttling, memory pressure and battery behavior were unavailable. No visual-quality reduction or claimed phone FPS improvement is based on these headless measurements.

## 3. Movement bottlenecks

The path is input → existing local physics → sampled position → WebSocket → ordered server queue → validation → replication batch → existing remote snapshot buffer → rendering. Local movement is already responsive without a round trip, so no second prediction system was introduced.

The important remaining latency risks are ordered TCP delivery and the per-socket handler queue: an awaited durable action can delay later movement from that socket. Adjacent ordinary movement already coalesces. The coalescer now preserves world changes, join transitions, respawn/teleport reasons and appearance synchronization as ordering barriers, instead of overwriting those state transitions with a newer ordinary move.

Movement validation, collision checks, correction thresholds and server limits were retained. Existing rollback tests cover stale/duplicate/reordered movement, jitter/loss patterns, stalls, speed limits, collisions and respawn. A Godot test covered 504 mirrored corner approaches and stable edge landing, with no injected speed/position correction. The normal-jump check passed at 97.95 pixels / 3.061 tiles.

## 4. Placement bottlenecks

The placement path is input/target/reach → existing prediction and one request → server authentication/permission/reach/inventory validation → staged world/inventory mutation → durable transaction → authoritative echo and inventory delta → per-cell client confirmation or rollback.

Placement already has prediction; this work fixes repeat timing and the shared event-backlog dispatch problem. It retains prediction eligibility rules, pending inventory reservation, request matching and rejection rollback. There is no added full-world refresh or second competing prediction path.

PostgreSQL latency can still delay authoritative acknowledgement. The local storage test cannot quantify that production component. Existing special-block prediction and placement reconciliation tests passed.

## 5. Breaking bottlenecks

The path is punch → local cracks → server-validated hits → final removal request → tile lock/validation → world mutation and generated drops → durable commit → confirmed update/drop broadcasts → client tile and collision removal.

Pending records now retain request ID, cell, layer, world and last reconciliation time. Guards run before additional local hit progression and before duplicate sends. Matching hit/rejection replies release the pending operation; stale replies do not release a newer operation. Cell-less rejections and multi-cell anchor responses can resolve by exact request ID. A response from another world cannot clear the operation.

After 1.5 seconds without a conclusive response, the client asks for authoritative cell state rather than sending destruction again. The interval is a recovery probe, not a longer timeout masking the bug. An in-flight server commit remains pending. Accepted removals use the existing immediate cell/collision removal path; full-break visual prediction was not needed to fix the reproduced queue/desync defect.

## 6. Network bottlenecks

| Traffic | Audit result |
|---|---|
| Movement | Frequent JSON snapshots; interest filtering and batching already exist. Redundant equipment aliases removed only when `equipment_slots` is present. Alias-only legacy records and individual legacy packets remain supported. |
| Block edits | Requester receives its authoritative result directly; observers use existing world batching. Live client edits now bypass cosmetic event work after packet dispatch. |
| Inventory | Placement/removal can also send an inventory/progression result. This is required authoritative information, not an extra client save RPC. Existing deltas remain. |
| Drops/entities | Server generates and broadcasts actual drop state after commit; observer batching/interest filtering remain. Replay tests assert no new drops. |
| World/chunks | Large joins use existing dictionary/streamed snapshots. These and ordinary gameplay still share the ordered connection. |
| Chat/player state | Reliable messages on that same connection. No new periodic full-state poll was added. Diagnostic ping is opt-in only. |

A simple successful placement normally produces one logical block update plus its requester inventory result. A final break produces its block update, actual generated drop messages and any applicable inventory/progression result. Packet batching and recipient count determine wire packet totals; this is not a fixed one-packet action. Exceptional replay repair deliberately includes authoritative reconciliation. There is no new client persistence RPC or full-world sync per edit.

The final 50-player capture contained 484,626,369 bytes of movement JSON, versus 628,414,174 bytes when the original duplicate fields were reconstructed on the identical captured records: **22.88% less**. This is a same-packet encoding comparison, not a production before/after bandwidth experiment. WebSocket/TCP/TLS overhead is excluded.

The crowded local scenario still averaged approximately 31 MB/s aggregate movement payload, or 4.95 Mbit/s per player when divided by its 15.66-second measured interval. This is substantial and is the clearest remaining optimization opportunity. The test captures include join presence; these figures are approximate interval averages, not sustained capacity limits.

## 7. Rendering/chunk bottlenecks

Single-cell placement/breaking did not rebuild the whole world or a full chunk in the inspected path. Eight actual renderer edits, including coordinates x=15 and x=16 across a chunk boundary, caused **zero chunk rebuilds**, with 97 microseconds total CPU time in the headless fixture. Bulk edits already coalesce rebuilds.

A 100-sample rebuild fixture with 256 cells and one layer measured 1.554 ms mean / 1.969 ms maximum CPU time. It excludes GPU submission, a full production world, real device collision load and effects. The renderer was instrumented rather than rewritten. The confirmed-edit queue was the reproduced render-visible delay, despite the renderer itself already using small updates.

## 8. Persistence/database bottlenecks

Block actions stage in-memory state and await the existing world or combined inventory/world commit. The durable path can serialize/clone world state, acquire locks, save a snapshot, mirror drops/objects and append journal/ledger records. Existing per-world serialization and persistence batching were retained.

Success, drops and inventory must not be announced as committed before the transaction completes. Moving those writes into fire-and-forget work would weaken anti-dupe and rollback guarantees. No such change was made. The new pending-reconcile lock check specifically prevents exposing an unfinished commit.

Local development block handlers were inexpensive, but that does not clear production PostgreSQL as a bottleneck. Existing `BLOCK_ACTION_PROFILE_LOGS=1` stages distinguish request, validation, mutation, persistence queue, database completion and broadcast. The new profiler also records socket queue time and world snapshot clone time. Together they allow production captures to separate database wait, queue delay and client rendering delay without relaxing authority.

## 9. Files/functions changed

Paths below are relative to the indicated repository; generated JavaScript was rebuilt from TypeScript.

| Repository/file | Functions or responsibility |
|---|---|
| Client `Scripts/runtime_profiler.gd` | New opt-in bounded aggregate samples, counters, request timing and application RTT. |
| Client `Scripts/network_manager.gd` | `_process`, packet dispatch/send/receive telemetry; event cell generations; live edit/reconcile ordering. |
| Client `Scripts/input_manager.gd` | `_process`, focus notification and touch cancellation; remainder-preserving holds. |
| Client `Scripts/mobile_controls.gd` | `_update_punch_hold`, global/GUI canceled touch handling and layout-editor cancellation. |
| Client `Scripts/world.gd` | `update_fast_block_place_hold`, hold input and focus-loss termination. |
| Client `Scripts/block_manager.gd` | Request IDs/pending records, `_reconcile_pending_breaks`, `resolve_pending_break_response`, guards, rejection handling and `try_consume_block_break_input_cadence`. Includes existing related break work. |
| Client `Scripts/world_state_sync_manager.gd` | Matching hit/reconcile handling; `apply_network_block_update` timing; test-double-safe method checks. |
| Client `Scripts/player.gd` | Existing movement-step CPU timing. |
| Client `Scripts/world_tilemap_renderer.gd` | `_rebuild_chunk` timing/count/cell instrumentation. |
| Server `src/server_runtime_stats.ts` | Bounded runtime histograms and opt-in Node GC observation. |
| Server `src/server.ts` | Queue/handler/parse/send/world-clone spans, five-second aggregates, authenticated ping; already-broken repair and pending reconciliation lock handling. |
| Server `src/server_phase7_dispatcher.ts` | Explicit diagnostic ping route. |
| Server `src/server_message_router_helpers.ts` | `coalesceQueuedPlayerPosition` transition barriers. |
| Server `src/server_socket_delivery_helpers.ts` | Stateless `compactMovementBatch`; preserve complete slot snapshots and backpressure recovery. |
| Client tests/tools | Performance, event backlog, chunk boundary, profiler, break state and touch regression fixtures; `tools/run_runtime_regressions.cjs`. Refreshed stale layout/placement test fixtures and event ordering expectations. |
| Server tests/tools | `scripts/runtime_network_stress.js`; router, socket-delivery and profiler assertions; related committed-break race/reconciliation tests. |

Unrelated dirty crafting scripts/assets and other workspace work were not reverted or included as performance fixes.

## 10. Exact optimizations implemented

1. Preserve fractional timing in pointer punch, mobile punch and repeated placement. Limit post-stall catch-up to one action per frame.
2. Preserve bounded cadence lateness in the 300 ms block input gate; cap carry at 75 ms to retain at least the server's 225 ms hit spacing at the client input gate.
3. Apply live confirmed block edits without waiting for the cosmetic event queue; invalidate earlier queued updates only for the affected cell.
4. Make pending breaks request-specific, prevent duplicate progression/sends and recover with authoritative reconciliation.
5. Repair already-broken cells and avoid applying unfinished persistence snapshots.
6. Preserve movement transition packets during queue coalescing.
7. Remove redundant legacy equipment aliases from movement batches, retaining complete authoritative slot data each time.
8. Add opt-in instrumentation with bounded memory and five-second aggregates. No default per-frame logging.

No server rate limit, validation rule, damage threshold, physics rate or transaction guarantee was relaxed. No production setting or deployment was changed.

## 11. Before/after measurements and verification

### Interaction timing: 30 seconds of simulated frame deltas

These run the real hold methods with lightweight action fixtures. They measure input repeat scheduling, not completed durable block operations or rendered device FPS. Placement advances its target for each action.

| Simulated FPS | Punch repeats before → after | Place repeats before → after |
|---:|---:|---:|
| 15 | 90 → 100 | 150 → 187 |
| 30 | 100 → 100 | 180 → 187 |
| 60 | 100 → 100 | 180 → 187 |
| 144 | 98 → 100 | 180 → 187 |

Long-stall tests confirm one action with no immediate catch-up burst. Focus/cancel and separate-finger ownership assertions pass.

### Controlled event-backlog reproduction

The fixture queues 4,096 cosmetic tiles and deliberately gives each 250 microseconds of CPU work. The old append-to-tail behavior is reconstructed in the fixture. It took 410 dispatch iterations before the break, representing 13.67 seconds if one iteration runs per 30 FPS frame. The new path applies the break immediately in the same dispatch, with zero event-queue frames and about 9 microseconds of fixture dispatch work.

**The 13.67 seconds is a modeled delay for this controlled workload, not a measured production or phone latency.** The important invariant is that unrelated event backlog no longer delays the committed edit or restores it afterward.

### Real local WebSocket stress

Runs used 1, 6, 25 and 50 development clients. Each client generated movement every 50 ms (requested 20 Hz; actual Windows scheduling was roughly 16–19 Hz). Clients shared a world and modified a nearby cell while others moved. Ordered application delays simulate 30/75/150 ms RTT with deterministic per-direction jitter of ±15% of RTT. No OS-level TCP loss was injected.

Final 50-player run, with inventory and drop replay assertions:

| Nominal RTT | Place request → response | Final break request → response | Application ping |
|---:|---:|---:|---:|
| 30 ms | 89.24 ms | 48.59 ms | 46.93 ms |
| 75 ms | 95.46 ms | 101.50 ms | 95.79 ms |
| 150 ms | 201.27 ms | 189.68 ms | 156.06 ms |

These are three individual operation samples, not statistically robust latency percentiles. The final-break measurement begins at its final request, excluding the intended preceding punch duration. Earlier 50-player samples were 48.33/79.43/194.68 ms for placement and 46.73/85.41/186.09 ms for final break. There is no matched pre-fix production RTT baseline from which to claim a general latency percentage improvement.

All 50 clients converged on the tested edited cells and observed the same six authoritative drops in the final run. Replaying placement/break IDs and a rival's already-broken request produced no additional drops and did not change either checked inventory. Normal test movement produced zero correction rejections. This is touched-cell/reward convergence, not an exhaustive equality check of every world field.

During final 50-player profiling windows:

- Movement handler mean: 0.049–0.067 ms; maximum 4.269 ms. Movement queue wait maximum 5 ms.
- Block handler mean: 1.22–3.63 ms; maximum 12.06 ms. These include development persistence, not PostgreSQL.
- JSON parse mean: about 0.005 ms. World snapshot clone mean: 0.064–0.119 ms.
- Observed GC pause maximum: 1.783 ms. Sampled process RSS reached about 147 MB; this short run is not a leak/soak test.
- Maximum 1-second monitor scheduling lag: 33.43 ms. Windows timer scheduling and the local test process contribute; this is not a 33 ms game physics tick.

### Regression checks

Passed: full TypeScript/build suite, final changed-source builds/typecheck, router/dispatcher/socket/profiler tests, movement rollback scenarios, placement consistency, server validation, anti-dupe, drop-pickup invariants, rate limits, world journal and the other offline security subchecks. Lint reports zero errors and one existing unused-disable warning in `server_player_state_helpers.ts`.

The delayed-commit two-player same-cell fixture passed: one removal, one drop-generation pass, one confirmed broadcast, no success before persistence completion. Authoritative already-broken repair and pending-lock tests passed.

Godot checks passed for hold timing, canceled/multiple touches, layout/settings integration, single tap, inventory layout, punch reach, zoom, device UI scaling, snapshot buffering, packet batching, inventory incremental refresh, placement/special-block prediction, break pending/reconciliation, renderer collision cleanup, rejoin visuals, cosmetic event delivery/backlog, chunk edits, bounded profiler, corner contacts and normal jump height. The runner treats Godot script assertions as failures even when Godot exits with status zero. The sandbox's root certificate-store warning was present in headless runs; these fixtures do not use TLS.

Release follow-up: the user authorized the npm dependency audit. It passed the configured high-severity threshold with no high/critical findings and five moderate advisories (`qs` and the `uuid`/Google API dependency chain). No breaking dependency upgrade was bundled into these performance fixes. The full combined release gate is run again by the deployment workflow.

## 12. Remaining bottlenecks and test limits

- Crowded-world movement still repeats full appearance/identity data. The measured bandwidth is substantial even after alias removal.
- All active traffic still shares ordered TCP and the server's per-socket action queue. Large snapshots, retransmission or a slow durable action can delay later gameplay messages. Client queue prioritization cannot undo TCP ordering.
- Full world serialization/snapshot work and PostgreSQL transaction time remain possible production bottlenecks. Current tests did not use production PostgreSQL/Redis, a real reconnect durability cycle, or multi-instance routing.
- No physical low/mid/high phone profiles, rendered gameplay FPS/GPU capture, thermal test or long soak test was available. Frame-delta fixtures do not substitute for those measurements.
- The stress harness moves clients over a small valid range and targets a small number of cells. Corner/jump physics and same-cell races are separate fixtures. It is not a full 50-human gameplay session or sustained 60 Hz traffic load.
- Packet-loss behavior was covered only by existing movement-buffer/rollback fixtures. Actual TCP loss/congestion and cellular transitions remain untested.

## 13. Recommended next optimization

First capture an affected physical phone and a staging server with the opt-in profiler, including a crowded world and a block operation during a slow database commit. Use client frame/dispatch/queue metrics and correlated operation-stage logs to establish where the remaining time is spent.

The next code optimization supported by this capture is a versioned movement format that sends appearance/identity on change and on interest entry/reconnect, with compact kinematic updates between them. It must explicitly recover after coalescing/backpressure and carry unequips; simply omitting unchanged fields without a resynchronization contract would create new visual desync. Validate at the real client send rate and under bandwidth limits before rollout. If database stage timings dominate instead, optimize the existing transaction/snapshot path while preserving atomic inventory/world/drop/journal commits.

## Diagnostics and reproduction

Client: `PIXELMANIA_RUNTIME_PROFILE=1` or user argument `--runtime-profile`. Server: `PIXELMANIA_RUNTIME_PROFILE=1`. Both emit `[RUNTIME_PROFILE]` aggregates every five seconds and default off. Client histograms retain at most 512 recent values per metric and 512 pending timing requests; server histograms cap metric names at 128 and recent samples at 512. `p95_recent` refers to that bounded recent sample, while count/mean/max cover the aggregate window.

Client output includes frame duration, engine process/physics duration, movement-step CPU time, packet/event backlog, JSON/dispatch time, send/receive counts/bytes, movement sends, block response/apply timing, chunk rebuilds/cells/time, node/object counts, static memory and draw calls. FPS is derived from frame duration; rates are count or byte deltas divided by `window_seconds`. Godot's reference-counted object/memory counters are used rather than inventing a Godot GC-pause metric.

Server output includes connected players, memory/GC, queue wait and handler duration by message type, parse/direct JSON-send/world-clone spans, cumulative network attempts/bytes/coalescing and existing loop-health telemetry. Serialization timing currently covers direct `sendJson` calls; it is not an exclusive measurement of every batched serialization. Existing `BLOCK_ACTION_PROFILE_LOGS=1` supplies durable action stage timings. Optional `PIXELMANIA_BREAK_TRACE=1` supplies cell/request-specific client trace events. The aggregate profiler logs no raw packets, identities or tokens; detailed existing operation traces do include request/cell context. Client/server monotonic clocks must not be subtracted from one another.

From the client repository:

```powershell
$env:PERF_OUTPUT_DIR='D:\Pixelmania\performance-20260918\client-tests'
node tools/run_runtime_regressions.cjs
```

From the server repository (isolated loopback development server and disposable data; no production credentials needed):

```powershell
$env:PERF_OUTPUT_DIR='D:\Pixelmania\performance-20260918\stress-new-run'
$env:PERF_PLAYERS='50'
node scripts/runtime_network_stress.js
```

Raw evidence: `D:\Pixelmania\performance-20260918\baseline-client4.log`, `after-client.log`, `client-tests\`, `stress-1\`, `stress-25\`, `stress-50\`, `stress-6-final\`, `stress-50-final\`, and `typescript.log`. Initial failed/debug attempts are retained separately; the results above use the named successful runs. Baseline source copies are in `baseline\`.
