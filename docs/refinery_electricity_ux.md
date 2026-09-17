# Refinery and electricity UX

## Controls

Equip the Electric Tool to show the wiring toolbar. The usual two-device tap
still connects devices. Tap the same source again, or **Done**, to exit.

- **Inspect**: tap a device to trace its circuit; tap a wire to select it.
- **Connect / Inspect**: explicit, mutually exclusive modes.
- **Show all / Focus circuit**: shown after selecting a device.
- **Keep connecting**: shown while linking a transformer; add several pads/poles.
- **Disconnect**: remove the selected connection after server confirmation.
- **Undo**: reverse the last confirmed edit, through normal server validation.

Disconnect and Undo are hidden until applicable. Done resets Keep connecting.
In Inspect mode, device clicks take priority over wire clicks at endpoints.

Selecting an already connected pair selects its wire. A refinery or charger
must have its current wire explicitly disconnected before linking a different
pole. Input/output limits and world/area permissions remain unchanged.

The toolbar reports pending saves and only enables Undo after confirmed state
arrives. An unconfirmed request times out after eight seconds without inventing
local success. Undo is cleared on a world change. Failed or stale operations
must be retried after inspecting current wiring.

## Feedback

Refineries distinguish switched off, disconnected, empty supply, starting,
running, battery backup and full output. The refinery panel gives the explanation;
Inspect shows the selected refinery's reason in the compact toolbar. Permanent
world warning badges and the grid of placement hints are hidden while wiring.

The next-oil meter shows progress toward one oil; the storage meter shows the
actual count divided by capacity. Battery reserve is an estimate for that
refinery alone at 100 energy/hour. Network energy is shared, so it is not
presented as a per-refinery runtime guarantee.

Only the target under the pointer and the endpoints of a selected wire receive
selection markers.
Generation shows a short `+energy` label; a full transformer shows `Storage full`.

### Directional flow overlay

Moving chevrons indicate an active supply route: pad to transformer on a
generation event, then transformer through poles toward a running consumer.
Battery-only refineries do not animate their grid input. Faint stationary
chevrons show the fixed direction of inactive input/output connections.

The server does not measure current on individual pole couplings. For multiple
feeds or loops, the overlay illustrates a shortest route from every charged
transformer output toward a running consumer. A nearer source no longer hides
other shared supplies. These arrows show supply availability, not exact wire
currents or simultaneous debits. Unused loop edges have no directional marks.
The server pools all reachable transformer stores for consumers; it does not
transfer stored energy between transformers. Small integer withdrawals can
come from the fullest store first.

The overlay uses one Node2D and two batched line draws. It updates animation at
30 Hz, draws at most 64 visible wires with two chevrons each, and skips dimmed
and offscreen connections. Selected and active wires get priority. Topology
rebuilds process 128 edges per frame; machine activity is checked at 2.5 Hz.
Topology and routes are reused until their inputs change. No particle nodes,
world-tile enumeration or general block-area queries are involved.

Wire caches retain coordinates and instance IDs, not Node references. A network
revision invalidates markers immediately, ahead of periodic visibility refresh.
Live wire entries are checked for validity and pending deletion before typed
assignment; a same-key replacement must match the cached instance ID.

## Selection performance correction

The initial overlay scanned visible cells every 150 ms. Its generic block-area
lookup could then scan all foreground blocks for every empty cell. Electrical
picking now uses direct dictionary lookups and a bounded nearby-transformer
footprint check. It never calls the general world-area search. The existing
preview resolves one pointer target; there is no viewport candidate enumeration.

Connection graphs rebuild on link changes. Focus traversals and line styling
run on selection/topology changes, not unchanged refreshes. Overlay drawing is
limited to one target, one selected wire, and bounded temporary generation text.
Idle selection frames do not request redraws. The separate bounded flow layer
animates only when an active route is visible. Wire picking follows the
mouse/touch pointer.

## Implementation and release

Internal `watts` fields and all production/storage rates are unchanged; UI copy
uses Energy. The backend extends the existing link requests with a boolean
`disconnect`, using the same authorization, persistence and rollback paths.
Deploy the updated server before distributing the client: older servers do not
understand the disconnect field. No server has been deployed by this change.

## Validation

- `tests/refinery_ux_test.gd`: status, storage/progress, link-key round trips,
  upstream supply highlighting, multi-connect across snapshots, and no Undo
  before confirmation. Also checks no world-area lookups with 30,000 blocks,
  no candidate enumeration, and graph reuse over 1,000 refreshes of 1,500 wires.
- `tests/refinery_ux_render.gd`: renders the actual refinery scene into
  `tmp/refinery_ux_preview.png` for visual inspection.
- `tests/electric_flow_test.gd`: checks forward/reverse pole routes, pad pulses,
  battery-only and stopped consumers, the 64-wire draw budget, offscreen
  culling, incremental rebuilds and cached state checks with 1,500 active wires.
  Also reproduces freed/queued wire references, same-key replacement and a new
  snapshot arriving during an unfinished rebuild.
  Local headless measurements: approximately 0.08 ms per animation update,
  2 ms per state check, and 5.4 ms worst rebuild step. These are isolated CPU
  checks, not a guarantee of full-game FPS on every device.
- Server: `scripts/check_electrical_disconnect.js` verifies remove/reconnect,
  tool permissions, commit-before-broadcast and rollback for all three pole/
  transformer link routes.
- Server TypeScript builds and the existing phase-8 route checks also run.
