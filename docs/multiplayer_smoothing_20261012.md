# Multiplayer smoothing — 2026-10-12

Implemented locally in the client and adjacent `PixelManiaServer` checkout.
No deployment, client release, database migration, or gameplay balance change.

## Changes

- Pickup queue drains scan all drops once, then operate on a temporary list of
  pending pickups. The list exists only during the synchronous drain, so network
  replies, removal, retries, and world switches cannot leave a persistent cache
  stale. Same-tile batching, ordering, send tokens, the in-flight cap, cancellation,
  and failure behavior are retained.
- Pickup request counts are computed only on pickup scan frames. Ordinary drop
  sprites skip repeated colour-cycle node lookups; animated colour-cycle drops
  continue updating normally, including the uncached fallback.
- Inventory drawer movement no longer runs layout twice in a frame. Internal
  panel layout is reused until viewport dimensions or slot columns change. Drawer
  transforms, item updates, selection, and resize/rotation still update normally.
- Read-only placement and break-target overlap queries iterate the block dictionary
  directly rather than allocating an array containing every world coordinate.
- Congested server movement queues copy only the entries for the next packet.
  Packet order, batch limits, latest-state coalescing, departure messages, and
  stopping when backpressure returns are preserved. Generated JavaScript was rebuilt.

Movement physics, reach, cooldowns, pickup rates, stack sizes, item amounts,
drop probabilities, authoritative inventory transactions, and anti-dupe checks
are unchanged. No authoritative packets are discarded by these changes.

## Measured work

Synthetic local headless probes; these are not device FPS or production latency
measurements. Timings vary with machine load.

| Probe | Before | After |
| --- | --- | --- |
| Drain four pickups among 10,009 drops | 33.9 ms; 9 additional full-world count scans | 5.7–8.0 ms; 0 additional count scans |
| 120 inventory layout calls, 640×360 | 16–19 ms of repeated layout | 0.024–0.067 ms with layout reuse |
| Drain 2,131 queued movement/departure entries into 126 packets | 134,631 entries traversed | 2,131 entries traversed |

The pickup baseline used the committed pre-change drop manager with the same
fixture. The movement baseline used the committed pre-change delivery helper
with the same ordering/backpressure assertions. Inventory comparison explicitly
invalidated layout reuse for the repeated-layout path.

## Verification

- All 30 checks in `node scripts/check_network_audit.js` passed, including
  placement, breaking, inventory interaction, movement, world entry, reconnect,
  validation, anti-dupe protection, and 39 movement rollback scenarios.
- All 60 simulated network combinations passed: 0–250 ms RTT, 0–5% missing
  snapshots, 30/60/144 FPS, and ordered delivery stalls. This models application
  delivery, not kernel TCP packet loss.
- 20 focused client tests passed, covering pickup recipients and HUD flights,
  drop visibility/counters, inventory actions/layout/refresh, placement
  reconciliation, multi-hit breaking, chunk edits, event-queue latency,
  networking, remote equipment, and the new hot-path regression.
- Server socket delivery, column encoding, drop capacity/item-loss,
  validation, anti-dupe, and rate-limit checks passed.
- Actual two-client local smoke passed at 250 ms simulated RTT with delivery
  recovery stalls, a 30 FPS observer, and a forced disconnect/reconnect.
  Local movement began before the round trip; placement charged once; multi-hit
  breaking rendered; inventory quantities survived display deposits/withdrawals
  with the bag both open and closed; reconnect retained the correct quantities.
  Zero movement corrections and no duplicate remote player were observed.

The smoke fixture now uses the valid alphanumeric world name `NETWORKAUDIT`;
its previous underscore caused current world-name validation to reject entry.
An existing HUD test needs loading after autoload initialization when run with
this engine's `--script` mode; it passed through a temporary runtime bootstrap.
Tests that write `user://` used an isolated writable APPDATA directory.

## Reproduction and evidence

- Client: run Godot headless with `--path . --script
  res://tests/multiplayer_hot_path_test.gd -- --pixelmania-ws-url ws://127.0.0.1:1`.
- Server: `npm run check:server-socket-delivery-helpers` includes the new
  deterministic movement queue regression; `node scripts/check_network_audit.js`
  runs the broader audit.
- Two clients: run `node scripts/network_game_smoke.js` with a fresh
  `AUDIT_OUTPUT_DIR`, `AUDIT_RTT_MS=250`, and `AUDIT_RECOVERY_PERCENT=3`.
- Local before/after logs: `D:/Pixelmania/work/multiplayer-before-engine.log`
  and `D:/Pixelmania/work/multiplayer-multiplayer_hot_path_test.log`.
- Successful smoke results: `D:/Pixelmania/work/multiplayer-smoothing-game-20261012-valid-world/`.
- Audit results: `D:/Pixelmania/PixelMania/PixelManiaServer/test-output/network-checks-1791787666780/results.json`.

Physical Android devices, production PostgreSQL/Redis load, and rendered device
frame rates were not measured. The local smoke uses isolated development data.
