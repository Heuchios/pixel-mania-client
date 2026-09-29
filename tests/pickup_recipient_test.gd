extends SceneTree

class NetworkFixture extends Node:
	var player_id := "local"
	var player_name := "Local"

func _initialize(): call_deferred("run")
func run():
	create_timer(15).timeout.connect(func(): quit(1))
	var drops = load("res://tests/fixtures/pickup_recipient_fixture.gd").new()
	drops.test_network = NetworkFixture.new()
	drops.entries = {"gem": {"drop_id": "gem", "item_type": "gem", "item_category": "currency", "amount": 3}, "item": {"drop_id": "item", "item_type": "dirt", "item_category": "block", "amount": 2}}
	for collector in ["remote", "local"]:
		var payload := {"type": "world_item_drop_remove", "bulk_pickup": true, "removed_drop_ids": ["gem", "item"], "requested_by": collector, "_server_inventory_update_applied": true}
		drops.apply_network_item_drop_remove(payload)
		assert(drops.removals[-1].animate == (collector == "local"))
		assert(drops.removals[-2].animate == (collector == "local"))
	# A losing local request must not animate somebody else's confirmed pickup.
	drops.entries.gem.pickup_requested = true
	drops.entries.gem.pickup_requested_by = "local"
	drops.apply_network_item_drop_remove({"type": "world_item_drop_remove", "drop_id": "gem", "requested_by": "remote", "_server_inventory_update_applied": true})
	assert(not drops.removals[-1].animate)
	drops.apply_network_item_drop_remove({"type": "world_item_drop_remove", "bulk_pickup": true, "updated_drops": [{"drop_id": "gem", "amount": 1}], "requested_by": "remote", "_server_inventory_update_applied": true})
	assert(drops.updates[-1].requested_by == "remote", "Partial stack results preserve collector identity")
	drops.test_network.free()
	drops.free()
	print("PICKUP_RECIPIENT_PASS")
	quit()
