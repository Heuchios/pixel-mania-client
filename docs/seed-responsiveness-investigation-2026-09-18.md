# Seed responsiveness and growing-tree fixes

## 1. Causes of remaining intermittent lag

The client scanned every planted tree every 250 ms and rebuilt all trees whose visual stages changed in that pass. A Godot benchmark using the actual seed-system code reproduced a 90.23 ms synchronized stage-change burst with 3,000 trees. Ordinary growth passes took 9.01 ms at the median. Tree hit/hover lookup also scanned every tree, costing about 0.565 ms per lookup at 3,000 trees.

Seed place/splice/harvest serialized the full world before calling the inventory commit helper, which serialized it again for the authoritative transaction. The redundant caller snapshot has been removed. The remaining snapshot, PostgreSQL transaction, world journal and inventory ledger are preserved.

The previous movement coalescing, ordered socket processing, block prediction/reconciliation, event queue budgets and incremental tile renderer remain in place.

## 2. Cause of planting delay

Previously the client sent the seed transaction and rendered nothing until the committed server world update arrived. Therefore a slow inventory/world commit or an earlier request in the ordered socket queue delayed the first visible feedback by the same amount. A controlled 150 ms commit barrier reproduced that relationship: there was no authoritative broadcast before commit completion.

Current pipeline: input -> send one request with ID -> immediate visual preview/pending cell -> server cell lock -> permission/reach/item/inventory/tile validation -> server-owned tree creation -> one atomic world/inventory commit -> broadcast and inventory delta -> reconcile preview.

This establishes the mechanism, but not the exact origin of a particular production multi-second incident. The production workers were essentially idle during observation: no movement samples, at most six inbound messages, queue wait at most 1 ms, no queued saves, and maximum sampled event-loop lag 2.30–2.99 ms. That sample cannot diagnose lag under active production load.

## 3. Why growing trees lacked breaking feedback

The input path called the tree harvest handler directly, bypassing normal block hit progress and crack overlays. Local removal feedback was only applied to mature trees. The server counted immature-tree punches privately and did not broadcast intermediate damage.

Growing trees now use the existing block crack stages, textures, overlay factory, hit cadence and damage-recovery maps. Stage transitions rebuild the tree sprite and restore its crack overlay. Server hit updates make the same damage visible to other players. Damage expires using the server reset interval; confirmed removal clears damage and pending rollback state.

## 4. Where the seed refunds occurred

Both `handleSeedHarvestTransaction` in the server and `harvest_planted_seed` in the client seed system had an immature-tree branch that generated one seed. Both branches are removed. Mature configured drops, fallback drops and mutation rewards retain their existing reward code.

## 5. Changed files and functions

Client:

- `Scripts/world.gd`: request IDs and pending quantities in `request_server_seed_place`; visual preview and rejection cleanup; `harvest_planted_seed`/`apply_seed_break_feedback`; rollback identity checks; seed profiling.
- `Scripts/seed_system.gd`: preview lifecycle, shared growth deadlines, bounded growing-tree work, nearby-cell hit/hover queries, no immature refund, no redundant unchanged mutation rebuild.
- `Scripts/block_manager.gd`: tree support in the existing crack/recovery path.
- `Scripts/world_state_sync_manager.gd`: tree hit events, duplicate confirmation handling, instance identity, speedup reconciliation and stale-removal protection.
- `Scripts/runtime_profiler.gd`: seed request-to-response timings.
- `tests/seed_prediction_test.gd`, its world fixture, `seed_growth_profile.gd`, and the updated `growing_tree_break_hits_test.gd`.

Server:

- `src/server.ts`: seed cell locks; authoritative no-refund destruction; hit broadcasts and expiry; permission rejection replies; tree identity; block-handler guard against tree reward bypass; one snapshot per seed commit; queue/lock/commit/persistence timings.
- `src/server_phase8_world_action_routes.ts`: legacy seed placement delegates to the canonical transaction; client remove/mature/splice world updates are rejected.
- `src/server_world_state_helpers.ts`: persist stable tree identity and preserve multi-day growth durations. Saved trees previously had a one-day duration cap on load.
- `types/pixelmania-contracts.d.ts`: explicit world-mutation commit option.
- Generated JavaScript counterparts, `scripts/check_seed_transactions.js`, expanded `runtime_network_stress.js`, and persistence regression assertions.

## 6. How planting responsiveness improved

Prediction extends the existing pending seed placement/reconciliation map. A stage-zero sprite appears immediately after a successful network send. It is separate from authoritative planted trees: it has no growth state, drops or inventory mutation. Pending quantities prevent repeated local sends beyond the known inventory count. Rejection, timeout, leaving the world and authoritative confirmation remove previews. Replies are matched by request ID and world; an old rejection cannot remove a newer prediction.

The Godot fixture measured 0.074 ms to create the preview and verified it stayed present throughout a simulated 200 ms confirmation delay. This is CPU-side headless timing, not a physical phone display-latency measurement.

## 7. Growing versus mature state

- Seed item: owned in authoritative inventory before planting.
- Growing tree: server time has not reached `planted_at + max_grow_time`; requires three punches; destruction produces no rewards.
- Mature tree: server-calculated remaining duration is zero; uses existing mature harvesting rules.

Client growth deadlines estimate display state. They do not authorize rewards. Server-created `tree_created_at` identifies an instance even when a growth-speedup changes `planted_at`; this prevents delayed hits/removals affecting a replacement tree.

## 8. Server enforcement

The server ignores client-provided maturity, planting time and duration. Destruction computes maturity from server state before constructing rewards. Immature rewards remain empty, with no seed delta or dropped item. Foreground block hit/break requests on a tree are rejected before generic block damage/drop processing. Legacy direct seed destruction is rejected. Seed actions share the foreground cell lock through validation, commit and rollback, so competing edits cannot destroy the same tree twice.

Authoritative confirmations still wait for durable success. Failed commits restore the tree or remove an uncommitted planting. Inventory and world changes remain in the same PostgreSQL transaction.

## 9. Tree-growth performance

The server already calculated growth from timestamps and has no per-tree growth timer; that design is retained. The client now processes at most 64 growing trees or roughly 1 ms of growth work per frame, rebuilding only changed visual stages. Ordinary mature trees leave this queue. Growth time advances independently of when a visual rebuild runs. Large synchronized transitions are spread across frames, so distant visual stages can catch up over subsequent frames rather than all changing in one burst.

| Actual Godot seed-system benchmark | Before | After |
| --- | ---: | ---: |
| 3,000 trees: median growth pass | 9.01 ms | 0.212 ms |
| 3,000 trees: synchronized stage work | 90.23 ms in one pass | 1.145 ms maximum measured update frame |
| 3,000 trees: hover lookup | 0.565 ms | 0.00191 ms |
| 500 trees: synchronized stage work | 16.82 ms | 1.17 ms maximum measured update frame |

The benchmark drains the entire work queue and asserts every tree reaches the expected stage and maturity. It does not measure GPU rendering, physical mobile frame rate, or many animated mature mutant trees.

## 10. Remaining bottlenecks and measurement limits

Full-world persistence and PostgreSQL row/ownership locking remain necessary costs in the existing design. Slow commits can still delay authoritative confirmation and later messages on that socket. Moving mature mutant animations, GPU draw cost and real phone thermal/frame stalls need device measurements. No networking rates, reliability settings or gameplay authority were loosened.

Enable the existing opt-in profiler with `PIXELMANIA_RUNTIME_PROFILE=1` on a diagnostic server/client or `--runtime-profile` on the client. Added metrics include `seed_queue_ms:<action>`, `seed_cell_lock_ms`, `seed_commit_ms:<action>`, `seed_action_ms:<action>`, `inventory_lock_ms`, `inventory_world_persistence_ms`, client `seed_place_request_to_response_ms` and `seed_growth_ms`. Existing metrics cover JSON parsing, snapshot cloning, GC, frame time, chunk updates and queued packets. Logs contain aggregate timings, not packet bodies or credentials.

The isolated three-player WebSocket run used 30/75/150 ms application RTT with deterministic jitter and development storage. It observed seed queue wait 0 ms, maximum seed-place handler 3.89 ms, snapshot clone 0.512 ms, GC 4.04 ms, and movement queue wait at most 3 ms. Seed confirmation was 45–46 ms for the 30 ms RTT planting client; all three peers synchronized. This does not measure production PostgreSQL latency or TCP packet loss.

## 11. Tests and results

Passed:

- Immediate and halfway-grown destruction: three hits, zero drops, zero seed refunds.
- Mature configured and mutated rewards; forged client maturity/duration ignored.
- Ten rapid plant/break cycles: exact seed consumption, no refund.
- Delayed commit, two-player same-cell contention, rollback and lock release.
- Stale tree hit rejection; generic block and legacy seed packet bypass attempts rejected.
- Immediate client preview, duplicate pending-cell suppression, pending quantity reservations, wrong-world/stale rejection handling, duplicate confirmation, failed send, cleanup.
- Real client hold cadence, crack progression, stage-change preservation, damage expiry, remote hit updates, removal/replant and speedup reconciliation.
- Three real loopback WebSocket players: planting, shared hits, destruction fanout, no tree drops, inventory invariants, normal block edits and zero movement corrections.
- Existing movement regression (12 scenarios), drop pickup (14 checks), block commit race/reconciliation, renderer/rejoin checks, chunk performance, event-queue latency, synthetic mobile touch and punch reach, profiler checks.
- World persistence timestamp round trip, multi-day duration, revision/CAS/ownership fencing tests.
- TypeScript checks; server builds; anti-dupe, transaction-ledger, world-journal and validation checks; Godot parsing and diff formatting.

Lint reports zero errors and one existing unused-disable warning in `src/server_player_state_helpers.ts`.

Physical phone touch/hold testing and a production incident capture were not performed. Automated mobile input tests and simulated latency are covered; they are not substitutes for physical-device GPU/input testing. These new changes are saved in the working repositories; this investigation did not publish a new production build.
