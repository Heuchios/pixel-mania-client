# Protected block punch feedback

2026-10-12: visitors punching protected tiles now get the equipped hand item's
animation and cosmetic swing effects without a lock warning. These effects use
the existing movement snapshot visual event so observers receive them too.
Denied hits do not damage blocks, create cracks, withdraw items, toggle machines,
harvest resources, or submit ordinary break requests.

Foreground, background, planted trees and electrical tiles use this behavior.
Mouse, touch and facing punches share the same permission handling; keyboard
Space also starts the player animation. Existing reach and input cadence limits
still apply. Wrench/interact retains access warnings and public interactions.

Real world/area locks still send a hit for the server to check decay. The client
silences only permission/decay rejections marked as hit or break actions. It
preserves placement errors, connection errors and the owner's storage-blocker
warning, plus pending request reconciliation. Server permissions are unchanged.

Validation in Godot 4.7.1:

- `protected_punch_test`: six hand items across fourteen protected block types,
  background/tree/electrical targets, mouse/keyboard/facing paths, cadence/reach,
  no mutations, wrench warnings, public vending/Fish Monger, decay requests and
  scoped server rejection handling.
- `punch_toggle_machine_test`: authorized toggles, break-only access, restricted
  cosmetics and wrench warnings, four-hit destruction and returned machines.
- `lock_decay_punch_test`: all five lock types retain authoritative decay checks.
- `mobile_punch_reach_test`: mobile press/hold routes and local animation.
- `remote_hand_item_visuals_test`: 189 checks, zero failures, including observer
  animation, particles, trails and duplicate snapshot suppression. Existing
  `Scenes/main.tscn` image UID fallback warning only.
- `break_sync_test` and `block_placement_reconciliation_test`: pending/stale
  responses, queued removals and placement reconciliation remain intact.

This is a client source change for staging. It needs an updated client to take
effect; it does not require a backend deployment or change published binaries.
