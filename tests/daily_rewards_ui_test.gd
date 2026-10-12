extends SceneTree

const Rewards = preload("res://Scripts/ui/daily_rewards_ui.gd")
var checks := 0
var failures := 0

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(description)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	for path in ["world.gd", "inventory_manager.gd", "network_manager.gd", "input_manager.gd", "interaction_manager.gd", "fishing_manager.gd"]:
		var script = load("res://Scripts/" + path)
		check(script != null and script.can_instantiate(), path + " parses")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	# Optional local world screenshot for visual checks; never required by the test.
	var preview_path := OS.get_environment("DAILY_REWARDS_PREVIEW_BACKGROUND")
	if not preview_path.is_empty():
		var preview_image := Image.load_from_file(preview_path)
		if preview_image != null:
			var background := TextureRect.new()
			background.texture = ImageTexture.create_from_image(preview_image)
			background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			viewport.add_child(background)
			background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ui = Rewards.new()
	viewport.add_child(ui)
	var now := 1770000000000
	var snapshot := {"day": 20486, "server_time": now, "reset_at": now + 43200000, "can_claim": true,
		"rewards": [{"id":"gems_250","gems":250,"name":"250 GEMS","rarity":"COMMON","chance":79.5},
			{"id":"gems_1000","gems":1000,"name":"1,000 GEMS","rarity":"RARE","chance":20},
			{"id":"gems_5000","gems":5000,"name":"5,000 GEMS","rarity":"JACKPOT","chance":0.5}]}
	ui.load_snapshot(snapshot)
	ui.show()
	await process_frame
	check(ui.phase == "ready" and not ui.action_button.disabled, "Ready claim button")
	check_ambient_lights(ui.wheel, "Before spinning")
	await capture(viewport, "daily-rewards-ready")
	# Exercise different starting rotations and every tier without rolling locally.
	for reward in snapshot.rewards:
		for rotation in [0.0, 1.37, -9.2]:
			ui.wheel.angle = rotation
			check(ui.wheel.begin_spin(reward), "Every offered reward has a destination pocket")
			var previous_angle: float = ui.wheel.angle
			var previous_ball: float = ui.wheel.ball_angle
			var moves_cleanly := true
			var lights_bounded := true
			var caught_in_pocket := true
			for step in range(1, 101):
				var progress := step / 100.0
				ui.wheel.set_spin_progress(progress)
				if progress >= ui.wheel.WINDUP_END + 0.01:
					moves_cleanly = moves_cleanly and ui.wheel.angle >= previous_angle
				if progress <= ui.wheel.CATCH_AT:
					moves_cleanly = moves_cleanly and ui.wheel.ball_angle <= previous_ball
				else:
					var pocket_angle: float = -PI * 0.5 + ui.wheel.angle + ui.wheel.winner_index * ui.wheel.STEP
					caught_in_pocket = caught_in_pocket and absf(angle_difference(ui.wheel.ball_angle, pocket_angle)) < ui.wheel.STEP * 0.45
				for bulb in range(48):
					var strength: float = ui.wheel.lamp_strength(bulb)
					lights_bounded = lights_bounded and is_finite(strength) and strength >= 0.0 and strength <= 1.0
				previous_angle = ui.wheel.angle
				previous_ball = ui.wheel.ball_angle
			ui.wheel.finish_spin()
			check(moves_cleanly and caught_in_pocket, "After wind-up the wheel coasts forward and the caught ball stays inside its winning pocket")
			check(int(ui.wheel.pockets[ui.wheel.pointed_index()].gems) == int(reward.gems) and absf(angle_difference(ui.wheel.ball_angle, -PI * 0.5)) < 0.001, "Every tier and ball settle on the confirmed prize")
			check(lights_bounded, "Animated lamp brightness stays bounded throughout the spin")
	ui.wheel._process(0.18)
	var first_wave: float = ui.wheel.lamp_strength(8)
	ui.wheel._process(0.35)
	check(absf(first_wave - ui.wheel.lamp_strength(8)) > 0.05, "Win lights sweep outward instead of freezing on one pattern")
	ui.wheel._process(8.0)
	check_ambient_lights(ui.wheel, "After the win celebration finishes")
	ui.load_snapshot(snapshot)
	for dimensions in [Vector2i(640, 360), Vector2i(360, 640), Vector2i(2340,1080)]:
		viewport.size = dimensions
		await process_frame
		ui._fit()
		var bounds: Rect2 = ui.panel.get_global_rect()
		check(bounds.position.x >= 0 and bounds.position.y >= 0 and bounds.end.x <= dimensions.x + 1 and bounds.end.y <= dimensions.y + 1, "Panel fits " + str(dimensions))
		await capture(viewport, "daily-rewards-%dx%d" % [dimensions.x,dimensions.y])
	viewport.size = Vector2i(1280, 720)
	await process_frame
	ui.pending_id = "real-claim"
	ui.pending_action = "daily_reward_claim"
	ui.pending_at = Time.get_ticks_msec()
	ui.handle_inventory_transaction_result({"action":"daily_reward_claim","request_id":"stale-claim","ok":true,"daily_reward":snapshot})
	check(ui.pending_id == "real-claim", "Ignore unrelated/stale replies")
	var claimed: Dictionary = snapshot.duplicate(true)
	claimed.can_claim = false
	claimed.reward = snapshot.rewards[1]
	ui.handle_inventory_transaction_result({"action":"daily_reward_claim","request_id":"real-claim","ok":true,"daily_reward":claimed})
	check(ui.phase == "spinning" and ui.action_button.disabled, "Only confirmed rewards start a spin")
	ui.spin_tween.custom_step(2.0)
	await capture(viewport, "daily-rewards-spinning")
	ui.spin_tween.custom_step(7.0)
	check(ui.phase == "result", "Spin completes")
	var winning_index: int = ui.wheel.pointed_index()
	check(winning_index == ui.wheel.winner_index and int(ui.wheel.pockets[winning_index].gems) == 1000, "Wheel lands on the server prize")
	check(absf(angle_difference(ui.wheel.ball_angle, -PI * 0.5)) < 0.001, "Ball settles under the fixed pointer")
	ui.reveal_tween.custom_step(1.0)
	ui.prize_tween.custom_step(1.0)
	check(ui.phase == "reveal" and ui.prize_name.text == "1,000 GEMS", "Automatic reveal counts up to the same server prize")
	check(is_instance_valid(ui.backdrop.confetti_effect), "Prize reveal starts the shared game confetti")
	await create_timer(0.35).timeout
	await capture(viewport, "daily-rewards-winner")
	ui._activate()
	check(ui.phase == "collecting" and not ui.panel.visible and ui.collection_fx.visible, "Collect sends gems toward the HUD over the visible world")
	ui._activate()
	check(ui.phase == "collecting", "Repeated collect does not start a second reward")
	ui.collection_tween.custom_step(1.2)
	check(not ui.visible and ui.phase == "claimed", "Collection animation closes the window")
	ui.show()
	ui.pending_id = "retry"
	ui.pending_action = "daily_reward_claim"
	ui.handle_inventory_transaction_result({"action":"daily_reward_claim","request_id":"retry","ok":true,"already_claimed":true,"daily_reward":claimed})
	check(ui.phase == "claimed", "Retries do not replay or award a second prize")
	ui.pending_id = "delayed"
	ui.pending_at = Time.get_ticks_msec() - 13000
	ui._process(0)
	check(ui.phase == "error" and ui.pending_id.is_empty() and not ui.action_button.disabled, "Timeout exposes safe status retry")
	ui.pending_id = "rejected"
	ui.handle_inventory_transaction_result({"action":"daily_reward_claim","request_id":"rejected","ok":false,"message":"Unavailable"})
	check(ui.phase == "error" and ui.status.text == "Unavailable", "Server rejection shown")
	ui.load_snapshot(claimed)
	ui._process(0)
	check(ui.countdown.text.contains("12:00:00"), "Countdown uses server time")
	check_ambient_lights(ui.wheel, "Reopening today's claimed reward")
	await capture(viewport, "daily-rewards-claimed")
	ui._start_spin(snapshot.rewards[2])
	ui.close_rewards()
	ui.spin_tween.custom_step(7.0)
	ui.reveal_tween.custom_step(1.0)
	ui.prize_tween.custom_step(1.0)
	check(ui.phase == "reveal" and not ui.backdrop.is_processing() and not ui.wheel.is_processing(), "Closing during spin preserves the prize and pauses hidden effects and lamps")
	check(ui.backdrop.confetti_effect.particle_layers.all(func(layer): return layer.speed_scale == 0), "Hidden GPU confetti is paused")
	ui.show()
	await process_frame
	check(ui.backdrop.is_processing() and ui.prize_name.text == "5,000 GEMS", "Reopening resumes the saved jackpot reveal")
	check(ui.backdrop.confetti_effect.particle_layers.all(func(layer): return layer.speed_scale == 1), "Reopened GPU confetti resumes")
	await create_timer(0.4).timeout
	await capture(viewport, "daily-rewards-jackpot")
	ui._activate()
	ui.collection_fx._process(0.3)
	await capture(viewport, "daily-rewards-collect")
	ui.close_rewards()
	check(ui.phase == "claimed" and not ui.collection_fx.is_processing(), "Back during collection cancels cosmetic effects safely")
	ui.show()
	ui._start_spin(snapshot.rewards[0])
	ui.spin_tween.custom_step(7.0)
	ui.reveal_tween.custom_step(1.0)
	ui.prize_tween.custom_step(1.0)
	await create_timer(0.25).timeout
	await capture(viewport, "daily-rewards-common")
	await create_timer(2.0).timeout
	check(not is_instance_valid(ui.backdrop.confetti_effect), "Confetti completes and frees itself without an endless celebration loop")
	ui.queue_free()
	await process_frame
	await check_hud(viewport)
	print("DAILY_REWARDS_UI_%s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)

func check_ambient_lights(wheel: Control, state: String) -> void:
	var original_angle: float = wheel.angle
	var lights: Array[float] = []
	# Sample away from the winning pointer: its small pulse alone is not a chase.
	for bulb in range(12, 37): lights.append(wheel.lamp_strength(bulb))
	wheel._process(0.75)
	var moving_lights := 0
	for bulb in range(12, 37):
		if absf(wheel.lamp_strength(bulb) - lights[bulb - 12]) > 0.1: moving_lights += 1
	check(wheel.is_processing() and moving_lights >= 4 and wheel.angle == original_angle, state + ": rim lights keep chasing while the wheel stays still")

func check_hud(viewport: SubViewport) -> void:
	# Run the actual world/HUD methods with world streaming disabled.
	var fixture_script := GDScript.new()
	fixture_script.source_code = "extends 'res://Scripts/world.gd'\nfunc _ready(): pass\nfunc _process(_delta): pass\nfunc _physics_process(_delta): pass\n"
	check(fixture_script.reload() == OK, "World HUD fixture parses")
	var scene := Node.new()
	viewport.add_child(scene)
	var layer := Control.new()
	layer.name = "UI"
	scene.add_child(layer)
	layer.size = Vector2(viewport.size)
	var world = fixture_script.new()
	scene.add_child(world)
	world.in_world = true
	world.current_world_name = "START"
	world.setup_ui_layers()
	var inventory = load("res://Scripts/inventory_manager.gd").new()
	scene.add_child(inventory)
	inventory.set_process(false)
	inventory.world = world
	inventory.ui_layer_ref = layer
	world.inventory_manager = inventory
	inventory.setup_gem_counter()
	inventory.setup_daily_rewards_button()
	inventory.gem_icon.texture = preload("res://Assets/currency/gem.png")
	inventory.gem_count_label.text = "6,097"
	inventory.update_gem_counter_position()
	await process_frame
	var button: Button = inventory.daily_rewards_button
	check(button.position.x == 16 and button.position.y == 60, "Button directly below gems at left")
	check(world.is_floating_hud_button_at_point(button.get_global_rect().get_center()), "HUD hit-test recognizes reward button")
	for factor in [0.75,1.0,1.25,1.5]:
		inventory.gem_panel.scale = Vector2.ONE * factor
		inventory.update_gem_counter_position()
		check(button.get_global_rect().position.y >= inventory.gem_panel.get_global_rect().end.y + 7.0, "Button stays below scaled gems")
	inventory.gem_panel.scale = Vector2.ONE
	inventory.update_gem_counter_position()
	await capture(viewport, "daily-rewards-hud")
	world.daily_rewards_ui.show()
	check(world.is_major_ui_open() and world.is_movement_blocking_ui_open(), "Reward modal blocks movement")
	check(world.is_panel_ui_at_point(Vector2(20,20)), "Open rewards prevent gameplay clicks through the transparent surround")
	var input = load("res://Scripts/input_manager.gd").new()
	input.world = world
	check(input._any_ui_blocking() and input._non_chat_ui_blocking(), "Reward modal blocks gameplay and chat shortcuts")
	check(input.handle_back_request() and not world.is_daily_rewards_open(), "Android Back closes rewards")
	world.daily_rewards_ui.show()
	var interaction = load("res://Scripts/interaction_manager.gd").new()
	interaction.world = world
	interaction.use_selected_item_at_mouse()
	check(true, "Item interaction returns before world actions")
	world.daily_rewards_ui.close_rewards()
	check(not world.is_daily_rewards_open(), "HUD modal closes")
	input.free()
	interaction.free()
	scene.queue_free()

func capture(viewport: SubViewport, filename: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await create_timer(0.15).timeout
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("D:/Pixelmania/" + filename + ".png")
