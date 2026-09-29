# Multiplayer audit — 28 September 2026

## Baseline, recorded before implementation changes

Scope: current working client and backend, including the user's existing edits. Original files and git status are retained in `D:/Pixelmania/network-audit-20260928/before`. No deployment is part of this audit. The July Netfox handoff is historical; the current project defaults to WEBSOCKET.

### Architecture and authority

- Godot 4.7.1 client, `NetworkManager` autoload, `WebSocketPeer`, TLS WebSockets to a central Node `ws` service. All default traffic is reliable, ordered TCP. No player host, inbound mobile peer connection, STUN/TURN, or host migration is involved. Separate optional Netfox/ENet and custom authoritative modes have explicit mode gates; switching the default transport is not justified by this audit.
- Socket open → protocol login/capability advertisement → account token/password/refresh authentication → server socket identity → world route lookup/validated redirect if needed → join acknowledgement with entry session/revisions → streamed world snapshot → local world initialization/spawn → ready/catch-up/active handshake → incremental events. World entry and socket generations reject obsolete replies.
- Local `player.gd` physics applies input immediately at the physics rate. Its post-physics sample is sent through `player_manager.gd` and `network_manager.gd`. This is client simulation with server position, speed, acceleration, collision and teleport validation, **not** deterministic input replay. Introducing full replay would require matching the large gameplay physics implementation on the server.
- Remote players have a dedicated snapshot buffer, timestamp/sequence rejection, adaptive 45–140 ms interpolation and at most 120 ms decelerating extrapolation. Their physics movement is disabled. Local authoritative corrections move the collision root immediately and tween presentation children only. No additional input delay is needed.
- Server is event driven, not a fixed-rate physics server. Presence/world fanout has 16 ms base batch timers, rising with population; the one-second health probe is not a game tick. Default local physics sampling can reach 60 Hz; rendering is separately gated.
- Server validates block permission/reach/cooldown and ownership. Breaks have intentional multi-hit cadence, request identities, cell locks and authoritative repair. Placement has local visual prediction/reservations and confirmation/rollback. Static blocks use changes, not constant full-world replication. World snapshots are for entry/recovery.
- Drops, inventory, trades, displays, equipment ownership, currency, progression and locks remain server validated. PostgreSQL is durable truth, Redis is temporary coordination; isolated local tests use disposable development persistence. Economic transactions retain locks, item instances, ledgers and rollback. Movement/action queue ordering protects reach validation across awaited writes.
- Display deposit/withdraw already has one mutation request, a validated server visual broadcast, durable inventory/world commit and final inventory delta. Failure broadcasts rollback. Optional DISPLAY_PROFILE separates validation/broadcast from database completion. The existing direct-interaction client path avoids opening inventory merely to dispatch the request.
- Player/drop interest management, movement coalescing, unchanged-presence suppression, column-encoded complete snapshots, block deltas and bounded world streams already exist. Critical events must not be discarded under socket backpressure.

### Problems confirmed in source

1. **Bursty crowded-world movement:** a 500 ms client quota is computed from the server's *outgoing batch capacity*, then density-scaled. At 50 players/112 batch items it permits 6 sends per half-second. At 60 Hz these exhaust early and leave a long silence. A separate rate limit and 120 ms retry timer add more unevenness. Batch size is not a client input rate.
2. **Unsent visual changes marked delivered:** `_should_send_full_movement_visual_sync` advances its cache when constructing a payload. Rate-limited/coalesced/failed packets can consume the change before it reaches the socket, suppressing it until the 2.5-second resync.
3. **Incomplete reconnect join retained:** only forced reconnects invalidate old joins, and invalidation checks only `active_join_request_pending`. A dropped socket during snapshot/ready stages can suppress a new join, or leave stale queued movement/events attached to the replacement transport.
4. **Half-open/mobile lifecycle gap:** normal clients have no application heartbeat watchdog, connect/auth deadline or pause/resume handling; profiler pings are opt-in. Retries use a fixed two seconds. A Wi-Fi/cellular switch can leave a TCP socket appearing open indefinitely.
5. **Receive-time anchoring:** interpolation derives server time anew from each packet's arrival. Jitter can stall the render timeline and then accelerate it. Existing tests cover modest jitter but not the complete requested matrix.
6. **Telemetry counts attempted bytes as sent:** backend `sendRawJsonToSocket` increments sent bytes before checking whether a packet is skipped/disconnected or send throws. Backpressure can therefore look like actual delivered bandwidth.
7. **Equipment signature gaps:** unchanged-presence detection omits beard/body accessory slots while complete snapshots include them. Changes can wait for an idle heartbeat.

### Existing limitations requiring explicit boundaries

- WebSocket head-of-line blocking remains: transport-level loss is recovered in order. Application snapshot skips are not packet-loss measurements. Movement cannot be made truly unreliable on this socket without a transport design change.
- Input sequence numbers exist, but ordinary accepted movement has no per-input replay acknowledgement. Corrections use accepted/rejected sequences. Client-reported velocities influence the existing speed envelope; endpoint collision validation is not full server physics. These pre-existing authority limits need regression-backed work, not a blind rewrite.
- Durable actions can delay the same actor's movement queue while PostgreSQL is pending. Existing runtime profiler distinguishes queue residence, handler time, event-loop delay, serialization and DB/pool/write-queue time. Moving positional authority concurrently with a transaction could invalidate action reach/order.
- Physical Android/iOS devices, cellular handover, real kernel packet loss and production PostgreSQL/Redis load are not automatically available on this Windows machine. Local engine and server tests will be reported separately from those unverified environments.

## Implementation, verification and measurements

The changes below are local and reviewable. No production deployment, database migration, transport replacement or new dependency was made. Unrelated pre-existing UI, world loading and backend edits were preserved. Evidence lives in `D:/Pixelmania/network-audit-20260928/`.

### Targeted changes and root causes

| Finding | Change | Practical effect |
|---|---|---|
| Batch capacity incorrectly used as a half-second client quota | One evenly paced movement deadline; normal movement capped at 30 Hz, or 20 Hz above eight players; player-manager sampling follows that rate | Removes burst/silence behavior and decouples traffic from render FPS |
| Queued positions acquired fresh timestamps after waiting | Resample the live player before retry; keep one newest unsent position; discard old-world/incomplete-entry queues | Old transforms cannot masquerade as current movement |
| Movement piled up above an already congested TCP socket | Coalesce normal movement while Godot's outbound buffer exceeds 8 KiB; retry on the paced schedule | Limits additional stale movement without discarding critical gameplay messages |
| Appearance cache advanced before delivery | Cache changes only after `send_text` succeeds; reset on new join | Failed/coalesced sends retain equipment, fishing and damage changes |
| Arrival jitter moved the interpolation clock abruptly | Advance presentation time on the monotonic local clock, gently slewing by at most 10% toward the latest target | Reduces remote playback pauses/jumps while retaining adaptive buffering, Hermite interpolation and bounded extrapolation |
| Replaced transports inherited incomplete world entry | Invalidate snapshot/ready state on every socket replacement; retain intended world and authenticated session; clear obsolete pending state | Reconnect can issue a fresh authorized join even after a partial world download |
| Real-game fault test exposed stale reconnect position | Mark recovery for the existing normal entrance-spawn path; suppress movement during incomplete entry | Correct server-approved position is applied before reveal, instead of a later hard correction |
| No ordinary-client half-open watchdog | Monotonic 15 s connect / 20 s authentication deadlines; one application probe every 5 s, 30 s timeout; jittered exponential retries capped at 30 s | Controlled recovery after silent connection failures; no duplicate heartbeat loop |
| No application lifecycle handling | Suspend network processing while paused; reset probe/deadline and discard queued movement on resume | Background time is not itself treated as a failed heartbeat; resume probes the route |
| Backend bandwidth metrics counted skipped/failed sends | Increment sent-byte/type statistics after successful `ws.send` | Separates attempted traffic from bytes accepted into the socket, without claiming remote delivery |
| Beard/body accessory absent from presence signature | Include both canonical equipment slots and aliases | These equipment changes trigger presence replication |
| Client velocity enlarged allowed movement distance | Remove client-reported speed from the server's maximum-distance allowance | Forged velocity cannot raise the configured server speed cap; trusted teleport/lava rules remain explicit |

The speed-envelope issue was discovered during the deeper authority review after the initial baseline notes. It was reproduced and added to the movement regression suite before being accepted as fixed.

### Movement and corner behavior

Local input still runs directly through `CharacterBody2D` physics. No input buffer or extra latency was added. Sequence numbers advance only on successful movement send; server timestamps/sequences still reject stale state. Normal movement remains local simulation followed by server validation. This implementation does **not** claim deterministic server simulation, per-input accepted-state ACKs or buffered input replay.

Remote transforms have one presentation owner: `WebSocketSnapshotBuffer` through `PlayerManager`. Local corrections update the collision root immediately and smooth visual children only. The existing separation was retained; tweening the collision body back into geometry would reintroduce corner bounce. The 504 mirrored corner approaches and stable edge-landing regression passed. Existing rollback checks also cover collision corrections, stalls, sequence ordering, timestamp credit, jumps/impulses and legal teleports. This demonstrates the tested cases, not every possible world layout.

The initial fault test found one 43–46 px `world_entry_position_pending` correction after reconnect. That was a spawn lifecycle mismatch, not interpolation. The corrected recovery run has zero corrections and no duplicate remote entity. A recovered session currently enters at the authoritative entrance; it does not promise to resume at the exact pre-disconnect coordinate.

### Protocol, bandwidth and interest management

The companion [message catalog](network_message_catalog_20260928.md) contains 153 directional message/route entries, 50 multiplexed inventory actions, behavioral frequency, reliability, ordering/ACK policy, batching/duplicate notes, and measured mean/max payload sizes where exercised. The [JSON index](network_message_catalog_20260928.json) includes source references and remaining literal object tags for review. Every unexercised route is labeled **unmeasured**; static discovery is not proof that every trade, purchase, machine or quest action was executed.

All active default traffic is ordered reliable WebSocket/TCP. Critical mutations retain reliable request/result processing. Movement favors freshness before entering the socket, but cannot overtake bytes already inside TCP. True independent unreliable movement would require a negotiated second transport and a separate design/security review.

Existing nearby-player/drop interest management, column-encoded batches, visual change detection, unchanged-presence suppression, dirty account saves and static world deltas were retained. Full snapshots remain entry/recovery operations. Intentional multi-hit breaking and readiness retries are not duplicate economy commits. Action-triggered position flushes may bypass the normal movement cap so action validation sees current position; unchanged flushes are already suppressed by `PlayerManager`.

Measured JSON payload examples from the initial rendered two-client test and 10-/50-client fixtures (no TLS/TCP framing): client movement averaged 592 B including appearance resyncs, inventory transaction requests 444 B, and block requests 441 B. Combined server movement batches averaged about 12.2 KiB and reached 19.2 KiB; world-stream chunks reached 36.3 KiB. Those large frames matter for TCP head-of-line delay even though UDP fragmentation is inapplicable. The catalog records exact counts and measurement inputs.

Normal small-world movement in the pacing fixture fell from 89 to 48 sends over 1.6 s (46% fewer). Crowded-world sends rose from 24 to 32 because the old quota was starving movement; the improvement there is even timing, not fewer bytes. Idle sampling now honors the server's longer heartbeat guidance instead of truncating it to 1.5 s, with a 10 s defensive maximum. The connection probe adds about one small request/response per five seconds.

The 50-client all-nearby fixture still delivered 394,645,015 movement JSON bytes across clients during a 24.53 s measured window: about 322 kB/s per client on average. This is a worst-case dense moving group using the synthetic sender, not measured mobile data usage or proof of reduced production bandwidth. Repeated complete movement fields remain an opportunity for negotiated sparse/binary snapshots. Existing column compaction was already present before this audit and is not claimed as a new optimization.

### Server, persistence and gameplay operations

Replication remains event driven. Base fanout batching is 16 ms, adjusted by population; no server tick increase was made. The `/health` one-second timing statistic measures event-loop scheduling, not a 1 Hz physics simulation. In the 50-client run, movement queue residence averaged 0.013 ms and peaked at 4 ms, 677 incoming movement messages were coalesced, and zero positional corrections occurred. Twenty-two stale sequences were safely rejected; seven duplicate request identities were handled without duplicate inventory effects. These numbers use disposable local storage, not production PostgreSQL/Redis.

Block placement follows request → authenticated actor/reach/permission/item checks → locked mutation → authoritative event/delta → inventory result. Normal gameplay already predicts the local placement and reconciles rejection. The real-game timing fixture deliberately sends through `NetworkManager` and waits for the authoritative block, so its placement measurement includes a round trip rather than claiming local prediction speed.

Breaking follows the same authority path, with server-enforced tool cadence and cumulative hits. The test sends successive intentional hits and verifies removal and resulting state; repeated clicking is not assumed to be packet loss. Existing request identity, pending-placement repair and render reconciliation checks pass.

Display case/box deposit and withdrawal use the shared inventory transaction path. Validation and provisional world visual broadcast precede durable completion; failure must roll back. No extra round trip or client authority was added. Fresh display profiling showed validation/mutation/broadcast around 0–1 ms and local persistence completion around 2 ms in a representative rendered-run withdrawal; transaction-handler maximum in that window was 5.8 ms. At 250 ms proxy RTT, a deposit completed in 297 ms with inventory closed and 272 ms open. These are individual observations, not statistically meaningful p95 values. They did not reproduce a several-second display delay or an inventory-open penalty. Actual PostgreSQL lock/commit stalls still require production/staging traces.

### Mobile, P2P and connection state

The observable state sequence includes `DISCONNECTED`, `CONNECTING`, `AUTHENTICATING`, `CONNECTED`, `JOINING_WORLD`, `IN_WORLD`, `RECONNECTING`, `FAILED` and `SUSPENDED`. Socket-generation guards prevent obsolete sockets from applying state to a replacement. There is one outstanding health probe and one controlled reconnect schedule. Authentication/session replacement and restriction handling are retained; economy actions are never automatically replayed after reconnect.

Mobile clients make outbound connections to the central server. No active P2P host, STUN/TURN requirement, symmetric-NAT inbound requirement or host-migration problem exists here. The optional historical Netfox/custom paths remain gated and were not converted into a second active movement authority. PC-host/mobile-host combinations are inapplicable to the default architecture.

Engine tests cover 30, 60 and 144 FPS; the real observer runs at 30 FPS. Application pause/resume was exercised through Godot notifications. No physical Android/iOS device, carrier handover, IPv6-only cellular route or real background OS socket suspension was available. The implementation is ready for those device tests, but they are not claimed to have passed. Loopback tests use `ws`; production TLS and certificate behavior were not validated.

### Development instrumentation

Enable client/backend aggregate profiling with `PIXELMANIA_RUNTIME_PROFILE=1` (or the client's `--runtime-profile`). Existing bounded profiling reports FPS/frame/physics time, parse/serialization time, receive queues, operation request-to-response timing, server event-loop delay, per-handler queue/run time and database/pool/write-queue timing where present. This change adds connection state, RTT, application jitter, missed health probes, outbound buffer bytes, snapshot/batch rates and display transaction latency. Corrections, packets and bytes per second are derived from windowed counters. `BLOCK_ACTION_PROFILE_LOGS=1` provides block stages; display handlers emit `DISPLAY_PROFILE` stage records.

RTT and jitter are **application** measurements: client scheduling, server queueing and world-build stalls can contribute. The recovery run's approximately 474 ms jitter EWMA included initial scene-load stalls; it must not be described as network-only jitter. `tcp_packet_loss_percent` is explicitly `null`; missed probes and skipped snapshots do not measure TCP segment loss. No new release gameplay overlay was added.

### Measurements and tests

| Check | Before | After / result |
|---|---:|---:|
| Small-world pacing, 1.6 s | 89 sends; 331 ms largest gap | 48 sends; 44 ms largest gap |
| Crowded-world pacing, 1.6 s | 24 sends; 455 ms largest gap | 32 sends; 56 ms largest gap |
| Mean RMS frame-step error, 60 deterministic interpolation conditions | 1.285 px | 0.265 px (79.4% lower) |
| Worst frame step in that matrix | 10.650 px | 5.611 px (47.3% lower) |
| Existing jitter case, 60 FPS max step | 3.201 px | 1.870 px |
| Existing jitter case, 30 FPS max step | 5.572 px | 3.740 px |
| Unsent appearance retains dirty state | Failed | Passed |
| Incomplete join invalidated on transport replacement | Failed | Passed |
| Forged velocity increases legal distance | Vulnerable envelope in source | Regression rejects it |
| Rendered game, 250 ms RTT | No comparable baseline run | Local movement within three physics frames, real jump, block actions, display conservation and reconnect passed |
| Interrupted join + 5% recovery-stall injection, 150 ms RTT | One reconnect spawn correction before final lifecycle fix | Zero corrections, no duplicate player, inventory conserved |

Pacing measurements come from the initial baseline/after fixture under comparable conditions, not a promise of exact scheduling on every machine. Matrix comparisons use identical deterministic traces. Existing constant-latency and direction/jump cases also pass. Matrix cases combine RTT 0/50/100/150/250 ms × skipped snapshot fractions 0/1/3/5% × rendering 30/60/144 FPS, jitter up to 40 ms, and a 300 ms recovery stall. Bounds assert no backward steady motion, bounded frame steps, and bounded buffers.

**Loss-model boundary:** skipped snapshots stress interpolation. The real-game proxy preserves FIFO ordering and introduces 100 ms recovery stalls at configured message fractions; it never labels those as dropped TCP segments. Neither fixture is a real 1/3/5% IP packet-loss or cellular test.

The reproducible regression runner executes 17 Godot and 13 Node checks. The selected suite covers connection deadlines/backoff/stale pongs, pacing/appearance/rejoin state, snapshot interpolation and codecs, direct interactions, 504 corner cases, placement/break/seed rollback, display interaction with inventory open, mobile input cadence, entry spawn/reconciliation, remembered login, movement rollback, message routing, validation, anti-dupe locking, session security, bot rate limits, scale wiring and runtime profiling. The movement suite has 21 scenarios. Generated backend modules were rebuilt and checked against their TypeScript sources.

The real integration runner launches a disposable local backend, two independently delayed WebSocket proxies, and two actual Godot `Scenes/main.tscn` clients. It drives real input/physics, remote presentation, placement and multi-hit breaking, world lock/display placement, direct display deposit/withdraw with inventory closed/open, token reconnect, initial-stream interruption, and pause/resume. It verifies single remote entity, inventory conservation, fresh entry session and no movement corrections. The rendered run also saves `game.png` for visual inspection. Test accounts/data are isolated and no live endpoint is contacted.

Final selected regression result: **30/30 passed**. Final rendered game: 250 ms configured RTT, placement visible in 295 ms, display deposit 294 ms closed / 273 ms open, 31 distinct remote positions, one remote entity maximum, zero corrections. Additional full game runs at 50 ms with 1% recovery injection and 100 ms with 3% injection also passed with zero corrections; the actor proxies actually injected one and three stalls respectively. The 150 ms/5% interrupted-join run injected five actor stalls and replaced its transport three times (initial, join recovery, in-world recovery). These small samples establish functional recovery, not latency percentiles.

A separate pre-existing static test, `world_join_state_lifecycle_test.gd`, fails because it requires the literal reveal fade `0.34` while the existing loading UI uses `0.08`. That unrelated UI constant/test was not changed. This is an explicitly recorded repository test failure, separate from the passing selected networking suite; no claim is made that every repository test passes.

Primary evidence:

- `baseline-reliability.log`, `reliability-first.log`, `baseline-snapshot.log`, `matrix-before.json`, `matrix-after.json`.
- `regressions-verified/results.json` and per-check logs: final selected regression results.
- `game-rendered/`: first successful visual game test, actor/observer results, server/client stage logs and screenshot.
- `game-rendered-final/`: final-code rendered test at 250 ms RTT and in-world interruption; screenshot inspected.
- `game-recovery1/`, `game-recovery3/`: final-code 50/100 ms RTT tests with actual 1%/3% ordered-recovery injection.
- `game-recovery5-verified/`: 150 ms RTT, 5% recovery injection, initial stream cut and subsequent in-world cut; zero corrections.
- `load50-after/results.json`: 50 synthetic clients, RTT mix 0/50/100/150/250 ms, local backend load/authority measurements.

### Files changed by this audit

Client runtime:

- `Scripts/network_manager.gd` — paced/coalesced movement, reliable appearance cache, connection health integration, recovery lifecycle/spawn and debug state.
- `Scripts/player_manager.gd` — sampling cadence and idle heartbeat guidance.
- `Scripts/networking/websocket_snapshot_buffer.gd` — stable presentation timeline.
- `Scripts/networking/connection_health.gd` (new) — monotonic deadlines, probes and retry policy.
- `Scripts/runtime_profiler.gd` — health, receive snapshots and display transaction timing.

Client validation/documentation:

- `tests/network_reliability_test.gd`, `tests/connection_health_test.gd`, `tests/network_conditions_matrix_test.gd`, `tests/network_game_smoke.gd` (new).
- `tests/display_direct_interaction_test.gd` and new `tests/fixtures/display_direct_block_fixture.gd` — fix test bootstrap by dynamically loading the fixture after autoloads, without changing display gameplay.
- This report and `network_message_catalog_20260928.md/.json` (new).

Backend (`../PixelManiaServer`):

- `src/server_phase11d_standard_movement.ts` and generated `server_phase11d_standard_movement.js` — server-owned speed envelope and equipment signatures.
- `src/server_socket_delivery_helpers.ts` and generated `server_socket_delivery_helpers.js` — accurate accepted-send telemetry.
- `scripts/check_movement_rollback_regression.js`, `scripts/check_server_socket_delivery_helpers_build.js` — security/equipment/send-counter regression cases.
- New `scripts/check_network_audit.js`, `scripts/network_game_smoke.js`, `scripts/audit_network_messages.js` and three `package.json` commands — reproducible regression, real-game fault tests and protocol index.

### Reproduce

From `D:/Pixelmania/PixelMania/PixelManiaServer` in PowerShell:

```powershell
npm run build:server-socket-delivery-helpers
npm run build:server-phase11d-standard-movement
$env:AUDIT_OUTPUT_DIR = 'D:\Pixelmania\network-audit-new-checks'
npm run check:network-audit

# Use a fresh output directory for every game run.
$env:AUDIT_OUTPUT_DIR = 'D:\Pixelmania\network-audit-new-game'
$env:AUDIT_RTT_MS = '250'
$env:AUDIT_RECOVERY_PERCENT = '5'
$env:AUDIT_INTERRUPT_JOIN = '1'
$env:AUDIT_RENDER = '1'
npm run test:network-game
```

`GODOT_BIN` overrides the default sibling Godot 4.7.1 console executable. `AUDIT_OBSERVER_FPS` defaults to 30. Set `AUDIT_RECOVERY_PERCENT` to 0/1/3/5 to vary the ordered-recovery model. `npm run audit:network-messages -- <summary.json> <results.json>` regenerates the catalog with supplied measurements; without files it produces an explicitly unmeasured static index.

### Remaining limitations and next measurements

1. Run real Android/iOS devices through Wi-Fi/cellular switches and long background/foreground cycles; test actual IP loss and IPv6/TLS. The current evidence is Windows engine testing plus controlled application faults.
2. World construction remains a visible join cost: approximately 1.1–1.3 s foreground build and roughly 2.6–2.8 s total join in the recovery fixture. Existing stage profiles identify this separately from RTT. Improving scene/block construction is a distinct client-loading task; no artificial delay was added to hide it.
3. Dense 50-player movement still has substantial JSON bandwidth. Measure negotiated sparse movement fields or compact binary frames, and viewport-aware interest settings, against compatibility/re-entry behavior before changing the protocol.
4. TCP cannot isolate movement from retransmission or a large reliable world frame. Application coalescing reduces extra backlog but does not remove head-of-line blocking.
5. Server movement authority is bounded validation with collision endpoint checks, generous grace and trusted event exceptions. It is not full server physics or swept collision validation. Removing velocity-based envelope inflation closes the reproduced issue, not every possible speed/collision exploit.
6. Durable transaction/actor ordering remains intentionally serialized. Collect PostgreSQL pool/lock/commit traces under realistic inventory/trade/display load before considering concurrency changes. Existing local tests cannot certify production durability or cross-instance Redis behavior.
7. World recovery is an authenticated fresh snapshot with entrance spawn and no automatic economic-action replay. Exact-position resume and durable cross-session operation receipts would require additional server session semantics.

No deployment was performed. Review the focused changes alongside the existing working tree before release.
