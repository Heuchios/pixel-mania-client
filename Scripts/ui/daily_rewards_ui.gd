extends Control

const Style = preload("res://Scripts/ui/pixel_ui_style.gd")
const Backdrop = preload("res://Scripts/ui/daily_reward_backdrop.gd")
const GEM_TEXTURES = [preload("res://Assets/currency/medium_gem.png"), preload("res://Assets/currency/large_gem.png"), preload("res://Assets/currency/huge_gem.png")]
const GOLD = Color("ffda79")
const INK = Color("281336")
const BASE_SIZE = Vector2(900, 590)
const CARD_SIZE = Vector2(142, 174)
const CARD_STEP = 156.0

var world = null
var panel: Control
var backdrop: Control
var reel_clip: Control
var reel: Control
var status: Label
var countdown: Label
var odds: Label
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

func _ready() -> void:
	name = "DailyRewards"
	z_index = 150
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_meta("pixelmania_text_shadow", false)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel = Panel.new()
	panel.set_meta("ignore_mobile_ui_scale", true)
	panel.size = BASE_SIZE
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _box(Color("19212bf2"), Color("6c7888"), 3))
	add_child(panel)
	backdrop = Backdrop.new()
	panel.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label(panel, "DAILY REWARDS", Rect2(80, 18, 740, 55), 38, GOLD)
	_label(panel, "A LITTLE LUCK. EVERY DAY.", Rect2(80, 80, 740, 30), 18, Color("bac8d8"))
	close_button = _button(panel, "X", Rect2(836, 18, 48, 48), close_rewards)
	Style.apply_close_button(close_button)
	reel_frame = Panel.new()
	reel_frame.position = Vector2(40, 140)
	reel_frame.size = Vector2(820, 202)
	reel_frame.add_theme_stylebox_override("panel", _box(Color("0e141c"), Color("6c7888"), 3, 0, 0))
	panel.add_child(reel_frame)
	reel_clip = Control.new()
	reel_clip.position = Vector2(8, 10)
	reel_clip.size = Vector2(804, 182)
	reel_clip.clip_contents = true
	reel_frame.add_child(reel_clip)
	reel = Control.new()
	reel_clip.add_child(reel)
	marker = _label(panel, "▼", Rect2(425, 110, 50, 38), 34, GOLD)
	var line := Panel.new()
	line.add_theme_stylebox_override("panel", _box(Color.TRANSPARENT, GOLD, 2))
	line.position = Vector2(450 - CARD_SIZE.x * 0.5 - 3, 150)
	line.size = CARD_SIZE + Vector2(6, 8)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(line)
	line.name = "SelectionLine"
	status = _label(panel, "CHECKING YOUR DAILY BOX...", Rect2(30, 363, 840, 40), 24, GOLD)
	odds = _label(panel, "", Rect2(20, 410, 860, 36), 18, Color("c4d0dd"))
	action_button = _button(panel, "PLEASE WAIT", Rect2(290, 468, 320, 60), _activate)
	countdown = _label(panel, "Free once a day · Resets at 00:00 UTC", Rect2(40, 545, 820, 28), 17, Color("a4b2c2"))
	prize_icon = TextureRect.new()
	prize_icon.position = Vector2(354, 148)
	prize_icon.size = Vector2(192, 176)
	prize_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	prize_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	prize_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(prize_icon)
	prize_name = _label(panel, "", Rect2(40, 340, 820, 54), 36, GOLD)
	prize_note = _label(panel, "Added to your gems", Rect2(40, 403, 820, 30), 20, Color("c4d0dd"))
	resized.connect(_fit)
	_fit()
	_set_phase("loading")
	hide()

func setup(parent_world) -> void:
	world = parent_world

func _box(fill: Color, border: Color, width: int = 3, _radius: int = 0, _shadow: int = 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.shadow_color = Color(0.03, 0.01, 0.08, 0.5)
	box.shadow_size = 4 if fill.a > 0 else 0
	box.shadow_offset = Vector2(0, 4)
	return box

func _label(parent: Node, text: String, rect: Rect2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.set_meta("pixelmania_font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, rect: Rect2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_size_override("font_size", 24)
	button.set_meta("pixelmania_font_size", 24)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var fill := Color("eab65b") if state == "normal" else Color("ffda79")
		if state == "disabled": fill = Color("465466")
		button.add_theme_stylebox_override(state, _box(fill, Color("96632f"), 3, 0, 0))
		button.add_theme_color_override("font_" + state + "_color", INK)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_disabled_color", Color("bcaaca"))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _fit() -> void:
	if panel == null: return
	var factor := minf(0.9, minf(size.x * 0.85 / BASE_SIZE.x, size.y * 0.74 / BASE_SIZE.y))
	panel.scale = Vector2.ONE * maxf(0.1, factor)
	panel.position = (size - BASE_SIZE * panel.scale) * 0.5

func open_rewards() -> void:
	if world != null and not world.in_world: return
	opened_world = str(world.current_world_name) if world != null else ""
	show()
	backdrop.set_process(true)
	_fit()
	if not snapshot.is_empty() and int(snapshot.get("reset_at", 0)) <= Time.get_ticks_msec() + clock_offset and phase != "spinning" and pending_id.is_empty():
		_request("daily_reward_status")
		return
	if phase in ["spinning", "result", "reveal"]: return
	if not pending_id.is_empty(): return
	_request("daily_reward_status")

func close_rewards() -> void:
	hide()
	backdrop.set_process(false)
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
	var parts := PackedStringArray()
	for reward in rewards:
		parts.append("%s  %s%%" % [str(reward.get("name", "")), str(reward.get("chance", 0))])
	odds.text = "   ·   ".join(parts)
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
		if i == 36 and not winner.is_empty(): reward = winner
		var card := Panel.new()
		card.position = Vector2(i * CARD_STEP, 4)
		card.size = CARD_SIZE
		var color := Color("315da5")
		if int(reward.get("gems", 0)) >= 1000: color = Color("7946a4")
		if int(reward.get("gems", 0)) >= 5000: color = Color("a86d2b")
		card.add_theme_stylebox_override("panel", _box(color, color.lightened(0.35), 3, 0, 0))
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		reel.add_child(card)
		_label(card, str(reward.get("rarity", "")), Rect2(3, 11, 136, 22), 14, Color("e6d9f4"))
		var icon := TextureRect.new()
		icon.texture = _texture(reward)
		icon.position = Vector2(35, 46)
		icon.size = Vector2(72, 72)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(icon)
		_label(card, str(reward.get("name", "")), Rect2(3, 132, 136, 29), 18, Color.WHITE)
	reel.position = Vector2(reel_clip.size.x * 0.5 - CARD_SIZE.x * 0.5 - CARD_STEP * 2.0, 0)

func _start_spin(reward: Dictionary) -> void:
	if reward.is_empty():
		_set_phase("error")
		status.text = "Check your saved reward."
		return
	winning_reward = reward.duplicate(true)
	_build_reel(snapshot.get("rewards", []), reward)
	_set_phase("spinning")
	spin_tween = create_tween()
	var target := reel_clip.size.x * 0.5 - CARD_SIZE.x * 0.5 - CARD_STEP * 36.0
	spin_tween.tween_property(reel, "position:x", target, 5.2).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	spin_tween.tween_callback(_finish_spin)

func _finish_spin() -> void:
	_set_phase("result")
	status.text = "YOU WON " + str(winning_reward.get("name", "GEMS")) + "!"
	var winner = reel.get_child(36) if reel.get_child_count() > 36 else null
	if winner != null:
		winner.add_theme_stylebox_override("panel", _box(Color("76549b"), GOLD, 4, 0, 0))

func _set_phase(value: String) -> void:
	phase = value
	var reveal := phase == "reveal"
	prize_icon.visible = reveal
	prize_name.visible = reveal
	prize_note.visible = reveal
	reel_frame.visible = not reveal
	marker.visible = not reveal
	panel.get_node("SelectionLine").visible = not reveal
	status.visible = not reveal
	odds.visible = not reveal
	backdrop.celebration = phase in ["result", "reveal"]
	backdrop.queue_redraw()
	action_button.disabled = phase in ["loading", "spinning"]
	match phase:
		"ready":
			status.text = "YOUR FREE DAILY BOX IS READY!"
			action_button.text = "OPEN DAILY BOX"
		"loading": action_button.text = "PLEASE WAIT"
		"spinning":
			status.text = "GOOD LUCK!"
			action_button.text = "OPENING..."
		"result": action_button.text = "COLLECT"
		"reveal": action_button.text = "CONTINUE"
		"claimed": action_button.text = "COME BACK TOMORROW"
		"error": action_button.text = "CHECK REWARD"

func _activate() -> void:
	match phase:
		"ready": _request("daily_reward_claim")
		"error": _request("daily_reward_status")
		"result":
			prize_icon.texture = _texture(winning_reward)
			prize_name.text = str(winning_reward.get("name", "GEMS"))
			_set_phase("reveal")
		"reveal", "claimed":
			_set_phase("claimed")
			close_rewards()

func _update_hud(seconds: int = -1) -> void:
	if not is_instance_valid(hud_button): return
	var ready := bool(snapshot.get("can_claim", false)) or seconds == 0
	hud_button.text = "DAILY REWARDS  !" if ready else "DAILY REWARDS"
	hud_button.tooltip_text = "Your free daily box is ready!" if ready else "Open daily rewards to see your next free box."
