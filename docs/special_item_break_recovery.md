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

## Verified staging deployment — 2026-10-12

- Release: `20261012-machine-return-bcd7c18`.
- Backend: `bcd7c183a6832f6a9f5ec92697a0ececb578a829`.
- Client source: `afec650ad3977c9a050ff2d356e72c37aea90e59` (clean release metadata).
- Full backend security checks and the 332-row farming rebuild/check passed.
  Actual client recovery checks passed for all 11 requested catalog items.
  The deployed server test passed for 13 recoverable machine states, including
  existing Leaderboard and Fish Monger coverage.
- Public staging health and PostgreSQL/Redis checks passed; current/minimum
  client version remains 1.2.25. Rollback: `20261012-combined-036f3b0`.
- Production remains `20261010-hand-visuals-33256ff`. Published binaries and
  player data were not changed.
- Logs: `D:/Pixelmania/work/machine-break-20261012-security.log`,
  `machine-break-20261012-deploy.log`, `machine-break-20261012-live-check.log`,
  and `D:/Pixelmania/work/machine-break-tests/client.log`.
