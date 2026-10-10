extends SceneTree

const PullGame = preload("res://Scripts/fishing_pull_game.gd")
const FishingManager = preload("res://Scripts/fishing_manager.gd")
const InputManager = preload("res://Scripts/input_manager.gd")
const TestWorld = preload("res://tests/fixtures/fishing_test_world.gd")
var checks := 0
var failures: Array[String] = []
var world
var manager
var inputs
var network

class MockNetwork:
	extends Node
	var online := false
	var requests: Array[Dictionary] = []
	func is_connected_to_server() -> bool: return online
	func has_active_session() -> bool: return online
	func send_inventory_transaction_request(data: Dictionary) -> bool:
		requests.append(data.duplicate(true))
		return online

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("[fishing] " + message)

func advance(game, seconds: float) -> void:
	for _i in range(int(ceil(seconds * 60.0))):
		game.update(1.0 / 60.0)

func aim(game) -> void:
	advance(game, 0.7)
	game.cursor = game.zone_start + game.zone_size * 0.5

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i.ZERO
	await process_frame
	# These tests must use run_fishing_tests.ps1's project, never game autoloads.
	if root.get_node_or_null("NetworkManager") != null:
		push_error("Run with tests/run_fishing_tests.ps1 to isolate networking.")
		quit(1)
		return
	_test_rules()
	_test_bobber_catch_animation()
	network = MockNetwork.new()
	network.name = "NetworkManager"
	root.add_child(network)
	world = TestWorld.new()
	root.add_child(world)
	manager = FishingManager.new()
	world.add_child(manager)
	world.fishing_manager = manager
	manager.setup(world)
	inputs = InputManager.new()
	world.add_child(inputs)
	inputs.setup(world)
	world.input_manager = inputs
	await _test_cast_and_inputs()
	await _test_cleanup()
	await _test_network_lifecycle()
	await _test_wooden_rod_phone_cast()
	_test_cast_context_changes()
	await _test_cast_viewport_changes()
	await _test_last_lure()
	await _test_layout()
	world.catch_confetti.clear()
	for rarity in ["common", "uncommon", "rare", "epic", "legendary"]:
		manager._present_catch_card({"name": "Test fish", "rarity": rarity})
	check(world.catch_confetti == ["epic", "legendary"], "Original confetti must play once for epic and legendary reward cards only")
	world.queue_free()
	network.queue_free()
	await process_frame
	await create_timer(0.3).timeout
	print("[fishing] %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _test_rules() -> void:
	for rare in [false, true]:
		for bonus in [0.0, 0.045, 0.075, 0.095, 0.12]:
			var game = PullGame.new()
			game.start(rare, bonus)
			game.pull()
			check(game.misses == 0, "Hook press counted as a miss")
			check(game.zone_size * game.SWEEP_SECONDS >= 1.3, "Timing window is too tight")
			for _pull in range(4 if rare else 3):
				aim(game)
				var before: int = game.pulls
				game.pull()
				game.pull()
				check(game.pulls == before + 1 and game.misses == 0, "Duplicate input spent an extra try")
			check(game.outcome == "caught", "Valid pulls failed to catch")
			game.pull()
			check(game.pulls == game.required_pulls, "Catch resolved twice")
	var forgiving = PullGame.new()
	forgiving.start(false)
	aim(forgiving)
	forgiving.pull()
	for miss in range(2):
		advance(forgiving, 0.7)
		forgiving.cursor = 0.0
		forgiving.pull()
		check(forgiving.pulls == 1 and forgiving.outcome == "", "Miss removed progress or ended catch early")
		advance(forgiving, 0.7)
		check(forgiving.zone_size > 0.44, "Miss did not widen next window")
	for _pull in range(2):
		aim(forgiving)
		forgiving.pull()
	check(forgiving.outcome == "caught", "Two misses must still permit a catch")
	var idle = PullGame.new()
	idle.start(false)
	advance(idle, 15)
	check(idle.outcome == "escaped" and idle.misses == 3, "Idle game did not end")
	var stalled = PullGame.new()
	stalled.start(false)
	advance(stalled, .5)
	stalled.update(10.0)
	check(stalled.misses == 0 and stalled.cursor < .1, "Frame stall skipped the catch window")
	for edge in [0, 1]:
		var game = PullGame.new()
		game.start(false)
		advance(game, .5)
		game.cursor = game.zone_start + edge * game.zone_size
		game.pull()
		check(game.pulls == 1, "Visible zone boundary was counted as a miss")

func begin_local(fish := "guppy") -> void:
	manager.start_local_cast(world.target, "bait", true, "", {"item_id": fish, "difficulty": 1})
	manager.update_fishing(.4)
	manager.update_fishing(6.0)

func send_key(code: Key, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.echo = echo
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

func send_click(position: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)

func _test_cast_and_inputs() -> void:
	world.target = Vector2i(8, 1)
	manager.use_fishing_rod_at_mouse()
	check(not world.fishing_active and world.lure_inventory.bait == 20, "Out-of-reach cast spent bait")
	world.target = Vector2i(2, 2)
	manager.use_fishing_rod_at_mouse()
	check(not world.fishing_active, "Cast on dry land started")
	world.target = Vector2i(2, 1)
	begin_local()
	check(world.lure_inventory.bait == 19 and manager.state == "bite", "Cast did not spend one lure and reach bite")
	check(manager.bobber != null and manager.fishing_line.visible, "Bobber/line did not appear")
	check(manager.fishing_line.points.size() == 17, "Fishing line lost its segments")
	inputs.is_holding = true
	inputs._process(3.0)
	check(not inputs.is_holding and manager.state == "bite", "Held cast turned into a hook")
	await create_timer(.22).timeout
	var hook = manager.fishing_ui.bite_panel.get_node("HookButton")
	send_click(hook.get_global_rect().get_center())
	check(manager.state == "minigame", "Native HOOK button did not hook")
	check(manager.pull_game.misses == 0, "Hook click also missed a pull")
	manager.catch_fish()
	check(manager.state == "minigame", "Catch API bypassed unfinished pulls")
	await process_frame
	aim(manager.pull_game)
	manager.update_minigame_visuals()
	send_key(KEY_E)
	check(manager.pull_game.pulls == 1, "E did not reel")
	await process_frame
	aim(manager.pull_game)
	manager.update_minigame_visuals()
	send_key(KEY_SPACE, true)
	check(manager.pull_game.pulls == 1, "Held key repeat reeled")
	send_key(KEY_SPACE)
	check(manager.pull_game.pulls == 2, "Space did not reel")
	await process_frame
	aim(manager.pull_game)
	manager.update_minigame_visuals()
	await create_timer(.15).timeout
	send_click(manager.fishing_ui.reel_button.get_global_rect().get_center())
	var landed_units: int = int(world.fish_inventory.get("guppy", 0))
	check(manager.state == "idle" and landed_units >= 1 and landed_units <= 1500, "Native REEL did not award a 0.1–150 kg catch")
	check(not manager.fishing_ui.catch_card.visible, "Card must wait for the landing reveal")
	await create_timer(1.15).timeout
	check(manager.fishing_ui.catch_card.visible, "Local catch card was not shown after landing")
	manager.catch_fish()
	check(world.fish_inventory.get("guppy", 0) == landed_units, "Duplicate completion awarded twice")
	await process_frame
	begin_local("swordfish")
	await process_frame
	send_key(KEY_E)
	check(manager.pull_game.required_pulls == 4, "Rare fish must need four pulls")
	await process_frame
	aim(manager.pull_game)
	manager.update_minigame_visuals()
	await create_timer(.2).timeout
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = manager.fishing_ui.reel_button.get_global_rect().get_center()
	touch.pressed = true
	Input.parse_input_event(touch)
	await process_frame
	touch = touch.duplicate()
	touch.pressed = false
	Input.parse_input_event(touch)
	await process_frame
	check(manager.pull_game.pulls == 1 and manager.pull_game.misses == 0, "Touch REEL was missed or dispatched twice")
	manager.cancel_fishing()

func _test_cleanup() -> void:
	await process_frame
	begin_local()
	var old = manager.bobber
	manager.cancel_fishing()
	begin_local()
	var new_bobber = manager.bobber
	await create_timer(.3).timeout
	check(not is_instance_valid(old) and is_instance_valid(new_bobber) and manager.bobber == new_bobber, "Old cleanup erased the new bobber")
	world.blocks.clear()
	manager.update_fishing(.016)
	check(not world.fishing_active, "Removing water did not cancel the cast")
	world.blocks[world.target] = {"type": "water"}
	for reason in ["range", "world", "tool", "menu", "chat"]:
		begin_local()
		match reason:
			"range": world.player.position = Vector2(500, 500)
			"world": world.current_world_name = "OTHER"
			"tool": world.selected_item_type = "punch"
			"menu": world.menu_open = true
			"chat": world.text_focused = true
		manager.update_fishing(.016)
		check(not world.fishing_active and not manager.fishing_ui.bite_panel.visible, "Cleanup failed: " + reason)
		world.player.position = Vector2(32, 32)
		world.current_world_name = "FISHING_TEST"
		world.selected_item_type = "bamboo_fishing_rod"
		world.menu_open = false
		world.text_focused = false
	begin_local()
	manager.update_fishing(3.1)
	check(not world.fishing_active, "Missed bite did not reset cast")

func cast_reply(request_id: String, session := "test-session") -> Dictionary:
	return {"action": "fishing_start", "ok": true, "request_id": request_id, "session_id": session, "target_x": 2, "target_y": 1, "lure_id": "bait", "item_id": "guppy", "item_category": "fish", "difficulty": 1}

func _test_network_lifecycle() -> void:
	network.online = true
	world.authoritative = true
	manager.start_cast(world.target, "bait")
	var request: String = manager.cast_request_id
	var count: int = network.requests.size()
	manager.start_cast(world.target, "bait")
	check(network.requests.size() == count, "Second cast sent while acknowledgement was pending")
	manager.cancel_fishing()
	manager.handle_inventory_transaction_result(cast_reply(request))
	check(not world.fishing_active and network.requests.back().success == false, "Late cancelled cast reopened fishing")
	manager.start_cast(world.target, "bait")
	request = manager.cast_request_id
	manager.update_fishing(8.1)
	check(not manager.is_fishing_active(), "Cast acknowledgement timeout left fishing locked")
	manager.handle_inventory_transaction_result(cast_reply(request, "timeout-session"))
	check(not world.fishing_active, "Timed-out cast reopened fishing")
	manager.start_cast(world.target, "bait")
	request = manager.cast_request_id
	world.current_world_name = "OTHER"
	manager.handle_inventory_transaction_result(cast_reply(request, "old-world-session"))
	check(not world.fishing_active, "Old world cast started in new world")
	world.current_world_name = "FISHING_TEST"
	manager.start_cast(world.target, "bait")
	request = manager.cast_request_id
	var bait: int = world.lure_inventory.bait
	var reply := cast_reply(request, "good-session")
	manager.handle_inventory_transaction_result(reply)
	var bobber = manager.bobber
	manager.handle_inventory_transaction_result(reply)
	check(manager.bobber == bobber and world.lure_inventory.bait == bait, "Ack restarted cast or charged client bait twice")
	manager.update_fishing(.4)
	manager.update_fishing(6)
	manager.start_minigame()
	for _i in range(3):
		aim(manager.pull_game)
		manager.try_finish_minigame()
	check(manager.waiting_for_server_catch and not world.fishing_active, "Catch did not wait for server")
	var complete: Dictionary = network.requests.back()
	check(complete.success == true and complete.session_id == "good-session", "Wrong success/session sent")
	count = network.requests.size()
	manager.start_cast(world.target, "bait")
	check(network.requests.size() == count, "New cast raced pending reward")
	manager.update_fishing(12.1)
	check(not manager.is_fishing_active(), "Lost reward acknowledgement locked fishing forever")
	manager.start_cast(world.target, "bait")
	request = manager.cast_request_id
	manager.handle_inventory_transaction_result(cast_reply(request, "new-session"))
	var reward := {"action": "fishing_complete", "ok": true, "request_id": complete.request_id, "fish_id": "guppy", "item_id": "guppy", "item_category": "fish", "catch_weight": 1.0, "message": "Caught Guppy"}
	var before: int = world.fish_inventory.get("guppy", 0)
	manager.handle_inventory_transaction_result(reward)
	manager.handle_inventory_transaction_result(reward)
	check(world.fish_inventory.guppy == before + 10, "Duplicate reward applied twice")
	check(manager.state == "casting" and manager.fishing_ui.waiting_panel.visible, "Late reward hid the new cast")
	manager.cancel_fishing()
	manager.handle_inventory_transaction_result({"action":"fishing_complete", "ok":true, "request_id": manager.catch_request_id})

func _test_wooden_rod_phone_cast() -> void:
	world.equipped_tool = "wooden_fishing_rod"
	for dimensions in [Vector2i(1080, 2340), Vector2i(2340, 1080)]:
		root.size = dimensions
		await process_frame
		for selection in ["wooden_fishing_rod", "bait"]:
			world.selected_item_type = selection
			world.selected_item_category = "lure" if selection == "bait" else "tool"
			if selection == "bait":
				manager.use_selected_lure_at_mouse()
			else:
				manager.use_fishing_rod_at_mouse()
			var request: String = manager.cast_request_id
			check(manager.awaiting_cast_ack and network.requests.back().rod_id == "wooden_fishing_rod", "Wooden rod must send an authoritative cast from rod or bait selection")
			manager.update_fishing(0.8)
			manager.handle_inventory_transaction_result(cast_reply(request, "wooden-" + request))
			manager.update_fishing(0.4)
			check(manager.state == "waiting" and manager.bobber != null and manager.fishing_line.visible, "Accepted wooden rod cast must show its line on a phone viewport")
			manager.cancel_fishing()
			manager.handle_inventory_transaction_result({"action":"fishing_complete", "ok":true, "request_id":manager.catch_request_id})
	world.selected_item_type = "wooden_fishing_rod"
	world.selected_item_category = "tool"
	manager.use_fishing_rod_at_mouse()
	manager.handle_inventory_transaction_result({"action":"fishing_start", "ok":false, "request_id":manager.cast_request_id, "message":"Cast the fishing rod on water."})
	check(not manager.is_fishing_active() and world.notifications.back() == "Cast the fishing rod on water.", "Rejected wooden rod cast must replace the casting notice and allow a retry")
	world.selected_item_type = "bamboo_fishing_rod"
	world.equipped_tool = "bamboo_fishing_rod"
	root.size = Vector2i(1280, 720)
	await process_frame


func _test_cast_context_changes() -> void:
	for reason in ["menu", "keyboard", "selection", "distance", "water", "rod"]:
		world.menu_open = false
		world.text_focused = false
		world.selected_item_type = "bait"
		world.selected_item_category = "lure"
		world.equipped_tool = "bamboo_fishing_rod"
		world.lure_inventory.bait = 20
		world.player.position = Vector2(32, 32)
		world.blocks[world.target] = {"type": "water"}
		manager.start_cast(world.target, "bait")
		var request: String = manager.cast_request_id
		check(world.notifications.back().begins_with("Casting"), "Cast did not announce pending response")
		match reason:
			"menu": world.menu_open = true
			"keyboard": world.text_focused = true
			"selection": world.selected_item_type = "different_bait"
			"distance": world.player.position = Vector2(900, 900)
			"water": world.blocks.clear()
			"rod": world.equipped_tool = "punch"
		manager.handle_inventory_transaction_result(cast_reply(request, reason + "-session"))
		check(not manager.is_fishing_active(), "Rejected context left fishing busy: " + reason)
		check(not world.notifications.back().begins_with("Casting"), "Cancelled cast left misleading Casting notice: " + reason)
		check(network.requests.back().action == "fishing_complete" and network.requests.back().success == false, "Cancelled context did not release paid session: " + reason)
		check(world.lure_inventory.bait == 20, "Client charged/refunded bait on context cancellation")
	world.menu_open = false
	world.text_focused = false
	world.selected_item_type = "bamboo_fishing_rod"
	world.selected_item_category = "tool"
	world.equipped_tool = "bamboo_fishing_rod"
	world.player.position = Vector2(32, 32)
	world.blocks[world.target] = {"type": "water"}


func _test_cast_viewport_changes() -> void:
	# Foldable/multi-window changes can resize the viewport between request and
	# acknowledgement. World-space fishing targets must survive those changes.
	for dimensions in [Vector2i(1080, 2640), Vector2i(2640, 1080), Vector2i(720, 900), Vector2i(900, 720)]:
		manager.start_cast(world.target, "bait")
		var request: String = manager.cast_request_id
		root.size = dimensions
		await process_frame
		manager.update_fishing(0.2)
		manager.handle_inventory_transaction_result(cast_reply(request, "resize-session-" + request))
		check(world.fishing_active and manager.bobber != null, "Viewport change discarded accepted cast")
		for _frame in range(6):
			manager.update_fishing(1.0 / 15.0)
		check(manager.state == "waiting", "15 FPS cast never reached waiting state")
		root.size = Vector2i(dimensions.y, dimensions.x)
		await process_frame
		manager.update_fishing(0.1)
		check(world.fishing_active and manager.fishing_line.visible, "Active fishing lost its line after resize")
		manager.cancel_fishing()
		manager.handle_inventory_transaction_result({"action":"fishing_complete", "ok":true, "request_id": manager.catch_request_id})
	root.size = Vector2i(1280, 720)
	await process_frame


func _test_layout() -> void:
	var ui = manager.fishing_ui
	for width in [320, 720, 1280]:
		root.size = Vector2i(width, 720)
		root.content_scale_size = Vector2i.ZERO
		await process_frame
		manager.pull_game.start(false)
		ui.set_reeling_reward(world.fish_textures.guppy)
		ui.show_pull_game(manager.pull_game.snapshot())
		await create_timer(.2).timeout
		var panel: Rect2 = ui.reeling_panel.get_global_rect()
		check(panel.position.x >= 0 and panel.end.x <= width + 1, "Reeling panel overflows viewport")
		check(ui.reel_button.get_global_rect().end.x <= panel.end.x, "Reel button overflows")
		check(ui.pull_zone.get_global_rect().end.x < panel.end.x, "Pull zone overflows")
		check(ui.progress_label.get_global_rect().end.x <= ui.mistakes_label.get_global_rect().position.x + 1, "Pull and miss counters overlap")
		check(ui.reel_hint.get_minimum_size().x <= ui.reel_hint.size.x, "Reel instructions overflow on narrow screens")
		for cursor in [0.0, 0.5, 1.0]:
			ui.pull_state["cursor"] = cursor
			ui._layout_reeling_panel()
			var expected_x: float = 6.0 + (ui.pull_track.size.x - 12.0) * cursor
			check(is_equal_approx(ui.pull_marker.position.x + ui.pull_marker.size.x * 0.5, expected_x), "Displayed cursor must match authoritative timing")
		ui.show_waiting("Worm Lure")
		check_fits(ui.waiting_panel, Vector2(width, 720))
		ui.show_bite(3.0)
		ui.update_bite_timer(2.0, 3.0)
		ui._update_bite_timer(.5)
		check(is_equal_approx(ui.bite_time_left, 2.0), "UI advanced the manager's bite countdown twice")
		check_fits(ui.bite_panel, Vector2(width, 720))
		check(ui.bite_panel.get_node("HookButton").get_global_rect().size.y >= 44.0, "Touch hook target is too small")
		ui.show_catch_result({"name":"Guppy", "rarity":"common", "amount":"x1", "value":"3"})
		await create_timer(.25).timeout
		check_fits(ui.catch_card, Vector2(width, 720))
		ui._fade_out(ui.catch_card)
		ui.show_catch_result({"name":"Guppy", "rarity":"common", "amount":"x1", "value":"3"})
		check(is_zero_approx(ui.catch_reveal_time), "New catch must restart its reveal")
		await create_timer(.25).timeout
		check(ui.catch_card.visible, "Old fade hid a newer catch")
		await create_timer(.35).timeout
		check(ui.catch_icon.scale.is_equal_approx(Vector2.ONE), "Catch artwork must settle after its entrance")
		check(is_equal_approx(ui.catch_name_label.modulate.a, 1.0), "Catch details must finish fading in")
		ui.show_escape()
		check_fits(ui.escape_panel, Vector2(width, 720))
	ui.hide_all()
	root.size = Vector2i(640, 320)
	await process_frame
	ui.show_pull_game(manager.pull_game.snapshot())
	check_fits(ui.reeling_panel, Vector2(640, 320))
	ui.hide_all()


func _test_bobber_catch_animation() -> void:
	var bobber = load("res://Scenes/fishing_bobber.tscn").instantiate()
	root.add_child(bobber)
	var animation: AnimationPlayer = bobber.get_node("AnimationPlayer")
	var sprite: Sprite2D = bobber.get_node("Sprite2D")
	animation.play("reel_success")
	for frame in range(14):
		animation.seek(frame / 60.0, true)
		check(sprite.scale.x <= 1.1 and sprite.scale.y <= 1.1, "Landing bait must never explode in size")
	check(sprite.modulate.a < 0.01, "Landing bait must fade before its deferred removal")
	check(sprite.position.y < 0, "Landing bait must lift out of the water")
	bobber.queue_free()


func check_fits(panel: Control, dimensions: Vector2) -> void:
	var rect := panel.get_global_rect()
	check(rect.position.x >= -1 and rect.position.y >= -1 and rect.end.x <= dimensions.x + 1 and rect.end.y <= dimensions.y + 1, panel.name + " overflows the viewport")


func _test_last_lure() -> void:
	world.selected_item_type = "bait"
	world.selected_item_category = "lure"
	world.lure_inventory.bait = 1
	manager.start_cast(world.target, "bait")
	var request: String = manager.cast_request_id
	# The real network manager applies inventory deltas before dispatching the ack.
	world.lure_inventory.bait = 0
	world.selected_item_type = "punch"
	world.selected_item_category = "tool"
	manager.handle_inventory_transaction_result(cast_reply(request, "last-lure"))
	manager.update_fishing(.1)
	check(world.fishing_active, "Server cast cancelled when the last selected lure was consumed")
	manager.cancel_fishing()
	manager.handle_inventory_transaction_result({"action":"fishing_complete", "ok":true, "request_id": manager.catch_request_id})
	network.online = false
	world.authoritative = false
	world.selected_item_type = "bait"
	world.selected_item_category = "lure"
	world.lure_inventory.bait = 1
	begin_local()
	world.selected_item_type = "punch"
	world.selected_item_category = "tool"
	manager.update_fishing(.1)
	check(world.fishing_active, "Local cast cancelled when the last selected lure was consumed")
	manager.cancel_fishing()
	world.selected_item_type = "bamboo_fishing_rod"
	manager.use_fishing_rod_at_mouse()
	check(not world.fishing_active, "Fishing started without bait")
	world.lure_inventory.bait = 20
	await process_frame
