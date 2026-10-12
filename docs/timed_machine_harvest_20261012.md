# Timed machine punch harvesting

Coloured Block Maker produces one coloured block after two hours. Punching a
ready machine drops one block: 1% RGB Block (`shifty_block`), otherwise a uniform
choice among 28 plain/pastel coloured blocks. Another two-hour cycle starts at
harvest. An unattended machine holds one ready output rather than accumulating
an unlimited backlog. No feeding or fuel is required.

Gem Driller produces collectible gem drops on punch harvest. The existing ATM
item sharing its atlas art also drops its output, preserving the existing
12-hour cycle and 1–100 gem amount. Harvest never changes the gem counter;
the normal server-authoritative pickup path credits gems and writes its ledgers.

Both use the existing `tackle_box_state` timed-provider protocol. Shared client
and server item overrides specify machine behavior and descriptions. Placement
starts a cooldown; previously placed machines without saved state start and
persist their first cycle when punched. Cooldown state and reward drops commit
together through PostgreSQL world state, object journals and drop records.
Harvest locks the provider and foreground tile, rechecks access after awaiting
locks, and rolls back output and cooldown when persistence fails.

Client timers use each item's name. Coloured Block Maker runs atlas cells
(12,16)/(13,16) while producing and uses (14,16) when ready. Gem Driller uses
(6,16) while producing and (5,16) when ready.

Verification: `scripts/test_timed_machine_harvest.js` runs shipped handlers with
a controlled clock, RNG and commit boundary. It covers the exact two-hour limit,
1% RGB boundaries, one output, offline ready state, reconnect/replay, simultaneous
punches, access/tile changes, first-cycle initialization, drop failure and SQL
failure rollback. `tests/timed_machine_harvest_test.gd` verifies matching client
cooldowns, provider recognition, artwork, running animation and ready cleanup.

## Verified staging release

Active release: `20261012-timed-machines`, backend
`865a59357bf57f438ad9843582f77f84c175ce97`, client metadata
`5d89706e454f6170d3131e8d1a68f30711ff982f`. Client version and minimum remain
1.2.25. The full security gate, farming balance check, machine server regression,
machine client regression, protected punch and authoritative placement checks pass.
The machine regression also passes against the deployed immutable server files.
Public deployment smoke checks pass, with PostgreSQL authoritative/ready and
Redis ready. Rollback points to `20261012-hair-odds-08f1942`.

The older `bait_box_visual_test.gd` has an existing hard-coded health assertion
of 4, while the already-committed balance override specifies 6. It fails that
assertion before testing visuals; no pass is claimed for that older suite.

This deployment targets staging only. Published client binaries were not replaced;
restart the updated Godot editor/debug client to use the new client visuals.
