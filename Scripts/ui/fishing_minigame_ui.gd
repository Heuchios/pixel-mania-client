extends Control

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")
const FishingJournalUI = preload("res://Scripts/ui/fishing_journal_ui.gd")

const WAITING_W := 390.0
const WAITING_H := 112.0
const BITE_W := 430.0
const BITE_H := 190.0
const REEL_W := 720.0
const REEL_H := 236.0
const CATCH_W := 500.0
const CATCH_H := 410.0
const ESCAPE_W := 330.0
const ESCAPE_H := 72.0

var world = null

var waiting_panel: Panel = null
var waiting_title: Label = null
var waiting_lure: Label = null
var waiting_status: Label = null
var waiting_dot_time := 0.0
var waiting_dot_count := 0

var target_panel: Panel = null
var target_label: Label = null
var target_pulse := 0.0

var bite_panel: Panel = null
var bite_title: Label = null
var bite_hint: Label = null
var bite_bar_fill: ColorRect = null
var bite_total_time := 0.0
var bite_time_left := 0.0

var reeling_panel: Panel = null
var reeling_title: Label = null
var progress_fill: ColorRect = null
var tension_fill: ColorRect = null
var progress_label: Label = null
var tension_label: Label = null
var reel_button: Button = null
var reel_hint: Label = null
var progress_value := 0.0
var tension_value := 0.0
var progress_target := 0.0
var tension_target := 0.0
var reel_button_down := false
var reel_input_active := false

var catch_card: Panel = null
var catch_special_label: Label = null
var catch_title_label: Label = null
var catch_icon_back: Panel = null
var catch_icon: TextureRect = null
var catch_name_label: Label = null
var catch_rarity_label: Label = null
var catch_weight_label: Label = null
var catch_value_label: Label = null
var catch_new_badge: Panel = null
var catch_new_label: Label = null
var sparkle_root: Control = null
var catch_timer := 0.0

var escape_panel: Panel = null
var escape_label: Label = null
var escape_timer := 0.0
var journal_ui = null


func setup(world_ref) -> void:
	world = world_ref
	for child in get_children():
		remove_child(child)
		child.queue_free()
	name = "FishingMinigameUI"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 230
	visible = true
	size = get_viewport_rect().size
	set_process(true)
	_remove_legacy_nodes()
	_build_waiting_panel()
	_build_bite_panel()
	_build_reeling_panel()
	_build_catch_card()
	_build_escape_panel()
	_setup_journal_ui()
	hide_all()


func _process(delta: float) -> void:
	size = get_viewport_rect().size
	_position_visible_panels()
	_update_waiting_dots(delta)
	_update_target_pulse(delta)
	_update_bite_timer(delta)
	_update_reeling_bars(delta)
	_update_auto_hide(delta)


func show_waiting(lure_name: String) -> void:
	_ensure_ready()
	hide_bite()
	hide_reeling()
	if waiting_panel == null:
		return
	waiting_lure.text = lure_name
	waiting_status.text = "Waiting for bite"
	waiting_dot_time = 0.0
	waiting_dot_count = 0
	waiting_panel.visible = true
	_position_waiting_panel()
	PixelUIStyle.play_panel_open(waiting_panel, Vector2(0.94, 0.94), 0.14)


func show_bite(reaction_time: float) -> void:
	_ensure_ready()
	hide_waiting()
	hide_reeling()
	if bite_panel == null:
		return
	bite_total_time = max(0.1, reaction_time)
	bite_time_left = bite_total_time
	reel_button_down = false
	bite_bar_fill.size.x = 360.0
	bite_panel.visible = true
	_position_bite_panel()
	PixelUIStyle.play_panel_open(bite_panel, Vector2(0.82, 0.82), 0.12)
	_shake_control(bite_panel, 10.0, 0.20)


func update_bite_timer(time_left: float, total_time: float) -> void:
	bite_total_time = max(0.1, total_time)
	bite_time_left = clamp(time_left, 0.0, bite_total_time)
	_apply_bite_bar()


func show_reeling(progress: float, tension: float, is_reeling: bool = false) -> void:
	_ensure_ready()
	hide_waiting()
	hide_bite()
	if reeling_panel == null:
		return
	progress_target = clamp(progress, 0.0, 1.0)
	tension_target = clamp(tension, 0.0, 1.0)
	reel_input_active = is_reeling
	if not reeling_panel.visible:
		progress_value = progress_target
		tension_value = tension_target
		reeling_panel.visible = true
		_position_reeling_panel()
		_layout_reeling_panel()
		PixelUIStyle.play_panel_open(reeling_panel, Vector2(0.94, 0.94), 0.14)
	_update_reel_button_state()


func show_catch_result(fish_data: Dictionary) -> void:
	_ensure_ready()
	hide_fishing_state()
	if catch_card == null:
		return

	var rarity: String = str(fish_data.get("rarity", "common")).to_lower()
	var rarity_color: Color = get_rarity_color(rarity)
	var fish_name: String = str(fish_data.get("name", fish_data.get("fish_id", "Fish")))
	var amount_text: String = str(fish_data.get("amount", fish_data.get("weight", "x1")))
	var value_text: String = str(fish_data.get("value", "0"))
	var icon_value = fish_data.get("icon", null)
	var is_new: bool = bool(fish_data.get("is_new", false))

	catch_name_label.text = fish_name
	catch_rarity_label.text = rarity.capitalize()
	catch_rarity_label.add_theme_color_override("font_color", rarity_color)
	catch_weight_label.text = "Amount: " + amount_text
	catch_value_label.text = "Value: " + value_text + " gems"
	catch_icon.texture = (icon_value as Texture2D) if icon_value is Texture2D else null
	catch_icon_back.add_theme_stylebox_override("panel", PixelUIStyle.slot_style(rarity))
	catch_new_badge.visible = is_new

	var special_text: String = ""
	match rarity:
		"rare":
			special_text = "RARE CATCH!"
		"epic":
			special_text = "EPIC CATCH!"
		"legendary":
			special_text = "LEGENDARY CATCH!"

	catch_special_label.text = special_text
	catch_special_label.visible = special_text != ""
	catch_special_label.add_theme_color_override("font_color", rarity_color)

	catch_card.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.050, 0.120, 0.175, 0.86),
		rarity_color if special_text != "" else PixelUIStyle.GLASS_BORDER_BRIGHT,
		4,
		22,
		14
	))

	_show_sparkles(rarity)
	_position_catch_card()
	var final_pos: Vector2 = catch_card.position
	catch_card.position = final_pos + Vector2(0, 48)
	catch_card.modulate = Color(1.0, 1.0, 1.0, 0.0)
	catch_card.scale = Vector2(0.92, 0.92)
	catch_card.visible = true
	catch_timer = 4.8 if rarity == "legendary" else 3.9

	var tween: Tween = catch_card.create_tween()
	tween.set_parallel(true)
	tween.tween_property(catch_card, "position", final_pos, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(catch_card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(catch_card, "modulate", Color.WHITE, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if special_text != "":
		_shake_control(catch_icon_back, 5.0 if rarity != "legendary" else 7.0, 0.18)


func show_escape() -> void:
	_ensure_ready()
	hide_fishing_state()
	if escape_panel == null:
		return
	escape_label.text = "Fish escaped..."
	escape_panel.visible = true
	escape_timer = 1.8
	_position_escape_panel()
	PixelUIStyle.play_panel_open(escape_panel, Vector2(0.96, 0.96), 0.12)


func hide_all() -> void:
	hide_fishing_state()
	if catch_card != null:
		catch_card.visible = false
	if escape_panel != null:
		escape_panel.visible = false
	catch_timer = 0.0
	escape_timer = 0.0
	reel_button_down = false


func open_journal() -> void:
	_setup_journal_ui()
	if journal_ui != null and journal_ui.has_method("open_journal"):
		journal_ui.open_journal()


func hide_fishing_state() -> void:
	hide_waiting()
	hide_bite()
	hide_reeling()
	hide_target_indicator()
	reel_button_down = false


func show_target_indicator(_grid_pos: Vector2i) -> void:
	return


func hide_target_indicator() -> void:
	if target_panel != null:
		target_panel.visible = false


func is_reel_button_down() -> bool:
	return reel_button_down


func hide_waiting() -> void:
	if waiting_panel != null:
		waiting_panel.visible = false


func hide_bite() -> void:
	if bite_panel != null:
		bite_panel.visible = false
	bite_time_left = 0.0
	bite_total_time = 0.0


func hide_reeling() -> void:
	if reeling_panel != null:
		reeling_panel.visible = false
	reel_input_active = false


func _ensure_ready() -> void:
	if waiting_panel == null:
		setup(world)


func _setup_journal_ui() -> void:
	if world == null:
		return
	if journal_ui != null and is_instance_valid(journal_ui):
		return
	journal_ui = get_node_or_null("FishingJournalUI")
	if journal_ui == null:
		journal_ui = Control.new()
		journal_ui.name = "FishingJournalUI"
		journal_ui.set_script(FishingJournalUI)
		add_child(journal_ui)
	if journal_ui != null and journal_ui.has_method("setup"):
		journal_ui.setup(world)


func _on_journal_pressed() -> void:
	open_journal()


func _remove_legacy_nodes() -> void:
	if world == null or world.ui_layer == null:
		return
	for node_name in ["FishingMinigamePanel", "FishCatchPopup"]:
		var old = world.ui_layer.get_node_or_null(node_name)
		if old != null:
			old.queue_free()


func _build_waiting_panel() -> void:
	waiting_panel = Panel.new()
	waiting_panel.name = "WaitingPanel"
	waiting_panel.size = Vector2(WAITING_W, WAITING_H)
	waiting_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	waiting_panel.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_PANEL_STRONG,
		PixelUIStyle.GLASS_BORDER_BRIGHT,
		3,
		18,
		11
	))
	add_child(waiting_panel)

	waiting_title = Label.new()
	waiting_title.text = "Fishing..."
	waiting_title.position = Vector2(22, 12)
	waiting_title.size = Vector2(WAITING_W - 44.0, 32)
	waiting_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	PixelUIStyle.apply_label_shadow(waiting_title, 24, PixelUIStyle.GOLD_SOFT)
	waiting_panel.add_child(waiting_title)

	var journal_button: Button = Button.new()
	journal_button.name = "JournalButton"
	journal_button.text = "JOURNAL"
	journal_button.position = Vector2(WAITING_W - 124.0, 16)
	journal_button.size = Vector2(96, 30)
	journal_button.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_blue_button(journal_button, 13)
	journal_button.pressed.connect(_on_journal_pressed)
	waiting_panel.add_child(journal_button)

	waiting_lure = Label.new()
	waiting_lure.position = Vector2(22, 47)
	waiting_lure.size = Vector2(WAITING_W - 44.0, 24)
	waiting_lure.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	PixelUIStyle.apply_small_label(waiting_lure, 15)
	waiting_panel.add_child(waiting_lure)

	waiting_status = Label.new()
	waiting_status.position = Vector2(22, 74)
	waiting_status.size = Vector2(WAITING_W - 44.0, 24)
	waiting_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	PixelUIStyle.apply_label_shadow(waiting_status, 17, PixelUIStyle.TEXT_SOFT)
	waiting_panel.add_child(waiting_status)


func _build_target_indicator() -> void:
	target_panel = Panel.new()
	target_panel.name = "WaterTargetIndicator"
	target_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_panel.z_index = 70
	target_panel.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(1.0, 0.82, 0.12, 0.12),
		Color(1.0, 0.84, 0.05, 0.94),
		3,
		7,
		0
	))
	add_child(target_panel)

	target_label = Label.new()
	target_label.text = "CAST"
	target_label.size = Vector2(76, 26)
	target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	target_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(target_label, 15, PixelUIStyle.GOLD_SOFT)
	target_panel.add_child(target_label)


func _build_bite_panel() -> void:
	bite_panel = Panel.new()
	bite_panel.name = "BitePanel"
	bite_panel.size = Vector2(BITE_W, BITE_H)
	bite_panel.pivot_offset = bite_panel.size * 0.5
	bite_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bite_panel.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.060, 0.135, 0.200, 0.88),
		PixelUIStyle.ACTION_YELLOW,
		4,
		22,
		15
	))
	add_child(bite_panel)

	bite_title = Label.new()
	bite_title.text = "FISH ON!"
	bite_title.position = Vector2(20, 16)
	bite_title.size = Vector2(BITE_W - 40.0, 58)
	bite_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bite_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	PixelUIStyle.apply_label_shadow(bite_title, 46, PixelUIStyle.GOLD_SOFT)
	bite_panel.add_child(bite_title)

	bite_hint = Label.new()
	bite_hint.text = "Hold click, E, Space, or the reel button"
	bite_hint.position = Vector2(24, 78)
	bite_hint.size = Vector2(BITE_W - 48.0, 26)
	bite_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bite_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	PixelUIStyle.apply_small_label(bite_hint, 15)
	bite_panel.add_child(bite_hint)

	var bar_bg: Panel = Panel.new()
	bar_bg.position = Vector2(34, 114)
	bar_bg.size = Vector2(362, 18)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_bg.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.03, 0.06, 0.09, 0.95),
		Color(0.01, 0.02, 0.03, 1.0),
		2,
		6,
		1
	))
	bite_panel.add_child(bar_bg)

	bite_bar_fill = ColorRect.new()
	bite_bar_fill.position = Vector2(35, 115)
	bite_bar_fill.size = Vector2(360, 16)
	bite_bar_fill.color = PixelUIStyle.ACTION_YELLOW
	bite_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bite_panel.add_child(bite_bar_fill)

	var hook_button: Button = Button.new()
	hook_button.name = "HookButton"
	hook_button.text = "HOLD TO HOOK"
	hook_button.position = Vector2(115, 146)
	hook_button.size = Vector2(200, 34)
	hook_button.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_yellow_button(hook_button, 15)
	hook_button.button_down.connect(_on_reel_button_down)
	hook_button.button_up.connect(_on_reel_button_up)
	bite_panel.add_child(hook_button)


func _build_reeling_panel() -> void:
	reeling_panel = Panel.new()
	reeling_panel.name = "ReelingPanel"
	reeling_panel.size = Vector2(REEL_W, REEL_H)
	reeling_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reeling_panel.add_theme_stylebox_override("panel", PixelUIStyle.premium_panel_style())
	add_child(reeling_panel)

	reeling_title = Label.new()
	reeling_title.text = "REEL STEADY"
	reeling_title.position = Vector2(28, 14)
	reeling_title.size = Vector2(320, 38)
	reeling_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	PixelUIStyle.apply_label_shadow(reeling_title, 28, PixelUIStyle.GOLD_SOFT)
	reeling_panel.add_child(reeling_title)

	var journal_button: Button = Button.new()
	journal_button.name = "JournalButton"
	journal_button.text = "JOURNAL"
	journal_button.position = Vector2(REEL_W - 142.0, 18)
	journal_button.size = Vector2(108, 34)
	journal_button.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_blue_button(journal_button, 13)
	journal_button.pressed.connect(_on_journal_pressed)
	reeling_panel.add_child(journal_button)

	reel_hint = Label.new()
	reel_hint.text = "Hold to reel. Release when tension climbs."
	reel_hint.position = Vector2(28, 52)
	reel_hint.size = Vector2(REEL_W - 56.0, 24)
	reel_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	PixelUIStyle.apply_small_label(reel_hint, 15)
	reeling_panel.add_child(reel_hint)

	progress_label = Label.new()
	progress_label.text = "Catch Progress"
	progress_label.position = Vector2(32, 86)
	progress_label.size = Vector2(210, 22)
	PixelUIStyle.apply_small_label(progress_label, 14)
	reeling_panel.add_child(progress_label)

	var progress_bg: Panel = Panel.new()
	progress_bg.name = "ProgressBg"
	progress_bg.position = Vector2(32, 112)
	progress_bg.size = Vector2(REEL_W - 64.0, 28)
	progress_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_bg.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.03, 0.06, 0.10, 0.96),
		PixelUIStyle.GLASS_BORDER,
		2,
		9,
		2
	))
	reeling_panel.add_child(progress_bg)

	progress_fill = ColorRect.new()
	progress_fill.position = Vector2(36, 116)
	progress_fill.size = Vector2(0, 20)
	progress_fill.color = Color(0.28, 0.95, 0.46, 0.92)
	progress_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reeling_panel.add_child(progress_fill)

	tension_label = Label.new()
	tension_label.text = "Line Tension"
	tension_label.position = Vector2(32, 146)
	tension_label.size = Vector2(210, 22)
	PixelUIStyle.apply_small_label(tension_label, 14)
	reeling_panel.add_child(tension_label)

	var tension_bg: Panel = Panel.new()
	tension_bg.name = "TensionBg"
	tension_bg.position = Vector2(32, 172)
	tension_bg.size = Vector2(REEL_W - 284.0, 26)
	tension_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tension_bg.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.03, 0.06, 0.10, 0.96),
		PixelUIStyle.GLASS_BORDER,
		2,
		9,
		2
	))
	reeling_panel.add_child(tension_bg)

	tension_fill = ColorRect.new()
	tension_fill.position = Vector2(36, 176)
	tension_fill.size = Vector2(0, 18)
	tension_fill.color = PixelUIStyle.GOLD_SOFT
	tension_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reeling_panel.add_child(tension_fill)

	reel_button = Button.new()
	reel_button.name = "ReelButton"
	reel_button.text = "HOLD TO REEL"
	reel_button.position = Vector2(REEL_W - 218.0, 162)
	reel_button.size = Vector2(186, 50)
	reel_button.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_yellow_button(reel_button, 18)
	reel_button.button_down.connect(_on_reel_button_down)
	reel_button.button_up.connect(_on_reel_button_up)
	reeling_panel.add_child(reel_button)


func _build_catch_card() -> void:
	catch_card = Panel.new()
	catch_card.name = "CatchRevealCard"
	catch_card.size = Vector2(CATCH_W, CATCH_H)
	catch_card.pivot_offset = catch_card.size * 0.5
	catch_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	catch_card.z_index = 240
	catch_card.add_theme_stylebox_override("panel", PixelUIStyle.premium_panel_style())
	add_child(catch_card)

	catch_special_label = Label.new()
	catch_special_label.position = Vector2(24, 14)
	catch_special_label.size = Vector2(CATCH_W - 48.0, 34)
	catch_special_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	catch_special_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	PixelUIStyle.apply_label_shadow(catch_special_label, 24, PixelUIStyle.GOLD_SOFT)
	catch_card.add_child(catch_special_label)

	catch_title_label = Label.new()
	catch_title_label.text = "FISH CAUGHT"
	catch_title_label.position = Vector2(24, 48)
	catch_title_label.size = Vector2(CATCH_W - 48.0, 42)
	catch_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	catch_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	PixelUIStyle.apply_label_shadow(catch_title_label, 32, PixelUIStyle.TEXT_LIGHT)
	catch_card.add_child(catch_title_label)

	catch_icon_back = Panel.new()
	catch_icon_back.position = Vector2(150, 104)
	catch_icon_back.size = Vector2(200, 142)
	catch_icon_back.pivot_offset = catch_icon_back.size * 0.5
	catch_icon_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	catch_icon_back.add_theme_stylebox_override("panel", PixelUIStyle.card_style_featured())
	catch_card.add_child(catch_icon_back)

	catch_icon = TextureRect.new()
	catch_icon.position = Vector2(174, 122)
	catch_icon.size = Vector2(152, 104)
	catch_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	catch_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	catch_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	catch_card.add_child(catch_icon)

	catch_new_badge = Panel.new()
	catch_new_badge.position = Vector2(328, 98)
	catch_new_badge.size = Vector2(76, 34)
	catch_new_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	catch_new_badge.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.ACTION_YELLOW,
		PixelUIStyle.ACTION_YELLOW_BORDER,
		4,
		11,
		5
	))
	catch_card.add_child(catch_new_badge)

	catch_new_label = Label.new()
	catch_new_label.text = "NEW!"
	catch_new_label.size = catch_new_badge.size
	catch_new_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	catch_new_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	PixelUIStyle.apply_label_shadow(catch_new_label, 17, Color.WHITE)
	catch_new_badge.add_child(catch_new_label)

	catch_name_label = Label.new()
	catch_name_label.position = Vector2(32, 258)
	catch_name_label.size = Vector2(CATCH_W - 64.0, 34)
	catch_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	catch_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	PixelUIStyle.apply_label_shadow(catch_name_label, 24)
	catch_card.add_child(catch_name_label)

	catch_rarity_label = Label.new()
	catch_rarity_label.position = Vector2(32, 294)
	catch_rarity_label.size = Vector2(CATCH_W - 64.0, 26)
	catch_rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	catch_rarity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	PixelUIStyle.apply_small_label(catch_rarity_label, 16)
	catch_card.add_child(catch_rarity_label)

	catch_weight_label = Label.new()
	catch_weight_label.position = Vector2(58, 338)
	catch_weight_label.size = Vector2(180, 26)
	catch_weight_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	PixelUIStyle.apply_small_label(catch_weight_label, 15)
	catch_card.add_child(catch_weight_label)

	catch_value_label = Label.new()
	catch_value_label.position = Vector2(262, 338)
	catch_value_label.size = Vector2(180, 26)
	catch_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	catch_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	PixelUIStyle.apply_small_label(catch_value_label, 15)
	catch_card.add_child(catch_value_label)

	var journal_button: Button = Button.new()
	journal_button.name = "JournalButton"
	journal_button.text = "OPEN JOURNAL"
	journal_button.position = Vector2(165, 370)
	journal_button.size = Vector2(170, 30)
	journal_button.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_blue_button(journal_button, 13)
	journal_button.pressed.connect(_on_journal_pressed)
	catch_card.add_child(journal_button)

	sparkle_root = Control.new()
	sparkle_root.name = "Sparkles"
	sparkle_root.size = catch_card.size
	sparkle_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	catch_card.add_child(sparkle_root)

	for i in range(14):
		var sparkle: Panel = Panel.new()
		sparkle.name = "Sparkle" + str(i)
		sparkle.size = Vector2(8, 8)
		sparkle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sparkle.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
			Color(1.0, 0.92, 0.28, 0.95),
			Color(1.0, 1.0, 1.0, 0.85),
			1,
			5,
			0
		))
		sparkle.visible = false
		sparkle_root.add_child(sparkle)


func _build_escape_panel() -> void:
	escape_panel = Panel.new()
	escape_panel.name = "FishingEscapePanel"
	escape_panel.size = Vector2(ESCAPE_W, ESCAPE_H)
	escape_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	escape_panel.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.050, 0.120, 0.175, 0.82),
		PixelUIStyle.GLASS_BORDER,
		3,
		16,
		9
	))
	add_child(escape_panel)

	escape_label = Label.new()
	escape_label.size = escape_panel.size
	escape_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	escape_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	PixelUIStyle.apply_label_shadow(escape_label, 19, PixelUIStyle.TEXT_SOFT)
	escape_panel.add_child(escape_label)


func _position_visible_panels() -> void:
	if waiting_panel != null and waiting_panel.visible:
		_position_waiting_panel()
	if reeling_panel != null and reeling_panel.visible:
		_position_reeling_panel()
		_layout_reeling_panel()
	if escape_panel != null and escape_panel.visible:
		_position_escape_panel()


func _position_waiting_panel() -> void:
	var ss: Vector2 = get_viewport_rect().size
	waiting_panel.position = Vector2(
		clamp((ss.x - WAITING_W) * 0.5, 12.0, max(12.0, ss.x - WAITING_W - 12.0)),
		clamp(ss.y - WAITING_H - 150.0, 72.0, max(72.0, ss.y - WAITING_H - 18.0))
	)


func _position_bite_panel() -> void:
	var ss: Vector2 = get_viewport_rect().size
	bite_panel.position = Vector2(
		clamp((ss.x - BITE_W) * 0.5, 12.0, max(12.0, ss.x - BITE_W - 12.0)),
		clamp((ss.y - BITE_H) * 0.5 - 58.0, 64.0, max(64.0, ss.y - BITE_H - 24.0))
	)


func _position_reeling_panel() -> void:
	var ss: Vector2 = get_viewport_rect().size
	var panel_w: float = clampf(float(ss.x - 24.0), 330.0, REEL_W)
	reeling_panel.size = Vector2(panel_w, REEL_H)
	reeling_panel.pivot_offset = reeling_panel.size * 0.5
	reeling_panel.position = Vector2(
		clamp((ss.x - panel_w) * 0.5, 12.0, max(12.0, ss.x - panel_w - 12.0)),
		clamp(ss.y - REEL_H - 112.0, 70.0, max(70.0, ss.y - REEL_H - 18.0))
	)


func _position_catch_card() -> void:
	var ss: Vector2 = get_viewport_rect().size
	catch_card.position = Vector2(
		clamp((ss.x - CATCH_W) * 0.5, 12.0, max(12.0, ss.x - CATCH_W - 12.0)),
		clamp((ss.y - CATCH_H) * 0.5 - 30.0, 36.0, max(36.0, ss.y - CATCH_H - 24.0))
	)


func get_catch_card_confetti_position() -> Vector2:
	if catch_card == null:
		return Vector2(INF, INF)
	if not catch_card.visible:
		_position_catch_card()

	return catch_card.global_position + catch_card.size * 0.5


func _position_escape_panel() -> void:
	var ss: Vector2 = get_viewport_rect().size
	escape_panel.position = Vector2(
		clamp((ss.x - ESCAPE_W) * 0.5, 12.0, max(12.0, ss.x - ESCAPE_W - 12.0)),
		clamp(ss.y - ESCAPE_H - 150.0, 72.0, max(72.0, ss.y - ESCAPE_H - 18.0))
	)


func _layout_reeling_panel() -> void:
	var w: float = reeling_panel.size.x
	reeling_title.size.x = max(220.0, w - 56.0)
	reel_hint.size.x = max(220.0, w - 56.0)
	var progress_bg: Control = reeling_panel.get_node_or_null("ProgressBg") as Control
	var tension_bg: Control = reeling_panel.get_node_or_null("TensionBg") as Control
	if progress_bg != null:
		progress_bg.size.x = max(252.0, w - 64.0)
	if tension_bg != null:
		tension_bg.size.x = max(170.0, w - 284.0)
	if reel_button != null:
		reel_button.position.x = max(32.0, w - 218.0)
	var journal_button: Control = reeling_panel.get_node_or_null("JournalButton") as Control
	if journal_button != null:
		journal_button.position.x = max(32.0, w - 142.0)
	var bar_w: float = max(246.0, w - 72.0)
	progress_fill.size.x = bar_w * progress_value
	var tension_w: float = max(164.0, w - 292.0)
	tension_fill.size.x = tension_w * tension_value


func _update_waiting_dots(delta: float) -> void:
	if waiting_panel == null or not waiting_panel.visible:
		return
	waiting_dot_time += delta
	if waiting_dot_time >= 0.34:
		waiting_dot_time = 0.0
		waiting_dot_count = (waiting_dot_count + 1) % 4
		var dots: String = ""
		for i in range(waiting_dot_count):
			dots += "."
		waiting_status.text = "Waiting for bite" + dots


func _update_target_pulse(delta: float) -> void:
	if target_panel == null or not target_panel.visible:
		return
	target_pulse += delta * 4.0
	var alpha: float = 0.12 + (sin(target_pulse) + 1.0) * 0.055
	target_panel.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(1.0, 0.82, 0.12, alpha),
		Color(1.0, 0.84, 0.05, 0.88),
		3,
		7,
		0
	))


func _update_bite_timer(delta: float) -> void:
	if bite_panel == null or not bite_panel.visible:
		return
	if bite_total_time > 0.0:
		bite_time_left = max(0.0, bite_time_left - delta)
	_apply_bite_bar()


func _apply_bite_bar() -> void:
	if bite_bar_fill == null:
		return
	var ratio: float = clampf(float(bite_time_left / max(0.1, bite_total_time)), 0.0, 1.0)
	bite_bar_fill.size.x = 360.0 * ratio
	if ratio < 0.28:
		bite_bar_fill.color = PixelUIStyle.WARNING_RED
	elif ratio < 0.55:
		bite_bar_fill.color = PixelUIStyle.GOLD_SOFT
	else:
		bite_bar_fill.color = PixelUIStyle.ACTION_YELLOW


func _update_reeling_bars(delta: float) -> void:
	if reeling_panel == null or not reeling_panel.visible:
		return
	progress_value = lerp(progress_value, progress_target, min(1.0, delta * 12.0))
	tension_value = lerp(tension_value, tension_target, min(1.0, delta * 12.0))
	_layout_reeling_panel()
	progress_label.text = "Catch Progress  " + str(int(round(progress_value * 100.0))) + "%"
	tension_label.text = "Line Tension  " + str(int(round(tension_value * 100.0))) + "%"
	if tension_value > 0.82:
		tension_fill.color = PixelUIStyle.WARNING_RED
	elif tension_value > 0.56:
		tension_fill.color = Color(1.0, 0.72, 0.12, 0.94)
	else:
		tension_fill.color = PixelUIStyle.GOLD_SOFT


func _update_auto_hide(delta: float) -> void:
	if catch_timer > 0.0:
		catch_timer -= delta
		if catch_timer <= 0.0 and catch_card != null:
			_fade_out(catch_card)
	if escape_timer > 0.0:
		escape_timer -= delta
		if escape_timer <= 0.0 and escape_panel != null:
			_fade_out(escape_panel)


func _update_reel_button_state() -> void:
	if reel_button == null:
		return
	reel_button.text = "REELING..." if reel_input_active else "HOLD TO REEL"
	if reel_input_active:
		reel_button.scale = Vector2(1.035, 1.035)
	else:
		reel_button.scale = Vector2.ONE


func _on_reel_button_down() -> void:
	reel_button_down = true


func _on_reel_button_up() -> void:
	reel_button_down = false


func _fade_out(node: Control) -> void:
	if node == null or not node.visible:
		return
	var tween: Tween = node.create_tween()
	tween.tween_property(node, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(Callable(node, "hide"))


func _shake_control(node: Control, strength: float, duration: float) -> void:
	if node == null:
		return
	var start_pos: Vector2 = node.position
	var tween: Tween = node.create_tween()
	var steps: int = 6
	for i in range(steps):
		var amount: float = strength * (1.0 - float(i) / float(steps))
		var offset: Vector2 = Vector2(randf_range(-amount, amount), randf_range(-amount, amount))
		tween.tween_property(node, "position", start_pos + offset, duration / float(steps)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "position", start_pos, 0.03)


func _show_sparkles(rarity: String) -> void:
	if sparkle_root == null:
		return
	var enabled: bool = rarity == "rare" or rarity == "epic" or rarity == "legendary"
	for child in sparkle_root.get_children():
		child.visible = false
	if not enabled:
		return

	var accent: Color = get_rarity_color(rarity)
	for child in sparkle_root.get_children():
		var sparkle: Panel = child as Panel
		if sparkle == null:
			continue
		sparkle.visible = true
		sparkle.modulate = accent
		sparkle.position = Vector2(randf_range(72.0, CATCH_W - 84.0), randf_range(92.0, 252.0))
		sparkle.scale = Vector2(0.35, 0.35)
		var tween: Tween = sparkle.create_tween()
		tween.set_parallel(true)
		tween.tween_property(sparkle, "scale", Vector2(randf_range(0.9, 1.45), randf_range(0.9, 1.45)), randf_range(0.28, 0.48)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(sparkle, "modulate:a", 0.0, randf_range(0.42, 0.72)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _world_to_screen(world_pos: Vector2) -> Vector2:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return world_pos
	return viewport.get_canvas_transform() * world_pos


func _canvas_scale() -> Vector2:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return Vector2.ONE
	var transform: Transform2D = viewport.get_canvas_transform()
	return Vector2(max(0.1, transform.x.length()), max(0.1, transform.y.length()))


func get_rarity_color(rarity: String) -> Color:
	match rarity.to_lower():
		"uncommon":
			return Color(0.28, 0.95, 0.45, 1.0)
		"rare":
			return Color(0.28, 0.55, 1.0, 1.0)
		"epic":
			return Color(0.72, 0.30, 1.0, 1.0)
		"legendary":
			return Color(1.0, 0.66, 0.12, 1.0)
		_:
			return Color(0.78, 0.90, 0.96, 1.0)
