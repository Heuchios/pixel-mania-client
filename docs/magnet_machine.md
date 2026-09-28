# Magnet Machine

Place `magnet_machine` in a world you own and have locked, then wrench it.
Choose a block or seed from your inventory. A machine holds up to 5,000 of
one item. Collection gathers matching newly generated block-break and tree
harvest rewards anywhere in that world; manual drops are not collected.
When full, additional rewards drop normally. Multiple machines fill in order.

Click the stock button to add or take items. Empty the machine before changing
its selected item or using **Remove empty machine** to return it to inventory.
Only the world owner (or an administrator) can change settings or take stock.

Enable building with **Update**, or punch the machine to toggle it. **Get Remote**
connects a Magnet Machine Remote to this machine. Select the remote in inventory
and click a valid target to place the selected block or plant its seed, consuming
machine stock. Normal placement reach, world permissions and occupancy rules
still apply. Visitors can obtain a remote but cannot manage the machine.
Get a remote again after changing worlds or reconnecting. Removed/replaced
machines invalidate old connections. Remotes cannot be traded or dropped.

Stock, settings and item transfers use the server's durable PostgreSQL world and
inventory transactions. Failed saves restore stock and any affected placement,
harvest or inventory; only committed results are broadcast. Remote bindings are
session-local and cannot be supplied by a client packet.

Artwork uses `image.png` cells (24,14) off and (25,14)/(26,14) on. The remote
uses `Assets/items/material.png` cell (6,3). The selected item is shown inside
the machine using the same visible-bounds sizing as vending previews.

Checks: backend `npm run check:magnet-machine`, and Godot headless
`--script res://tests/magnet_machine_test.gd`.
