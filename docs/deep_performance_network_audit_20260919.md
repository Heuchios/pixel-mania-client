# PixelMania performance and networking audit — September 19, 2026

## Result and evidence boundaries

**A substantial production bottleneck was found:** routine account changes triggered a PostgreSQL save of every registered account. Production logs show these saves taking 4–5 seconds, with unrelated writes queued behind them. Routine saves now identify and persist only the changed accounts, including both sides of friendship changes. Complete recovery backups and durable transaction boundaries remain intact.

Three additional measured costs were reduced: full collision-map rebuilds after individual edits, repeated movement-packet field names, and rebuilding unchanged remote equipment keys every frame.

This report separates production observations, controlled reproductions, and remaining risks. The user could not identify a particular time, world, or phone. Therefore this is **not proof that every reported lag episode has the same cause**, or that production latency has already improved. These changes are saved in the working repositories; this audit did not deploy them.

### Method

- Mapped the architecture before editing. Original map: [architecture-before-changes.md](D:/Pixelmania/performance-20260919/architecture-before-changes.md).
- Initial source: client `202e00ab`, server `3a4f60e`, plus existing working changes recorded in [source-snapshot.json](D:/Pixelmania/performance-20260919/source-snapshot.json). Experiments used isolated checkouts, then audit-only source patches were applied to the newer working repositories. Concurrent shop, quest, and seed work was preserved.
- Node 24.12.0 and Godot 4.7.1 on this Windows workstation. Production reported Node 22.22.2. CPU timings are workstation measurements, not production or phone benchmarks.
- Real local WebSocket servers, disposable development identities/storage, scripted movement at 20 Hz, RTT settings 0/30/75/150/250 ms with deterministic jitter. The ordinary 50-player world cap was preserved; the 60-player test used worlds of 50 and 10.
- Paired bandwidth runs used the same action fixture with receiver encoding as the variable. Counters exclude joins and the first second of warm-up. A test-only loader made dirt drops deterministic so replay tests cannot randomly pass or fail because no drop rolled. Production drop probabilities were not changed.
- No production load generation, database mutation, restart, or configuration change. Read-only production health and bounded PM2 log tails were inspected.

## 1. Top bottlenecks discovered

| Finding | Evidence | Change |
|---|---|---|
| Whole-account saves occupy the global PostgreSQL write queue | Production `saveAccountStates` executions of 4,151–5,085 ms; unrelated `mirrorPlayerWorld` waits of 4,503–4,782 ms | Track changed account keys; save only that batch; preserve failed work for retry |
| One foreground edit discards the entire collision overlay | Actual cache functions rebuilt a 7,000-cell map 120 times for 120 edits | Update the authoritative cached cell; keep full invalidation for bulk changes/restoration |
| Nearby-player movement repeats the same JSON field names | 50-player paired runs: 32.85 → 16.02 MB/s aggregate movement traffic | Negotiated `columns_v1` complete snapshots |
| Stable equipment normalization/string building repeats every render frame | Actual client function, 50 remote nodes: median 0.716 → 0.061 ms/frame | Reuse the equipment key already computed when a snapshot arrives |

## 2. Root cause of intermittent lag

There is direct production evidence of **persistence queue stalls**, not just a theoretical concern. Relevant worker log entries on September 19, using the PM2 timestamps exactly as recorded:

| Log time | Operation | Queue wait | Execution |
|---|---|---:|---:|
| 14:27:49 | saveAccountStates | 0 ms | 4,837 ms |
| 14:27:53 | saveAccountStates | 760 ms | 4,151 ms |
| 14:27:53 | mirrorPlayerWorld | 4,503 ms | 2 ms |
| 14:28:47 | saveAccountStates | 0 ms | 5,085 ms |
| 14:28:47 | mirrorPlayerWorld | 4,782 ms | 2 ms |

At 06:02:36 the same log also records a 4,265 ms account save, a 2,508 ms world save, and a 2,351 ms player save. These are correlated slow writes; the old instrumentation cannot separate PostgreSQL pool waits from row locks and query execution. It would be inaccurate to call all of that time a frozen Node event loop.

The source explains the unnecessary work: last-seen/login/join-related changes called `queueAccountsSave()`, and `saveAccounts()` passed the complete account collection to `saveAccountStates()`. That method sequentially upserts every account in one transaction. The new path names changed accounts, deduplicates keys, and preserves edits arriving during an in-flight save. A 5,000-account fixture now performs **one account upsert for one changed account**, versus 5,000 before. This is an upsert-count measurement, not a claimed 5,000-fold latency improvement.

Production evidence: [production-spikes.json](D:/Pixelmania/performance-20260919/production-spikes.json). These logs precede the newly added detailed profiler and are not tied to a user's client frame capture.

Two other lag mechanisms were reproduced independently: a durable action holding its player's ordered handler queue, and an ordered receive stall delaying all subsequent traffic on a connection. Bandwidth and client CPU improvements reduce pressure on those paths; they do not remove TCP ordering or the need to commit durable changes.

## 3. Movement latency findings

Flow: input → local fixed-step movement/`move_and_slide` → physics/collision → post-physics send sampling → WebSocket → per-socket queue → server validation/collision → authoritative position → interested receivers → snapshot decoding → sequence checks/interpolation → remote presentation.

Local movement already runs before a server response. That behavior, sequence rejection, transition ordering barriers, speed/reach validation, interpolation, and correction thresholds were preserved. The test mover follows a small valid path; zero corrections in this fixture does not prove every corner, teleport, or terrain combination is correction-free. The separate corner-contact and reconciliation regressions also pass.

**Queue diagnostic correction:** movement coalescing updates an envelope's enqueue timestamp to the newest position. The old queue timer therefore understates how long the queue slot has been blocked. A new `queue_slot_ms:*` metric retains the original timestamp without changing scheduling or which movement snapshot wins.

With a test-only 300 ms wait at the inventory commit boundary:

- Latest movement-envelope wait: maximum **64 ms**.
- Actual queue-slot wait: maximum **312 ms**.
- Observed remote movement gaps: up to **372 ms**.
- Event-loop probe delay: maximum **20.91 ms**.

This reproduces action-related movement stalls while the event loop remains responsive. Splitting movement into an independent mutation queue was deliberately avoided: changing an actor's position during an awaited action could invalidate reach/order assumptions.

## 4. Breaking latency findings

Flow: target/reach checks → elapsed-time hit cadence and local cracks → request-specific pending guard → server validation/cell lock → hit/removal and drops → durable world/inventory work as required → authoritative broadcast → client cell and collision update.

The existing pending-break guard and reconciliation path remain. Real WebSocket tests replayed requests and attempted rival breaks, then checked all relevant observers for absent blocks and unchanged drop identities/inventory. Delayed observers are synchronized before measuring duplicates; an early harness check incorrectly counted the original delayed drop as a duplicate and was corrected.

At 50 players, individual final-break request/response samples ranged from 6.45 ms at configured 0 ms RTT to 243.93 ms at 250 ms RTT. These are five samples across different RTTs, **not statistically meaningful latency percentiles**. They exclude the intentional multi-hit break duration and GPU presentation. Existing break traces now include UTC epoch timestamps for correlation.

## 5. Placement latency findings

Flow: input/target → eligibility and quantity reservation → local visual/collision prediction where permitted → request → server validation and mutation → durable inventory/world commit → authoritative result/delta → confirmation or rollback.

At 50 players, observed place request/response samples for configured RTTs 0/30/75/150/250 ms were **45.41 / 63.37 / 118.80 / 143.22 / 329.49 ms**. Timer granularity, jitter, scheduling, and batching are included. Local prediction is separate from these round trips.

New `place_prediction_cpu_ms` measures entry into prediction through local node/cell creation. It is not hardware input-to-photon latency. Rejected predictions, stale confirmations, inventory reservations, and world re-entry reconciliation remain covered by tests.

## 6. Planting latency findings

Seeds add configured growth deadlines, stable tree identity, a cell lock, inventory consumption, and an atomic world transaction. They use a separate visual-only preview; the preview cannot create authoritative growth state or grant inventory.

The headless seed regression created the preview in 0.089 ms and successfully delayed confirmation by 200 ms. That timing describes CPU/node creation, not a displayed phone frame. The 60-player network test confirmed planting to all 50 relevant peers, with plant responses of 8.10, 29.89, and 30.35 ms for its zero-RTT actor.

Three-hit immature destruction, visible cracking, stage changes, damage decay, replant identity, spoofed maturity rejection, and **no seed/drop refund for destroyed growing trees** all pass. Earlier one-splice and growth scheduling protections were retained.

## 7. Server tick findings

The service is event-driven. The `/health` value near one tick per second is a **one-second scheduling probe**, not a 1 Hz game simulation. Movement and action handlers run on incoming messages; movement/world batches have separate timers.

The earlier live health capture had zero players, healthy PostgreSQL/Redis, empty queues, and maximum loop-probe delays of 2.37/1.57/3.26 ms across the three processes. It cannot explain busy-server lag.

The opt-in profiler now has a 100 ms event-loop probe, monotonic and UTC timestamps, process CPU and memory samples, actual-window traffic rates, bounded latency histograms, and capped spike logging. Measured 50-player runs had loop-probe maxima around 25–30 ms; no 100–500 ms global CPU stall was reproduced in that local fixture.

## 8. Network findings

All messages below currently use **reliable, ordered WebSocket/TCP**. Sizes are observed JSON bytes in the 50-player fixture, excluding TCP/TLS overhead. Unexercised gameplay messages are labeled rather than assigned invented sizes.

| Message | Direction / frequency | Observed bytes | Purpose |
|---|---|---:|---|
| player_position | Client → server; 20 Hz in harness, adaptive in game | mean 273 | Position, velocity, facing, sequence |
| player_position_batch | Server → interested clients; nominal 16 ms batch window | mean 14,937, max 18,879 with columns | Complete nearby-player snapshots |
| player_position / player_joined | Server → relevant clients on presence/join | about 992 / 991 | Initial presence and compatibility |
| world_block_update request | Client → server on place/hit | mean 189 | Validated action request |
| world_block_update response | Server → actor; observers may be batched | mean 553 | Committed place/hit/removal |
| world_block_reconcile | Server → requester on conflict/replay | mean 1,790 | Authoritative repair, including player state where needed |
| inventory_transaction_request | Client → server on seed action in fixture | mean 211 | Authoritative inventory/world transaction |
| inventory_transaction_result | Server → requester | mean 348 | Result/delta; durable boundary retained |
| world_seed_update | Server → relevant world clients | mean 247 individually | Tree creation, hits, removal |
| world_update_batch | Server → world clients; nominal 16 ms window | mean 502 in this fixture | Coalesced world event delivery |
| player_state | Server → owner on request/resync | mean 1,772 | Full authoritative owner state |
| world_state_stream_begin/chunk/end | Server → joining client | mean 1,898 / 17,850 / 258; chunk max 37,224 | Join snapshot stream |
| drop_spawned | Server → interested clients on drop creation | mean 255 | Authoritative drop identity and quantity |
| world_population_update | Server → world on join/leave | 305 | World population |
| chat | Server → recipients; join notices in fixture | 117 for those notices | Chat/presence text; longer messages vary |
| client_ping / client_pong | Client ↔ server; profiler ping every 5 s | 103 / 55 in fixture | Application round trip |
| Machine/entity actions | Event/timer driven, relevant world recipients | Not separately sampled | Devices, animals, fishing, special interactions |

Legacy recipients still receive `players`. New clients advertise `movement_batch_format: columns_v1`; new servers share field names once and send complete value rows. Unknown/mixed schemas fall back to the legacy form. There is no retained delta baseline, quantization, or loss of numeric precision. Old servers ignore the capability and continue sending the old form.

## 9. Reliable/ordered message findings

Movement, chat, inventory, world snapshots, and edits share a connection. A queued large message or TCP recovery stall can delay later messages. Movement backpressure already keeps the newest complete snapshot; authoritative world/inventory messages cannot be silently dropped.

A controlled test held ordered delivery for 300 ms every 100 received packets, retaining all messages and their order. Ten clients encountered 100 such stalls in total. Remote movement gaps reached **419 ms**, although server movement queue waits peaked at **7 ms** and loop delay at **11.31 ms**. Block/seed/drop/inventory invariants survived and queues drained to zero.

This models the ordered recovery delay associated with loss; **kernel-level packet loss, TCP retransmission, cellular bandwidth limits, and real phone networks were not measured**. A new transport/channel architecture would require its own authority, ordering, and compatibility design.

## 10. Chunk/render findings

Ordinary tile edits already update the affected cells. A boundary fixture changed cells around x=15/16 and verified **zero whole-chunk rebuilds for eight normal edits**. Bulk dirty marks are deduplicated by chunk. Collision overlay rebuilding on the server was the separate avoidable whole-map operation fixed here.

Chunk activation/rebuilds still cost work proportional to cells/layers. The implementation limits the number of dirty chunks processed per frame; it does not guarantee a strict wall-clock budget for every rebuild. Existing chunk metrics plus new world/drop/remote-visual spans help identify an expensive real scene before changing that scheduling.

Headless tests do not measure real GPU rendering, texture upload stalls, overdraw, or phone thermals. No renderer rewrite or lighting change was made.

## 11. Collision findings

The old path invalidated the complete foreground map after place/break, and even after foreground hit broadcasts. The next movement validation rebuilt all generated terrain plus explicit edits/removals.

For a 7,000-cell synthetic map, 120 alternating edits using the actual cache functions:

| Measurement | Before | After |
|---|---:|---:|
| Full overlay rebuilds | 120 | 0 |
| Mean CPU per edit + query | 1.1365 ms | 0.0030 ms |
| p95 CPU | 2.0139 ms | 0.0048 ms |
| Maximum | 2.9825 ms | 0.0194 ms |

The new cache reads the current authoritative cell after mutation. Hits/background edits do not invalidate foreground collision. Cold caches remain lazy; bulk restore/generation changes still invalidate. Restoration that exposes generated terrain falls back to the canonical rebuild. Neighbor cells, other worlds, rollback, tombstones, and restoration are checked.

20,000/50,000-cell benchmark cases are extrapolations beyond the ordinary 100×70 world, not claims about current production world sizes.

## 12. Database/persistence findings

**Implemented:** changed-account batching, full recovery backup retained, failed writes retained/retried, explicit full-save fallback retained, no deletion of edits added during an in-flight write. Authentication/password/session durable saves still follow their existing authoritative paths. Friend changes include both account records in the same snapshot transaction.

**Instrumented:** write-queue wait, pool acquisition, transaction execution, and labeled write time. These separate asynchronous waiting from Node CPU work. Existing inventory-lock and world/inventory persistence spans now carry request/world correlation.

World economic commits still wait for PostgreSQL. Inventory, drops, world state, item instances, ledgers, ownership fencing, and revisions must remain atomic. Confirming success before commit would trade latency for duplication/data-loss risk and was not done.

A CPU-only fixture with 7,000 explicit cells measured median 3.97 ms to assemble/deep-clone a snapshot and another 1.03 ms to JSON-encode it. This excludes database/IO and ancillary world components. Whole-world snapshot work remains a scaling cost, but it does not alone establish a 300 ms production CPU stall.

Actual production improvements to account-save latency still require a deployed before/after capture. The observed seconds-long production timings must not be substituted with the much smaller local CPU-only figures.

## 13. Inventory findings

Inventory commits build validated deltas and retain locks/ledger/instance checks. Some transactions still inspect the full inventory and serialize full world state; reconciliation can include a full owner state. These are potential costs at large inventory/world sizes, now separable from DB waits.

The client incremental inventory-refresh regression passes. Replay tests preserve authoritative quantities, and changing movement encoding does not touch inventory messages. No optimistic inventory grants, weakened cooldowns, or bypassed durable commits were introduced.

## 14. GC/allocation findings

Measured client waste was repeated dictionary normalization, key sorting, and string concatenation for unchanged remote equipment. Reusing the packet-time key reduced that path by about **91%** in the 50-node microbenchmark. Equip/unequip, facing changes, and legacy metadata fallback remain tested.

The validated movement decoder reduced Godot parse-plus-decode median from **0.23849 to 0.19459 ms** for a captured ten-player batch, while wire size fell **7,950 → 4,228 bytes**. Node encoding/decoding microtests have additional row-construction work; this is not a claim of universally lower server CPU. The benefit is substantially lower bandwidth and lower measured Godot decoding time.

Node GC was sampled with `PerformanceObserver`; 50-player run maxima were about 4 ms. No evidence from these short tests justifies blaming a 500 ms incident on GC. GDScript object/static-memory/node counters are memory-pressure proxies, not precise allocation counts or managed-GC pause measurements. Profiling buckets, counters, pending operations, and spike volume are bounded.

## 15. Mobile-specific findings

At simulated 30, 45, and 60 FPS, a 30-second hold produced identical counts: **100 punch repeats and 187 placement repeats**. Additional 15/144 FPS cases and a five-second stall confirmed the prior bounded carry/no-catch-up-burst behavior. Touch cancellation, simultaneous movement/punch ownership, inventory layout, reach, and zoom tests pass.

The reduced movement decode cost and remote equipment CPU apply to mobile code paths, but no physical phone was connected for GPU, thermal, memory-pressure, or radio testing. There is no claim of a measured phone FPS increase. Input-to-display latency and gameplay with a busy UI/particles on a low-end phone remain device-validation tasks.

## 16. Tree-growth findings

The server derives maturity from authoritative timestamps; it does not schedule an independent timer per growing tree. The client already budgets ordinary growing-tree visual work to 64 entries/about 1 ms per frame. That earlier optimization was preserved.

Special animated mature trees and their rendering still have per-frame work. Large mixed scenes of mutated trees, drops, particles, and open UI were not physically profiled. Growth identity, delayed confirmations, three-hit damage, mature/immature distinctions, replant races, and no immature refunds were regression-tested.

## 17. Files/functions changed

Paths below are relative to the client or server repository.

| Repository / file | Changes |
|---|---|
| Server `src/server.ts` | `queueAccountsSave`, `saveAccounts`, caller keys; per-cell collision cache; capability negotiation; queue-slot, loop, CPU/rate and correlated persistence telemetry |
| Server `src/server_account_auth_routes.ts` | Name the account changed by registration/authentication recovery |
| Server `src/server_account_session_helpers.ts` | Name the account changed by verification/password/email/session fallback |
| Server `src/server_friend_routes.ts` | Name both affected accounts |
| Server `src/postgres_store.ts` | Optional queue/pool/transaction/write timings |
| Server `src/server_runtime_stats.ts` | Bounded, redacted spike logging and observer cleanup |
| Server `src/server_socket_delivery_helpers.ts` | Negotiated complete-row movement encoding, including backpressure flushes |
| Server generated counterparts | Rebuilt from the current TypeScript; concurrent quest changes preserved |
| Server `scripts/check_*`, `profile_*`, `runtime_network_stress.js`, `runtime_fault_preload.js` | Codec, profiler, account-save and collision checks; controlled load/fault fixtures |
| Server `package.json` | Add `check:runtime-audit` to the security gate |
| Client `Scripts/networking/movement_batch_codec.gd`, `Scripts/network_manager.gd` | Safe complete-row decoder, capability advertisement, existing world/self/stale filtering retained |
| Client `Scripts/player_manager.gd` | Reuse cached equipment key in `update_remote_shared_equipment_visuals` |
| Client `Scripts/runtime_profiler.gd` | Bounded metrics/counters, UTC spikes/rates, response correlation |
| Client `Scripts/block_manager.gd`, `Scripts/seed_system.gd`, `Scripts/world.gd` | Prediction CPU, world/drop/remote-visual spans; UTC action traces |
| Client tests/fixtures and `tools/run_runtime_regressions.cjs` | Codec/appearance checks, captured synthetic packet fixtures, 45 FPS case, current fishing/seed stub interfaces |

## 18. Exact optimizations made

1. Persist only named changed accounts in routine PostgreSQL snapshot saves; preserve full backups, atomic paired updates, retries, and the explicit full-save path.
2. Update one authoritative collision cache cell after a normal foreground edit; avoid invalidation for hits and background edits.
3. Share movement field names once per negotiated batch, preserving complete state and exact values. Legacy and heterogeneous batches fall back safely.
4. Skip repeated per-frame equipment normalization/key construction when the packet-time key and facing match the applied appearance.

Telemetry and test changes expose remaining stalls; they do not hide corrections or alter action rates.

## 19. Before/after measurements

| Controlled measurement | Before | After |
|---|---:|---:|
| Account upserts for one changed account among 5,000 | 5,000 | 1 |
| Collision CPU/edit, 7,000 cells, mean | 1.1365 ms | 0.0030 ms |
| Stable equipment CPU/frame, 50 nodes, median | 0.716 ms | 0.061 ms |
| Ten-player packet JSON bytes | 7,950 | 4,228 |
| Godot parse + validated decode, median | 0.23849 ms | 0.19459 ms |
| 50-player aggregate movement traffic | 32.85 MB/s | 16.02 MB/s |

Evidence: [collision before](D:/Pixelmania/performance-20260919/collision-matched-before.json), [collision after](D:/Pixelmania/performance-20260919/collision-matched-after.json), [equipment before](D:/Pixelmania/performance-20260919/equipment-before/remote_equipment_performance_test.log), [equipment after](D:/Pixelmania/performance-20260919/equipment-after/remote_equipment_performance_test.log), [decoder](D:/Pixelmania/performance-20260919/encoding-final/movement_encoding_probe.log), [account correctness](D:/Pixelmania/performance-20260919/integrated-audit-checks-final.log).

## 20. Performance with multiple players

| Players | Topology | Legacy movement MB/s | Columns movement MB/s | Corrections |
|---:|---|---:|---:|---:|
| 1 | One world | Not applicable: no remote players | 0 | 0 |
| 5 | One crowded world | 0.26 | 0.22 | 0 |
| 10 | One crowded world | 1.14 | 0.69 | 0 |
| 25 | One crowded world | 7.42 | 3.88 | 0 |
| 50 | One crowded world | 32.85 | 16.02 | 0 |
| 60 | Two worlds: 50 + 10 | Not rerun | 16.58 | 0 |

Traffic is aggregate server-to-client JSON bytes, not per-client bandwidth. At 50 players, bytes per replicated movement item fell from about 792.5 to 387.8. The change does not remove crowded-world **O(players²)** fanout. The 60-player test verified edits did not leak into the unrelated world.

Interest management exists for players/actions/drops with distance hysteresis and world membership. The observed 2,560 px entry radius is broad relative to a 3,200 px-wide world, so many players still see one another. Reducing that radius without verifying camera/zoom visibility could make players pop out; it was not changed speculatively. World tile edits still reach world residents because clients maintain world state beyond the current screen.

All matched runs, the 60-player run, both final delay tests, and the integrated ten-player smoke test finished with zero inbound pending messages and passed inventory/drop/seed convergence checks.

## 21. Remaining bottlenecks and validation limits

- Production database waits still need query/lock/pool attribution after deployment. The new timers expose those stages; this audit did not run destructive or load-generating DB experiments on production.
- Durable actions still hold their socket's ordered handler chain. Commit guarantees take priority over acknowledging uncommitted inventory/world changes.
- Crowded-world replication remains quadratic and shares TCP ordering with snapshots/inventory/chat. Even the smaller 50-player stream averages roughly 0.32 MB/s per receiver in this workload.
- Full world serialization and complete recovery-file JSON encoding remain synchronous CPU work before asynchronous IO. Dirty account batching removes unrelated DB upserts, not every serialization cost.
- Chunk activation, drops, animated trees, equipment effects, particles, GPU work, and inventory/UI interaction can combine on a phone. A physical-device capture is still required.
- Fault tests model ordered stalls and application jitter. They do not constitute actual packet-loss, bandwidth shaping, long-duration soak, or thermal testing.
- These were short scripted movement/action runs, not a full production workload or exhaustive testing of every simultaneous same/different-chunk interaction. Existing cell-lock, rollback, world revision, replay and anti-dupe suites provide additional correctness coverage.
- Editor import still reports an existing archived `Backups/inventory_manager_claude_code_before_codex_fix_20260530.gd` reference to `PANEL_DARKERER`. Runtime audit scripts and the 24 executed client regressions have no parse failures. The archival script was not modified as part of this audit.

## 22. Validation and next steps

**Passed:** 24 client regressions; all 27 existing top-level backend security gates (including their nested TypeScript, persistence, movement, seed, quest, rollback and anti-dupe checks); the new runtime-audit gate; final real-WebSocket integrated smoke test. An initial quest fixture failure occurred during concurrent quest work; the subsequent full set of gate commands and an explicit quest recheck both pass. No gate was removed or weakened.

Validation records: [security results](D:/Pixelmania/performance-20260919/security-remainder-results.json), [audit-specific checks](D:/Pixelmania/performance-20260919/integrated-audit-checks-final.log), [client logs](D:/Pixelmania/performance-20260919/integrated-client), [two fixture rechecks](D:/Pixelmania/performance-20260919/integrated-client-recheck), [integrated network result](D:/Pixelmania/performance-20260919/integrated-smoke/results.json).

After reviewing and releasing the changes, collect a short, correlated busy-world capture:

1. Enable `PIXELMANIA_RUNTIME_PROFILE=1` on the relevant server process and client, or client `--runtime-profile`. Profiling is off by default. Client/Node histograms are capped at 128 metrics and 512 samples; abnormal-event logging is capped at eight events per five seconds.
2. Use UTC timestamps and request IDs to align client frame/dispatch/prediction times with server queue-slot/latest-message waits, inventory locks, DB queue/pool/transaction times, GC and world snapshot work. Client display latency is not interchangeable with round-trip or handler time.
3. Use bounded `--pm-place-trace`/`PIXELMANIA_PLACE_TRACE` for a specific placement sequence and `PIXELMANIA_BREAK_TRACE=1` for a short break capture. Avoid leaving verbose action traces enabled indefinitely.
4. Compare account-save rows, queue waits and pool/transaction timings against the September 19 log evidence. Confirm the seconds-long whole-account snapshots disappear from ordinary activity; do not infer it solely from local tests.
5. Capture a lower-end Android/iPhone session at 30/45/60 FPS with nearby players, drops, trees, particles and open inventory, plus real bandwidth/loss conditions. Use the new subsystem spans to select the next measured optimization.

Reproduction commands and fixtures live in the repositories: `npm run check:runtime-audit`, `scripts/runtime_network_stress.js`, `scripts/profile_persistence_cpu.js`, and `node tools/run_runtime_regressions.cjs` with `GODOT_BIN` set. Network fault injection is only installed explicitly by the isolated development harness; production server code never enables it.

**Release state:** saved locally and validated. No audit commit, production deployment, phone build, or store publication was performed in this audit turn.
