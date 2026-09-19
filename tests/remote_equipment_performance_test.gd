extends SceneTree

class EquipmentStub extends RefCounted:
	var updates := 0
	var hand := ""
	var facing := 0
	func update_equipped_tool_visual(value: String, direction: int):
		updates += 1
		hand = value
		facing = direction

class ManagerProbe extends "res://Scripts/player_manager.gd":
	var equipment := EquipmentStub.new()
	func get_remote_equipment_manager(_player): return equipment

func _initialize(): call_deferred("run")

func run():
	var manager := ManagerProbe.new()
	var players := []
	for index in range(50):
		var player := Node.new()
		var slots: Dictionary = manager.normalize_remote_equipment_slots({"hand": "pickaxe", "hat": "top_hat"})
		player.set_meta("equipment_slots", slots)
		player.set_meta("equipment_slots_debug_key", manager.get_equipment_slots_debug_key(slots))
		player.set_meta("facing", 1)
		assert(manager.update_remote_shared_equipment_visuals(player))
		players.append(player)
	var updates_before := manager.equipment.updates
	var samples := []
	for iteration in range(501):
		var started := Time.get_ticks_usec()
		for player in players: assert(manager.update_remote_shared_equipment_visuals(player))
		if iteration > 0: samples.append(float(Time.get_ticks_usec() - started) / 1000.0)
	samples.sort()
	assert(manager.equipment.updates == updates_before, "Stable appearance must not reapply sprites")
	var changed: Node = players[0]
	var empty_slots: Dictionary = manager.normalize_remote_equipment_slots({})
	changed.set_meta("equipment_slots", empty_slots)
	changed.set_meta("equipment_slots_debug_key", manager.get_equipment_slots_debug_key(empty_slots))
	manager.update_remote_shared_equipment_visuals(changed)
	assert(manager.equipment.updates == updates_before + 1 and manager.equipment.hand == "", "Unequip must refresh")
	changed.set_meta("facing", -1)
	manager.update_remote_shared_equipment_visuals(changed)
	assert(manager.equipment.updates == updates_before + 2 and manager.equipment.facing == -1)
	changed.remove_meta("equipment_slots_debug_key")
	changed.set_meta("equipment_slots", {"hand": "pickaxe"})
	manager.update_remote_shared_equipment_visuals(changed)
	assert(manager.equipment.hand == "pickaxe", "Legacy metadata must still work")
	print("REMOTE_EQUIPMENT_PROBE ", JSON.stringify({"players": players.size(), "samples": samples.size(), "median_ms": samples[250], "p95_ms": samples[475], "max_ms": samples[-1]}))
	for player in players: player.free()
	manager.free()
	print("REMOTE_EQUIPMENT_PERFORMANCE_OK")
	quit()
