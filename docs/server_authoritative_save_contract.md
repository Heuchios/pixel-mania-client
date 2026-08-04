# Server-Authoritative Save Contract

PixelMania is a 100% server-multiplayer game. Client worlds should treat every
normal world as server-owned. The client may show pending feedback, but it must
not commit world or inventory changes until the server replies with authoritative
state.

## World Entry

Client sends:

```json
{"type":"join_world","world":"START"}
```

Server replies:

```json
{
  "type": "world_state",
  "world": "START",
  "foreground": [],
  "background": [],
  "seeds": [],
  "interactions": [],
  "drops": [],
  "world_lock": {}
}
```

The server should load or create the world, keep it in memory while active, and
mark it dirty when actions change world state.

## Block Updates

Client sends:

```json
{
  "type": "world_block_update",
  "action": "place|hit|break",
  "layer": "foreground|background",
  "x": 10,
  "y": 20,
  "block_type": "dirt",
  "world": "START",
  "hit_power": 1,
  "hit_count": 3,
  "max_hits": 3
}
```

Server validates ownership, locks, reach, inventory, and block health. On success
it broadcasts the authoritative update:

```json
{
  "type": "world_block_update",
  "action": "place|break",
  "layer": "foreground|background",
  "x": 10,
  "y": 20,
  "block_type": "dirt",
  "world": "START",
  "player_data": {}
}
```

`player_data` is optional but should be included when the action changes player
inventory. On rejected actions, send:

```json
{"type":"action_rejected","action":"world_block_update","message":"Reason"}
```

## Seeds

Seed placement, splice, and harvest use inventory transactions:

```json
{"type":"inventory_transaction_request","action":"seed_place","world":"START","x":10,"y":20,"seed_type":"dirt_seed"}
{"type":"inventory_transaction_request","action":"seed_splice","world":"START","x":10,"y":20,"seed_type":"wood_seed"}
{"type":"inventory_transaction_request","action":"seed_harvest","world":"START","x":10,"y":20}
```

Server replies with `inventory_transaction_result` and broadcasts
`world_seed_update`.

## Drops

Dropping inventory uses:

```json
{
  "type": "inventory_transaction_request",
  "action": "drop_inventory_item",
  "world": "START",
  "item_type": "dirt",
  "item_category": "block",
  "amount": 1,
  "x": 320,
  "y": 640,
  "stack_grid_x": 10,
  "stack_grid_y": 20
}
```

Picking up a drop uses:

```json
{"type":"world_item_drop_pickup","drop_id":"abc"}
```

Server validates the drop and the player's context using the player's authenticated
server-side current world id. Do not trust a client-provided world name for pickup.
Validate `drop_id`, distance, ownership, inventory availability, and stack rules,
then broadcast `world_item_drop_update` with the remaining amount or
`world_item_drop_remove` when fully consumed. Include `player_data` whenever
inventory changes.

Client expectations for pickup packets:

- `world_item_drop_pickup` must return either `world_item_drop_update` (with a
  remaining-stack value) or `world_item_drop_remove` (fully consumed).
- The packet must reject forged/invalid pickup requests; clients do not send a
  pickup amount.
- Include `player_data` when inventory is mutated, or include the pickup
  requester identity on the drop update/remove packet so the requesting client
  can safely reconcile the confirmed delta.

Recommended authoritative server flow (single stack per item, max stack 400):

1. Validate request:
   - player/session authenticated
   - canonical server-side player current world id is resolved from the session
   - `drop_id` exists in that current world's authoritative drop map and not already claimed
   - drop amount > 0 and not stale
   - player within pickup range (server-side distance check)
   - item is known/stackable or non-stackable (max stack = 1)
   - inventory capacity for that item/category
2. Lock drop and player inventory mutation atomically in the world transaction.
3. Compute `picked = min(available_inventory_space, drop_amount)`. The client
   request does not include or control the pickup amount.
4. Persist drop and player state:
   - if `picked == drop_amount` -> remove drop, send
     `{"type":"world_item_drop_remove","drop_id":"...","remaining":0}`.
   - else decrement drop amount and send
     `{"type":"world_item_drop_update","drop_id":"...","remaining":new_amount}`.
5. Broadcast inventory changes through `player_data` and include the same remaining
   stack value in the pickup payload so clients can visually sync immediately.
- Reject duplicate/late pickup attempts that race with other players; response must be
  idempotent per drop lock state.
- If a pickup is rejected because the drop was not found, log username, current
  server world id, requested `drop_id`, world drop count, and whether the drop key
  exists in the map.

## Inventory Transactions

The client sends inventory-changing gameplay as `inventory_transaction_request`
instead of editing inventory locally in authenticated worlds. Supported actions:

- `craft_recipe`
- `furnace_recipe`
- `shop_buy`
- `fishing_start`
- `fishing_complete`
- `fish_monger_sell`
- `fish_monger_sell_all`
- `trash_inventory_item`

Server replies:

```json
{
  "type": "inventory_transaction_result",
  "action": "craft_recipe",
  "ok": true,
  "message": "Crafting finished.",
  "player_data": {}
}
```

`player_data` should be the authoritative post-transaction player state whenever
inventory, equipment, currency, lures, fish, or fishing progression records changed.
Fishing catches should preserve `fishing_records` in player data so PostgreSQL
stores per-player totals, XP/level, discovered species, biggest species weights,
species catch counts, and rarest-catch metadata.
Fish stacks are weight-based: `fish_inventory[fish_id]` stores total pounds as a
decimal number, and `fish_monger_sell.amount` means pounds to sell. Fish sale
value should be `round(amount * price_per_lb)`, but sales where
`amount * price_per_lb < 1` should be rejected instead of rounded up to 1 gem.

## Saving

The server should:

- Keep active worlds in memory.
- Apply validated actions to memory immediately.
- Persist dirty worlds on a timer, when the last player leaves, and on shutdown.
- Save inventory changes transactionally with world changes that consume or grant items.
- Treat `player_state_save` as a profile/settings helper only; inventory and world
  state should come from validated transactions and world actions.
- Never rely on client local world JSON as gameplay truth.
- Periodically compact deltas into full world snapshots.
