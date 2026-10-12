extends Control

const Style = preload("res://Scripts/ui/pixel_ui_style.gd")
const Backdrop = preload("res://Scripts/ui/daily_reward_backdrop.gd")
const Roulette = preload("res://Scripts/ui/daily_reward_roulette.gd")
const GEM_TEXTURES = [preload("res://Assets/currency/medium_gem.png"), preload("res://Assets/currency/large_gem.png"), preload("res://Assets/currency/huge_gem.png")]
const GOLD = Color("ffda79")
const INK = Color("281336")
const BASE_SIZE = Vector2(900, 550)
const SPIN_DURATION := 6.2

var world = null
var panel: Control
var backdrop: Control
var wheel: Control
var status: Label
var countdown: Label
var action_button: Button
var close_button: Button
var prize_icon: TextureRect
var prize_name: Label
var prize_note: Label
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
var wheel_legend: Label
var tick_player: AudioStreamPlayer

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
	panel.add_theme_stylebox_override("panel", Style.panel_style())
	add_child(panel)
	_label(panel, "DAILY REWARDS", Rect2(80, 18, 740, 55), INK, "header")
	_label(panel, "ONE FREE SPIN. A LITTLE LUCK. EVERY DAY.", Rect2(60, 76, 780, 34), INK)
	close_button = _button(panel, "X", Rect2(836, 18, 48, 48), close_rewards)
	Style.apply_close_button(close_button)
	wheel = Roulette.new()
	wheel.position = Vector2(28, 108)
	wheel.size = Vector2(440, 388)
	wheel.scale = Vector2.ONE * 0.95
	panel.add_child(wheel)
	_create_tick_player()
	wheel.pocket_tick.connect(_on_pocket_tick)
	wheel_legend = _label(panel, "250 / 1,000 / 5,000 GEMS", Rect2(28, 478, 420, 30), INK)
	status = _label(panel, "CHECKING YOUR DAILY SPIN...", Rect2(474, 350, 388, 65), INK)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_button = _button(panel, "PLEASE WAIT", Rect2(500, 423, 340, 60), _activate)
	countdown = _label(panel, "Free once a day · Resets at 00:00 UTC", Rect2(40, 511, 820, 32), INK)
	prize_stage = Panel.new()
	prize_stage.position = Vector2(480, 130)
	prize_stage.size = Vector2(376, 216)
	prize_stage.add_theme_stylebox_override("panel", Style.slot_style("legendary"))
	prize_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(prize_stage)
	backdrop = Backdrop.new()
	panel.add_child(backdrop)
	backdrop.position = Vector2(470, 84)
	backdrop.size = Vector2(398, 304)
	backdrop.clip_contents = true
	prize_rarity = _label(panel, "DAILY JACKPOT", Rect2(486, 144, 364, 36), GOLD)
	prize_icon = TextureRect.new()
	prize_icon.position = Vector2(616, 184)
	prize_icon.size = Vector2(104, 104)
	prize_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	prize_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	prize_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prize_icon.pivot_offset = prize_icon.size * 0.5
	panel.add_child(prize_icon)
	prize_name = _label(panel, "5,000 GEMS", Rect2(486, 286, 364, 50), Color.WHITE, "header")
	prize_note = _label(panel, "Added to your gems", Rect2(474, 350, 388, 65), INK)
	_show_preview_prize()
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

func _create_tick_player() -> void:
	# A short, soft wooden click; build once and share the game's SFX volume policy.
	var samples := PackedByteArray()
	samples.resize(1600)
	for i in range(800):
		var t := i / 22050.0
		var sample := int((sin(TAU * 1600.0 * t) * 0.75 + sin(TAU * 4200.0 * t) * 0.25) * exp(-t * 190.0) * 12000.0)
		samples[i * 2] = sample & 255
		samples[i * 2 + 1] = (sample >> 8) & 255
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = 22050
	sound.data = samples
	tick_player = AudioStreamPlayer.new()
	tick_player.stream = sound
	add_child(tick_player)

func _on_pocket_tick() -> void:
	if not visible or world == null or not is_instance_valid(world.sound_manager): return
	tick_player.volume_db = world.sound_manager.get_scaled_sfx_volume_db(-12.0)
	if tick_player.volume_db <= -79.0: return
	tick_player.pitch_scale = lerpf(1.15, 0.85, wheel.progress)
	tick_player.play()

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
	tick_player.stop()
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
		var spin_status := "THE BALL IS SETTLING..." if wheel.progress > 0.78 else "GOOD LUCK!"
		if status.text != spin_status: status.text = spin_status
	if not pending_id.is_empty() and Time.get_ticks_msec() - pending_at > 12000:
		pending_id = ""
		_set_phase("error")
		status.text = "Connection delayed. Check your saved reward."
	if snapshot.is_empty(): return
	var seconds := maxi(0, ceili((int(snapshot.get("reset_at", 0)) - Time.get_ticks_msec() - clock_offset) / 1000.0))
	if not bool(snapshot.get("can_claim", false)):
		countdown.text = "Next free spin in %02d:%02d:%02d" % [int(seconds / 3600.0), int(seconds / 60.0) % 60, seconds % 60]
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
	status.text = "GETTING YOUR DAILY SPIN..." if action == "daily_reward_claim" else "CHECKING YOUR DAILY SPIN..."
	var packet := {"action": action, "request_id": pending_id, "reward_day": int(snapshot.get("day", -1))}
	var network = get_node_or_null("/root/NetworkManager")
	if network == null or not network.send_inventory_transaction_request(packet):
		pending_id = ""
		_set_phase("error")
		status.text = "Connect to the game server to spin."

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
	wheel.configure(rewards)
	_show_preview_prize()
	_set_phase("ready" if bool(snapshot.get("can_claim", false)) and not rewards.is_empty() else "claimed")
	if phase == "claimed":
		var reward = snapshot.get("reward", {})
		status.text = "TODAY'S REWARD CLAIMED"
		if reward is Dictionary and not reward.is_empty():
			winning_reward = reward.duplicate(true)
			wheel.show_saved_reward(reward)
			_show_saved_prize(reward)
	countdown.text = "Free once a day · Resets at 00:00 UTC"
	_update_hud()

func _texture(reward: Dictionary) -> Texture2D:
	var amount := int(reward.get("gems", 0))
	return GEM_TEXTURES[2 if amount >= 5000 else (1 if amount >= 1000 else 0)]

func _show_preview_prize() -> void:
	prize_icon.texture = GEM_TEXTURES[2]
	prize_icon.scale = Vector2.ONE
	prize_rarity.text = "DAILY JACKPOT"
	prize_name.text = "5,000 GEMS"
	prize_stage.add_theme_stylebox_override("panel", Style.slot_style("legendary"))

func _show_saved_prize(reward: Dictionary) -> void:
	prize_icon.texture = _texture(reward)
	prize_rarity.text = str(reward.get("rarity", "")) + " REWARD"
	_show_prize_amount(int(reward.get("gems", 0)))
	var amount := int(reward.get("gems", 0))
	prize_stage.add_theme_stylebox_override("panel", Style.slot_style("legendary" if amount >= 5000 else ("rare" if amount >= 1000 else "common")))

func _start_spin(reward: Dictionary) -> void:
	if reward.is_empty():
		_set_phase("error")
		status.text = "Check your saved reward."
		return
	winning_reward = reward.duplicate(true)
	if not wheel.begin_spin(reward):
		_set_phase("error")
		status.text = "Check your saved reward."
		return
	_show_preview_prize()
	_set_phase("spinning")
	if spin_tween != null: spin_tween.kill()
	spin_tween = create_tween()
	spin_tween.tween_method(wheel.set_spin_progress, 0.0, 1.0, SPIN_DURATION)
	spin_tween.tween_callback(_finish_spin)

func _finish_spin() -> void:
	wheel.finish_spin()
	_set_phase("result")
	status.text = "YOU WON " + str(winning_reward.get("name", "GEMS")) + "!"
	_show_saved_prize(winning_reward)
	reveal_tween = create_tween()
	reveal_tween.tween_interval(0.55)
	reveal_tween.tween_callback(_reveal_reward)

func _reveal_reward() -> void:
	if phase != "result": return
	if reveal_tween != null: reveal_tween.kill()
	_show_saved_prize(winning_reward)
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
	prize_note.visible = reveal
	status.visible = not reveal
	backdrop.set_mode("celebrate" if phase == "reveal" else ("spin" if phase == "spinning" else "idle"), winning_reward, _texture(winning_reward))
	action_button.disabled = phase in ["loading", "spinning"]
	match phase:
		"ready":
			status.text = "YOUR FREE DAILY SPIN IS READY!"
			action_button.text = "SPIN THE WHEEL"
		"loading": action_button.text = "PLEASE WAIT"
		"spinning":
			status.text = "GOOD LUCK!"
			action_button.text = "SPINNING..."
		"result": action_button.text = "REVEAL REWARD"
		"reveal": action_button.text = "COLLECT"
		"claimed":
			action_button.text = "COME BACK TOMORROW"
			status.text = "TODAY'S REWARD CLAIMED"
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
	hud_button.tooltip_text = "Your free daily spin is ready!" if ready else "Open daily rewards to see your next free spin."
