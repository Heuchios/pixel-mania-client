# Special item break recovery

Snow Repellent, Vending Machine, Magnet Machine, World Lock, Anti Gravity,
Anti Talk, Anti Punch, CCTV and every theme machine return exactly one item
directly to inventory when broken. They produce no break seeds, gems or world
item drops. Existing ownership, vending contents, magnet contents and inventory
capacity checks still run through the normal authoritative break transaction.

Snow Repellent and CCTV were incorrectly marked `farm` in the authored farming
balance. Spreadsheet-derived overrides also set `break_return_to_inventory` to
false and installed random block/seed/gem rewards. Both entries now use `return`.
The shared generator writes the recovery flag, return item ID and empty break
loot consistently to client and server overrides for every recovery-mode item.
The spreadsheet comparison records that the user's break rule supersedes its
block/seed ranges; rebuilding the farming data preserves the correction.

The other requested items already used direct recovery. Regression coverage now
includes all of them and discovers every theme machine in the current catalogs.
The server test executes the actual recovery and break-loot functions and proves
that even a stray seed rule cannot run for a recovery item. The client test loads
the same merged catalog as the world and checks exact +1 returns, full-stack
rejection, unchanged seed counts and ordinary farming compatibility.

This changes breaking only. Existing owned seeds, growth times and legacy tree
harvest tables are preserved; no player inventory or world records are migrated.

Checks: `npm run check:machine-break-return`, `npm run check:farming-balance`,
`npm run check:security`, and Godot headless
`--script res://tests/machine_break_return_test.gd`.
