extends SceneTree

const Equipment = preload("res://Scripts/equipment_manager.gd")
const Manager = preload("res://Scripts/player_manager.gd")
const Atlas = preload("res://Scripts/atlas_texture_factory.gd")
const Trail = preload("res://Scripts/sword_slash_trail.gd")
const WEAPONS = ["blue_saber", "phoenix_sword", "angelic_sword", "sakura_sword", "red_saber", "green_saber", "void_saber", "void_trident", "blood_battleaxe", "serpent_staff", "neptune_trident", "fire_staff", "wizards_staff"]
const IMPACT_WEAPONS = ["neptune_trident", "phoenix_sword", "angelic_sword", "void_saber", "void_trident", "blood_battleaxe", "serpent_staff", "fire_staff", "wizards_staff"]
var failures := 0
var checks := 0

func _init(): call_deferred("run")

func check(ok: bool, message: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run():
	var world = load("res://tests/void_trident_world_fixture.gd").new()
	root.add_child(world)
	var source = load("res://Scenes/main.tscn").instantiate()
	var actor := Node2D.new()
	world.add_child(actor)
	world.player = actor
	world.in_world = true
	world.particle_manager = load("res://Scripts/particle_manager.gd").new()
	world.add_child(world.particle_manager)
	world.particle_manager.setup(world, false)
	world.item_gameplay_manager = load("res://Scripts/item_gameplay_manager.gd").new()
	world.add_child(world.item_gameplay_manager)
	world.item_gameplay_manager.setup(world)
	for node_name in ["PlayerVisual", "AnimationPlayer", "Jump", "idle", "Sprite2D", "DeadSpiritAnimated"]:
		var original = source.get_node("Player").get_node_or_null(node_name)
		if original != null:
			actor.add_child(original.duplicate())
	var database = load("res://Scripts/item_database.gd").new()
	for item in WEAPONS:
		world.item_database[item] = database.get_item_data(item)
		world.tool_textures[item] = Atlas.load_texture(world.item_database[item].texture)
	database.free()
	var local_equipment = Equipment.new()
	actor.add_child(local_equipment)
	local_equipment.setup(world, actor, false)
	local_equipment.set_process(false)
	local_equipment.update_equipped_tool_visual("void_trident", 1)
	var manager = Manager.new()
	world.add_child(manager)
	manager.world = world
	world.player_manager = manager
	var network = load("res://tests/fixtures/hand_swing_network_probe.gd").new()
	world.add_child(network)
	network.fixture_world = world
	for weapon in WEAPONS:
		var remote := Node2D.new()
		world.add_child(remote)
		remote.set_meta("remote_id", weapon)
		remote.set_meta("facing", 1)
		remote.set_meta("animation_state", "idle")
		remote.set_meta("equipment_slots", {"hand":weapon})
		remote.set_meta("equipment_slots_debug_key", weapon)
		manager.remote_players[weapon] = remote
		check(manager.ensure_remote_player_shared_visual_pipeline(remote), "Remote rig must be created")
		manager.update_remote_shared_equipment_visuals(remote)
		var equipment = manager.get_remote_equipment_manager(remote)
		var hand = equipment.hand_item_animated
		check(hand.visible and (hand.sprite_frames.get_frame_count(hand.animation) == 1 or hand.is_playing()), "Remote hand artwork must remain visible and play any configured frames for " + weapon)
		var trails := remote.get_node("PlayerVisual").get_children().filter(func(n): return n.get_script() == Trail)
		if Trail.supports_weapon(weapon):
			check(trails.size() == 1, "Remote %s must have exactly one trail, without a copied local trail" % weapon)
			check(remote.get_node_or_null("PlayerVisual/SwordSlashTrail") == equipment.sword_slash_trail, "Animation must address the remote-owned trail for " + weapon)
			check(equipment.sword_slash_trail.blade == equipment.hand_item_animated, "Trail must track the remote blade")
		else:
			check(trails.is_empty(), "A non-sword remote must not inherit the observer's sword trail")
		manager.apply_remote_player_action_animation(weapon, "punch", 1)
		var animation = manager.get_remote_animation_manager(remote)
		check(animation.current_movement_animation == str(world.item_database[weapon].get("punch_animation", "punch")), "Remote actor must play its own weapon's action")
		if Trail.supports_weapon(weapon):
			check(equipment.sword_slash_trail.swing_active, "Remote action must start its own weapon trail for " + weapon)
		if weapon in IMPACT_WEAPONS:
			world.equipped_tool = weapon
			var original_children = world.get_children() + world.particle_manager.get_children()
			check(world.spawn_hand_item_swing_particles(Vector2(48, -4), weapon), "Local effect must spawn for " + weapon)
			var outgoing = network._build_player_position_payload(actor.position, 1, "TEST", false, false, "")
			check(outgoing.hand_swing_visual.sequence > 0, "Free-swing sequence must reach the real movement payload")
			check(outgoing.hand_swing_visual.offset_x == 48, "Movement payload preserves the aimed offset")
			var baseline = outgoing.hand_swing_visual.duplicate()
			baseline["tool"] = weapon # Stamped by the server from owned equipment.
			baseline["facing"] = -1
			var count_before = effect_count(world)
			manager.consume_remote_hand_swing_visual(remote, {"hand_swing_visual":null}, false, true)
			check(int(remote.get_meta("hand_swing_visual_sequence", -1)) == 0, "No prior swing establishes a zero baseline")
			manager.consume_remote_hand_swing_visual(remote, {"hand_swing_visual":baseline}, true, true)
			check(effect_count(world) == count_before + 1, "The very first swing after joining must be visible for " + weapon)
			count_before = effect_count(world)
			manager.consume_remote_hand_swing_visual(remote, {"hand_swing_visual":baseline}, false, true)
			check(effect_count(world) == count_before, "Joining must not replay an old swing")
			var swing = baseline.duplicate()
			swing.sequence += 1
			# Advance effect dedupe timestamps to a distinct, valid next strike.
			for key in remote.get_meta_list():
				if str(key).begins_with("last_") and str(key).ends_with("msec"):
					remote.set_meta(key, Time.get_ticks_msec() - 300)
			manager.consume_remote_hand_swing_visual(remote, {"hand_swing_visual":swing}, true, true)
			var expected_count = count_before if weapon == "neptune_trident" else count_before + 1
			check(effect_count(world) == expected_count, "Observer receives subsequent particles (or refreshes the same water jet) for " + weapon)
			manager.consume_remote_hand_swing_visual(remote, {"hand_swing_visual":swing}, true, true)
			check(effect_count(world) == expected_count, "Duplicate snapshots must not duplicate effects")
			swing.sequence += 1
			manager.consume_remote_hand_swing_visual(remote, {"hand_swing_visual":swing}, true, false)
			manager.consume_remote_hand_swing_visual(remote, {"hand_swing_visual":swing}, true, true)
			check(effect_count(world) == expected_count, "Hidden actions must not replay on visibility changes")
			for effect in world.get_children() + world.particle_manager.get_children():
				if effect not in original_children:
					effect.free()
		var old_trail = equipment.sword_slash_trail
		remote.set_meta("equipment_slots", {"hand":"neptune_trident"})
		remote.set_meta("equipment_slots_debug_key", "changed-to-neptune")
		manager.update_remote_shared_equipment_visuals(remote)
		check(remote.get_node_or_null("PlayerVisual/SwordSlashTrail") == null, "Changing away from a sword removes its owned trail")
		check(not is_instance_valid(old_trail) or old_trail.is_queued_for_deletion(), "Old trail must be released")
		manager.remote_players.erase(weapon)
		remote.free()
	source.free()
	world.free()
	print("REMOTE_HAND_ITEM_VISUALS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func effect_count(world) -> int:
	return world.get_child_count() + world.particle_manager.get_child_count()
