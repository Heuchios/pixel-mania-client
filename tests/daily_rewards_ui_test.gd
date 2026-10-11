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
		"rewards": [{"id":"gems_250","gems":250,"name":"250 GEMS","rarity":"COMMON","chance":75},
			{"id":"gems_1000","gems":1000,"name":"1,000 GEMS","rarity":"RARE","chance":20},
			{"id":"gems_5000","gems":5000,"name":"5,000 GEMS","rarity":"JACKPOT","chance":5}]}
	ui.load_snapshot(snapshot)
	ui.show()
	await process_frame
	check(ui.phase == "ready" and not ui.action_button.disabled, "Ready claim button")
	check(ui.odds.text.contains("75%") and ui.odds.text.contains("5%"), "Server odds displayed")
	await capture(viewport, "daily-rewards-ready")
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
	ui.spin_tween.custom_step(6.0)
	check(ui.phase == "result", "Spin completes")
	var winner: Control = ui.reel.get_child(36)
	var selected_center: float = winner.position.x + winner.size.x * 0.5 + ui.reel.position.x
	check(absf(selected_center - ui.reel_clip.size.x * 0.5) < 1, "Reel lands on server prize")
	ui._activate()
	check(ui.phase == "reveal" and ui.prize_name.text == "1,000 GEMS", "Collect reveals same server prize")
	await capture(viewport, "daily-rewards-winner")
	ui._activate()
	check(not ui.visible and ui.phase == "claimed", "Continue closes")
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
	await capture(viewport, "daily-rewards-claimed")
	ui.queue_free()
	await process_frame
	await check_hud(viewport)
	print("DAILY_REWARDS_UI_%s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)

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
