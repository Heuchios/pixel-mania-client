extends Control

const Style = preload("res://Scripts/ui/pixel_ui_style.gd")
const Backdrop = preload("res://Scripts/ui/daily_reward_backdrop.gd")
const GEM_TEXTURES = [preload("res://Assets/currency/medium_gem.png"), preload("res://Assets/currency/large_gem.png"), preload("res://Assets/currency/huge_gem.png")]
const GOLD = Color("ffda79")
const INK = Color("281336")
const BASE_SIZE = Vector2(900, 550)
const CARD_SIZE = Vector2(150, 174)
const CARD_STEP = 164.0

var world = null
var panel: Control
var backdrop: Control
var reel_clip: Control
var reel: Control
var status: Label
var countdown: Label
var action_button: Button
var close_button: Button
var prize_icon: TextureRect
var prize_name: Label
var prize_note: Label
var reel_frame: Panel
var marker: Label
var snapshot: Dictionary = {}
var pending_id := ""
var pending_action := ""
var pending_at := 0
var clock_offset := 0
var phase := "loading"
var spin_tween: Tween
var refresh_at := 0
var sequence := 0
var winning_reward: Dictionary = {}
var hud_button: Button
var opened_world := ""
var reveal_tween: Tween
var prize_tween: Tween
var collection_tween: Tween
var collection_fx: Control
var prize_rarity: Label
var prize_stage: Panel
var spin_index := -1
var visual_rng := RandomNumberGenerator.new()

func _ready() -> void:
	name = "DailyRewards"
	z_index = 150
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_meta("pixelmania_text_shadow", false)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visual_rng.randomize()
	panel = Panel.new()
	panel.set_meta("ignore_mobile_ui_scale", true)
	panel.size = BASE_SIZE
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", Style.panel_style())
	add_child(panel)
	_label(panel, "DAILY REWARDS", Rect2(80, 18, 740, 55), INK, "header")
	_label(panel, "A FREE BOX. A LITTLE LUCK. EVERY DAY.", Rect2(60, 76, 780, 34), INK)
	close_button = _button(panel, "X", Rect2(836, 18, 48, 48), close_rewards)
	Style.apply_close_button(close_button)
	reel_frame = Panel.new()
	reel_frame.position = Vector2(40, 140)
	reel_frame.size = Vector2(820, 202)
	reel_frame.add_theme_stylebox_override("panel", Style.atlas_style("input_field"))
	panel.add_child(reel_frame)
	reel_clip = Control.new()
	reel_clip.position = Vector2(8, 10)
	reel_clip.size = Vector2(804, 182)
	reel_clip.clip_contents = true
	reel_frame.add_child(reel_clip)
	reel = Control.new()
	reel_clip.add_child(reel)
	marker = _label(panel, "▼", Rect2(425, 110, 50, 38), GOLD, "icon")
	marker.add_theme_font_size_override("font_size", 34)
	var line := Panel.new()
	var selection_style := Style.atlas_style("inv_slot_selected_1")
	# Keep the atlas corners at pixel size so they do not cover the prize text.
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		selection_style.set_texture_margin(side, 8)
	line.add_theme_stylebox_override("panel", selection_style)
	line.position = Vector2(450 - CARD_SIZE.x * 0.5 - 3, 150)
	line.size = CARD_SIZE + Vector2(6, 8)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(line)
	line.name = "SelectionLine"
	status = _label(panel, "CHECKING YOUR DAILY BOX...", Rect2(30, 363, 840, 40), INK)
	action_button = _button(panel, "PLEASE WAIT", Rect2(290, 428, 320, 60), _activate)
	countdown = _label(panel, "Free once a day · Resets at 00:00 UTC", Rect2(40, 499, 820, 36), INK)
	prize_stage = Panel.new()
	prize_stage.position = reel_frame.position
	prize_stage.size = reel_frame.size
	prize_stage.add_theme_stylebox_override("panel", Style.atlas_style("input_field"))
	prize_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(prize_stage)
	backdrop = Backdrop.new()
	panel.add_child(backdrop)
	backdrop.position = Vector2(32, 120)
	backdrop.size = Vector2(836, 300)
	backdrop.clip_contents = true
	prize_rarity = _label(panel, "", Rect2(40, 110, 820, 36), INK)
	prize_icon = TextureRect.new()
	prize_icon.position = Vector2(354, 148)
	prize_icon.size = Vector2(192, 176)
	prize_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	prize_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	prize_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prize_icon.pivot_offset = prize_icon.size * 0.5
	panel.add_child(prize_icon)
	prize_name = _label(panel, "", Rect2(40, 340, 820, 54), INK, "header")
	prize_note = _label(panel, "Added to your gems", Rect2(40, 390, 820, 34), INK)
	collection_fx = Backdrop.new()
	add_child(collection_fx)
	collection_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	collection_fx.hide()
	resized.connect(_fit)
	_fit()
	_set_phase("loading")
	hide()

func setup(parent_world) -> void:
	world = parent_world

func _label(parent: Node, text: String, rect: Rect2, color: Color, role: String = "body") -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_meta(Style.GLOBAL_FONT_ROLE_META, role)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	Style.apply_global_typography_to_node(label)
	return label

func _button(parent: Node, text: String, rect: Rect2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.set_meta(Style.GLOBAL_FONT_ROLE_META, "body")
	Style.apply_green_button(button)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _fit() -> void:
	if panel == null: return
	var factor := minf(1.0, minf(size.x * 0.85 / BASE_SIZE.x, size.y * 0.74 / BASE_SIZE.y))
	panel.scale = Vector2.ONE * maxf(0.1, factor)
	panel.position = (size - BASE_SIZE * panel.scale) * 0.5

func open_rewards() -> void:
	if world != null and not world.in_world: return
	opened_world = str(world.current_world_name) if world != null else ""
	show()
	panel.visible = phase != "collecting"
	_fit()
	if not snapshot.is_empty() and int(snapshot.get("reset_at", 0)) <= Time.get_ticks_msec() + clock_offset and phase != "spinning" and pending_id.is_empty():
		_request("daily_reward_status")
		return
	if phase in ["spinning", "result", "reveal", "collecting"]: return
	if not pending_id.is_empty(): return
	_request("daily_reward_status")

func close_rewards() -> void:
	hide()
	if phase == "collecting":
		if collection_tween != null: collection_tween.kill()
		_set_phase("claimed")
	if world != null and world.has_method("clear_mobile_pointer_screen_position"):
		world.clear_mobile_pointer_screen_position()

func is_rewards_open() -> bool:
	return visible

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_rewards()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if visible and world != null and (not world.in_world or str(world.current_world_name) != opened_world):
		close_rewards()
	if visible and phase == "spinning":
		var selected := roundi((reel_clip.size.x * 0.5 - reel.position.x - CARD_SIZE.x * 0.5) / CARD_STEP)
		if selected != spin_index:
			spin_index = selected
			backdrop.tick()
			marker.scale = Vector2(1.18, 1.18)
		marker.scale = marker.scale.lerp(Vector2.ONE, minf(1, _delta * 14))
	if not pending_id.is_empty() and Time.get_ticks_msec() - pending_at > 12000:
		pending_id = ""
		_set_phase("error")
		status.text = "Connection delayed. Check your saved reward."
	if snapshot.is_empty(): return
	var seconds := maxi(0, ceili((int(snapshot.get("reset_at", 0)) - Time.get_ticks_msec() - clock_offset) / 1000.0))
	if not bool(snapshot.get("can_claim", false)):
		countdown.text = "Next free box in %02d:%02d:%02d" % [int(seconds / 3600.0), int(seconds / 60.0) % 60, seconds % 60]
	if visible and seconds == 0 and pending_id.is_empty() and phase in ["ready", "claimed"] and Time.get_ticks_msec() >= refresh_at:
		refresh_at = Time.get_ticks_msec() + 15000
		_request("daily_reward_status")
	_update_hud(seconds)

func _request(action: String) -> void:
	if not pending_id.is_empty(): return
	sequence += 1
	pending_id = "daily_%s_%s" % [Time.get_ticks_usec(), sequence]
	pending_action = action
	pending_at = Time.get_ticks_msec()
	_set_phase("loading")
	status.text = "OPENING YOUR DAILY BOX..." if action == "daily_reward_claim" else "CHECKING YOUR DAILY BOX..."
	var packet := {"action": action, "request_id": pending_id, "reward_day": int(snapshot.get("day", -1))}
	var network = get_node_or_null("/root/NetworkManager")
	if network == null or not network.send_inventory_transaction_request(packet):
		pending_id = ""
		_set_phase("error")
		status.text = "Connect to the game server to open your box."

func handle_inventory_transaction_result(data: Dictionary) -> bool:
	if not str(data.get("action", "")).begins_with("daily_reward_"): return false
	if pending_id.is_empty() or str(data.get("request_id", "")) != pending_id: return true
	pending_id = ""
	var incoming = data.get("daily_reward")
	if incoming is Dictionary and not incoming.is_empty():
		load_snapshot(incoming)
	if not bool(data.get("ok", false)):
		_set_phase("error")
		status.text = str(data.get("message", "Please try again."))
		return true
	if pending_action == "daily_reward_claim" and not bool(data.get("already_claimed", false)):
		_start_spin(snapshot.get("reward", {}))
	return true

func load_snapshot(data: Dictionary) -> void:
	snapshot = data.duplicate(true)
	clock_offset = int(snapshot.get("server_time", 0)) - Time.get_ticks_msec()
	var rewards: Array = snapshot.get("rewards", [])
	_build_reel(rewards)
	_set_phase("ready" if bool(snapshot.get("can_claim", false)) and not rewards.is_empty() else "claimed")
	if phase == "claimed":
		var reward = snapshot.get("reward", {})
		status.text = "TODAY'S REWARD: " + str(reward.get("name", "CLAIMED")) if reward is Dictionary else "TODAY'S REWARD CLAIMED"
	countdown.text = "Free once a day · Resets at 00:00 UTC"
	_update_hud()

func _texture(reward: Dictionary) -> Texture2D:
	var amount := int(reward.get("gems", 0))
	return GEM_TEXTURES[2 if amount >= 5000 else (1 if amount >= 1000 else 0)]

func _build_reel(rewards: Array, winner: Dictionary = {}) -> void:
	for child in reel.get_children():
		reel.remove_child(child)
		child.queue_free()
	if rewards.is_empty(): return
	var count := 42 if not winner.is_empty() else 7
	for i in range(count):
		var reward: Dictionary = rewards[(i * 7 + int(i / 3.0)) % rewards.size()]
		if not winner.is_empty(): reward = _visual_reward(rewards)
		if i == 36 and not winner.is_empty(): reward = winner
		var card := Panel.new()
		card.position = Vector2(i * CARD_STEP, 4)
		card.size = CARD_SIZE
		var rarity := "common"
		if int(reward.get("gems", 0)) >= 1000: rarity = "rare"
		if int(reward.get("gems", 0)) >= 5000: rarity = "legendary"
		card.add_theme_stylebox_override("panel", Style.slot_style(rarity))
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		reel.add_child(card)
		_label(card, str(reward.get("rarity", "")), Rect2(3, 8, 144, 32), Color("e6d9f4"))
		var icon := TextureRect.new()
		icon.texture = _texture(reward)
		icon.position = Vector2((CARD_SIZE.x - 72) * 0.5, 46)
		icon.size = Vector2(72, 72)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(icon)
		_label(card, str(reward.get("name", "")), Rect2(3, 130, 144, 32), Color.WHITE)
	reel.position = Vector2(reel_clip.size.x * 0.5 - CARD_SIZE.x * 0.5 - CARD_STEP * 2.0, 0)

func _visual_reward(rewards: Array) -> Dictionary:
	var total := 0.0
	for reward in rewards: total += maxf(0, float(reward.get("chance", 0)))
	var roll := visual_rng.randf() * total
	for reward in rewards:
		roll -= maxf(0, float(reward.get("chance", 0)))
		if roll < 0: return reward
	return rewards[0]

func _start_spin(reward: Dictionary) -> void:
	if reward.is_empty():
		_set_phase("error")
		status.text = "Check your saved reward."
		return
	winning_reward = reward.duplicate(true)
	_build_reel(snapshot.get("rewards", []), reward)
	_set_phase("spinning")
	spin_index = -1
	spin_tween = create_tween()
	var target := reel_clip.size.x * 0.5 - CARD_SIZE.x * 0.5 - CARD_STEP * 36.0
	spin_tween.tween_property(reel, "position:x", target + CARD_STEP * 3.25, 2.3).set_trans(Tween.TRANS_LINEAR)
	spin_tween.tween_property(reel, "position:x", target, 2.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	spin_tween.tween_callback(_finish_spin)

func _finish_spin() -> void:
	_set_phase("result")
	status.text = "YOU WON " + str(winning_reward.get("name", "GEMS")) + "!"
	var winner = reel.get_child(36) if reel.get_child_count() > 36 else null
	if winner != null:
		winner.add_theme_stylebox_override("panel", Style.slot_style("legendary"))
	reveal_tween = create_tween()
	reveal_tween.tween_interval(0.55)
	reveal_tween.tween_callback(_reveal_reward)

func _reveal_reward() -> void:
	if phase != "result": return
	if reveal_tween != null: reveal_tween.kill()
	prize_icon.texture = _texture(winning_reward)
	prize_rarity.text = str(winning_reward.get("rarity", "")) + " REWARD!"
	_set_phase("reveal")
	prize_icon.scale = Vector2.ONE * 0.45
	prize_tween = create_tween().set_parallel(true)
	prize_tween.tween_property(prize_icon, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	prize_tween.tween_method(_show_prize_amount, 0, int(winning_reward.get("gems", 0)), 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if visible and world != null and is_instance_valid(world.sound_manager):
		world.sound_manager.play_vend_purchase()

func _show_prize_amount(amount: int) -> void:
	prize_name.text = (str(amount) if amount < 1000 else "%d,%03d" % [int(amount / 1000.0), amount % 1000]) + " GEMS"

func _collect_reward() -> void:
	var origin := prize_icon.get_global_rect().get_center() - global_position
	var target := Vector2(40, 34)
	if world != null and is_instance_valid(world.inventory_manager) and is_instance_valid(world.inventory_manager.gem_panel):
		var gem_bounds: Rect2 = world.inventory_manager.gem_panel.get_global_rect()
		target = gem_bounds.position + Vector2(24, gem_bounds.size.y * 0.5) - global_position
	_set_phase("collecting")
	collection_fx.collect(origin, target, _texture(winning_reward))
	collection_tween = create_tween()
	collection_tween.tween_interval(1.0)
	collection_tween.tween_callback(func():
		_set_phase("claimed")
		close_rewards())

func _set_phase(value: String) -> void:
	phase = value
	panel.visible = phase != "collecting"
	collection_fx.visible = phase == "collecting"
	var reveal := phase == "reveal"
	prize_icon.visible = reveal
	prize_name.visible = reveal
	prize_note.visible = reveal
	prize_rarity.visible = reveal
	prize_stage.visible = reveal
	reel_frame.visible = not reveal
	marker.visible = not reveal
	panel.get_node("SelectionLine").visible = not reveal
	status.visible = not reveal
	marker.scale = Vector2.ONE
	backdrop.set_mode("celebrate" if phase == "reveal" else ("spin" if phase == "spinning" else "idle"), winning_reward, _texture(winning_reward))
	action_button.disabled = phase in ["loading", "spinning"]
	match phase:
		"ready":
			status.text = "YOUR FREE DAILY BOX IS READY!"
			action_button.text = "OPEN DAILY BOX"
		"loading": action_button.text = "PLEASE WAIT"
		"spinning":
			status.text = "GOOD LUCK!"
			action_button.text = "OPENING..."
		"result": action_button.text = "REVEAL REWARD"
		"reveal": action_button.text = "COLLECT"
		"claimed": action_button.text = "COME BACK TOMORROW"
		"error": action_button.text = "CHECK REWARD"

func _activate() -> void:
	match phase:
		"ready": _request("daily_reward_claim")
		"error": _request("daily_reward_status")
		"result": _reveal_reward()
		"reveal": _collect_reward()
		"claimed":
			_set_phase("claimed")
			close_rewards()

func _update_hud(seconds: int = -1) -> void:
	if not is_instance_valid(hud_button): return
	var ready := bool(snapshot.get("can_claim", false)) or seconds == 0
	hud_button.tooltip_text = "Your free daily box is ready!" if ready else "Open daily rewards to see your next free box."
