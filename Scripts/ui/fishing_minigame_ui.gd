extends Control

signal reel_pressed

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")
const FishingJournalUI = preload("res://Scripts/ui/fishing_journal_ui.gd")

const WAITING_W := 390.0
const WAITING_H := 112.0
const BITE_W := 430.0
const BITE_H := 206.0
const REEL_W := 720.0
const REEL_H := 390.0
const CATCH_W := 500.0
const CATCH_H := 410.0
const ESCAPE_W := 330.0
const ESCAPE_H := 72.0

var world = null
var last_viewport_size := Vector2.ZERO

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
var progress_label: Label = null
var mistakes_label: Label = null
var reel_button: Button = null
var reel_hint: Label = null
var pull_feedback: Label = null
var pull_track: Panel = null
var pull_zone: ColorRect = null
var pull_marker: ColorRect = null
var pull_zone_label: Label = null
var reel_scene: Panel = null
var reel_fish: TextureRect = null
var reel_line: ColorRect = null
var progress_value := 0.0
var progress_target := 0.0
var pull_state: Dictionary = {}


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
	_update_pull_preview(delta)
	_update_auto_hide(delta)


func show_waiting(lure_name: String) -> void:
	_ensure_ready()
	_hide_results()
	hide_bite()
	hide_reeling()
	if waiting_panel == null:
		return
	waiting_title.text = "Fishing..."
	waiting_lure.text = lure_name
	waiting_status.text = "Waiting for bite"
	waiting_dot_time = 0.0
	waiting_dot_count = 0
	waiting_panel.visible = true
	_position_waiting_panel()
	_open_fitted_panel(waiting_panel, 0.14)


func show_bite(reaction_time: float) -> void:
	_ensure_ready()
	hide_waiting()
	hide_reeling()
	if bite_panel == null:
		return
	bite_total_time = max(0.1, reaction_time)
	bite_time_left = bite_total_time
	bite_bar_fill.size.x = 360.0
	bite_panel.visible = true
	_position_bite_panel()
	_open_fitted_panel(bite_panel, 0.12)


func update_bite_timer(time_left: float, total_time: float) -> void:
	bite_total_time = max(0.1, total_time)
	bite_time_left = clamp(time_left, 0.0, bite_total_time)
	_apply_bite_bar()


func set_reeling_reward(texture: Texture2D) -> void:
	_ensure_ready()
	reel_fish.texture = texture


func show_resolving() -> void:
	show_waiting("")
	waiting_title.text = "Landing catch..."
	waiting_status.text = "Waiting for server"


func show_pull_game(data: Dictionary) -> void:
	_ensure_ready()
	hide_waiting()
	hide_bite()
	pull_state = data
	progress_target = float(data.get("pulls", 0)) / maxf(1.0, float(data.get("required_pulls", 3)))
	if not reeling_panel.visible:
		progress_value = progress_target
		reeling_panel.visible = true
		_position_reeling_panel()
		_open_fitted_panel(reeling_panel, 0.12)
	progress_label.text = "Pulls %d/%d" % [data.get("pulls", 0), data.get("required_pulls", 3)]
	mistakes_label.text = "Misses %d/3" % data.get("misses", 0)
	pull_feedback.text = str(data.get("feedback", ""))
	reel_button.text = "GET READY..." if bool(data.get("resting", false)) else "REEL"
	_layout_reeling_panel()


func show_catch_result(fish_data: Dictionary) -> void:
	_ensure_ready()
	_stop_panel_fade(catch_card)
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
	var fitted_scale := catch_card.scale
	var final_pos: Vector2 = catch_card.position
	catch_card.position = final_pos + Vector2(0, 48)
	catch_card.modulate = Color(1.0, 1.0, 1.0, 0.0)
	catch_card.scale = fitted_scale * 0.92
	catch_card.visible = true
	catch_timer = 4.8 if rarity == "legendary" else 3.9

	var tween: Tween = catch_card.create_tween()
	tween.set_parallel(true)
	tween.tween_property(catch_card, "position", final_pos, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(catch_card, "scale", fitted_scale, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(catch_card, "modulate", Color.WHITE, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if special_text != "":
		_shake_control(catch_icon_back, 5.0 if rarity != "legendary" else 7.0, 0.18)


func show_escape() -> void:
	_ensure_ready()
	_stop_panel_fade(escape_panel)
	hide_fishing_state()
	if escape_panel == null:
		return
	escape_label.text = "Fish escaped..."
	escape_panel.visible = true
	escape_timer = 1.8
	_position_escape_panel()
	_open_fitted_panel(escape_panel, 0.12)


func hide_all() -> void:
	hide_fishing_state()
	_hide_results()


func _hide_results() -> void:
	_stop_panel_fade(catch_card)
	_stop_panel_fade(escape_panel)
	if catch_card != null:
		catch_card.visible = false
	if escape_panel != null:
		escape_panel.visible = false
	catch_timer = 0.0
	escape_timer = 0.0


func open_journal() -> void:
	_setup_journal_ui()
	if journal_ui != null and journal_ui.has_method("open_journal"):
		journal_ui.open_journal()


func hide_fishing_state() -> void:
	hide_waiting()
	hide_bite()
	hide_reeling()
	hide_target_indicator()


func show_target_indicator(_grid_pos: Vector2i) -> void:
	return


func hide_target_indicator() -> void:
	if target_panel != null:
		target_panel.visible = false


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
	bite_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bite_hint.text = "Tap HOOK, click, E, or Space"
	bite_hint.position = Vector2(24, 78)
	bite_hint.size = Vector2(BITE_W - 48.0, 26)
	bite_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bite_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	PixelUIStyle.apply_small_label(bite_hint, 15)
	bite_panel.add_child(bite_hint)

	var bar_bg: Panel = Panel.new()
	bar_bg.name = "BiteBar"
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
	hook_button.text = "HOOK"
	hook_button.focus_mode = Control.FOCUS_NONE
	hook_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	hook_button.position = Vector2(115, 146)
	hook_button.size = Vector2(200, 48)
	hook_button.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_yellow_button(hook_button, 15)
	hook_button.pressed.connect(_on_reel_pressed)
	bite_panel.add_child(hook_button)


func _build_reeling_panel() -> void:
	reeling_panel = Panel.new()
	reeling_panel.name = "ReelingPanel"
	reeling_panel.size = Vector2(REEL_W, REEL_H)
	reeling_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	reeling_panel.add_theme_stylebox_override("panel", PixelUIStyle.premium_panel_style())
	add_child(reeling_panel)

	reeling_title = _reel_label("ReelingTitle", "REEL IT IN!", Vector2(24, 16), Vector2(672, 42))
	PixelUIStyle.apply_label_shadow(reeling_title, 36, PixelUIStyle.GOLD_SOFT)
	reel_hint = _reel_label("ReelHint", "Tap REEL in the green zone. Click, E or Space.", Vector2(24, 62), Vector2(672, 36))
	reel_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	reel_scene = Panel.new()
	reel_scene.name = "ReelScene"
	reel_scene.position = Vector2(24, 106)
	reel_scene.size = Vector2(672, 64)
	reel_scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reel_scene.add_theme_stylebox_override("panel", PixelUIStyle.section_style())
	reeling_panel.add_child(reel_scene)
	reel_line = ColorRect.new()
	reel_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reel_line.color = PixelUIStyle.TEXT_SOFT
	reel_line.position = Vector2(12, 32)
	reel_scene.add_child(reel_line)
	reel_fish = TextureRect.new()
	reel_fish.name = "ReelingFish"
	reel_fish.size = Vector2(64, 64)
	reel_fish.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	reel_fish.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	reel_fish.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	reel_fish.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reel_scene.add_child(reel_fish)

	progress_label = _reel_label("PullCount", "Pulls 0/3", Vector2(24, 180), Vector2(330, 30))
	mistakes_label = _reel_label("MissCount", "Misses 0/3", Vector2(366, 180), Vector2(330, 30))
	mistakes_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pull_track = Panel.new()
	pull_track.name = "PullTrack"
	pull_track.position = Vector2(24, 220)
	pull_track.size = Vector2(672, 40)
	pull_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pull_track.add_theme_stylebox_override("panel", PixelUIStyle.input_style())
	reeling_panel.add_child(pull_track)
	pull_zone = ColorRect.new()
	pull_zone.name = "PullZone"
	pull_zone.color = Color(0.18, 0.62, 0.30)
	pull_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pull_track.add_child(pull_zone)
	pull_zone_label = Label.new()
	pull_zone_label.text = "PULL"
	pull_zone_label.set_meta("pixelmania_font_size", 18)
	pull_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pull_zone_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pull_zone_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(pull_zone_label)
	pull_zone.add_child(pull_zone_label)
	pull_marker = ColorRect.new()
	pull_marker.name = "PullMarker"
	pull_marker.color = PixelUIStyle.GOLD_SOFT
	pull_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pull_track.add_child(pull_marker)

	pull_feedback = _reel_label("PullFeedback", "Two mistakes forgiven.", Vector2(24, 270), Vector2(672, 42))
	pull_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pull_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reel_button = Button.new()
	reel_button.name = "ReelButton"
	reel_button.text = "REEL"
	reel_button.position = Vector2(24, 324)
	reel_button.size = Vector2(672, 46)
	reel_button.focus_mode = Control.FOCUS_NONE
	reel_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	reel_button.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_yellow_button(reel_button, 24)
	reel_button.pressed.connect(_on_reel_pressed)
	reeling_panel.add_child(reel_button)


func _reel_label(node_name: String, text: String, pos: Vector2, dimensions: Vector2) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.position = pos
	label.size = dimensions
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	PixelUIStyle.apply_small_label(label)
	reeling_panel.add_child(label)
	return label


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
	var resized := last_viewport_size != get_viewport_rect().size
	last_viewport_size = get_viewport_rect().size
	if waiting_panel != null and waiting_panel.visible:
		_position_waiting_panel()
	if reeling_panel != null and reeling_panel.visible:
		_position_reeling_panel()
		_layout_reeling_panel()
	if escape_panel != null and escape_panel.visible:
		_position_escape_panel()
	if resized and bite_panel != null and bite_panel.visible:
		_position_bite_panel()
	if resized and catch_card != null and catch_card.visible:
		_position_catch_card()


func _position_waiting_panel() -> void:
	_fit_fixed_panel(waiting_panel, Vector2(WAITING_W, WAITING_H), false)


func _position_bite_panel() -> void:
	var ss := get_viewport_rect().size
	var width := minf(BITE_W, maxf(1.0, ss.x - 24.0))
	_fit_fixed_panel(bite_panel, Vector2(width, BITE_H), true)
	bite_title.size.x = width - 40.0
	bite_hint.size = Vector2(width - 48.0, 36)
	bite_hint.position.y = 74.0
	var hint_size := 18 if width < BITE_W else 24
	bite_hint.set_meta("pixelmania_font_size", hint_size)
	bite_hint.add_theme_font_size_override("font_size", hint_size)
	var bar: Control = bite_panel.get_node("BiteBar")
	bar.position.x = 24.0
	bar.size.x = width - 48.0
	bite_bar_fill.position.x = 25.0
	var hook: Button = bite_panel.get_node("HookButton")
	hook.position.x = 24.0
	hook.size.x = width - 48.0
	_apply_bite_bar()


func _position_reeling_panel() -> void:
	var ss: Vector2 = get_viewport_rect().size
	var panel_w: float = minf(maxf(1.0, ss.x - 24.0), REEL_W)
	reeling_panel.size = Vector2(panel_w, REEL_H)
	reeling_panel.pivot_offset = reeling_panel.size * 0.5
	var factor := minf(1.0, maxf(1.0, ss.y - 24.0) / REEL_H)
	reeling_panel.scale = Vector2.ONE * factor
	var drawn_size := reeling_panel.size * factor
	var top_left := Vector2((ss.x - drawn_size.x) * 0.5, clampf(ss.y - drawn_size.y - 112.0, 12.0, maxf(12.0, ss.y - drawn_size.y - 12.0)))
	reeling_panel.position = top_left - reeling_panel.pivot_offset * (1.0 - factor)


func _position_catch_card() -> void:
	_fit_fixed_panel(catch_card, Vector2(CATCH_W, CATCH_H), true)


func get_catch_card_confetti_position() -> Vector2:
	if catch_card == null:
		return Vector2(INF, INF)
	if not catch_card.visible:
		_position_catch_card()

	return catch_card.global_position + catch_card.size * 0.5


func _position_escape_panel() -> void:
	_fit_fixed_panel(escape_panel, Vector2(ESCAPE_W, ESCAPE_H), false)


func _fit_fixed_panel(panel: Control, design_size: Vector2, centered: bool) -> void:
	var ss: Vector2 = get_viewport_rect().size
	var factor := minf(1.0, minf(maxf(1.0, ss.x - 24.0) / design_size.x, maxf(1.0, ss.y - 24.0) / design_size.y))
	panel.size = design_size
	panel.pivot_offset = design_size * 0.5
	panel.scale = Vector2.ONE * factor
	var drawn_size := design_size * factor
	var y := (ss.y - drawn_size.y) * 0.5 - 30.0 if centered else ss.y - drawn_size.y - 150.0
	var top_left := Vector2((ss.x - drawn_size.x) * 0.5, clampf(y, 12.0, maxf(12.0, ss.y - drawn_size.y - 12.0)))
	panel.position = top_left - panel.pivot_offset * (1.0 - factor)


func _open_fitted_panel(panel: Control, duration: float) -> void:
	panel.modulate = Color(1, 1, 1, 0)
	var tween := panel.create_tween()
	tween.tween_property(panel, "modulate", Color.WHITE, duration)


func _layout_reeling_panel() -> void:
	var width := maxf(1.0, reeling_panel.size.x - 48.0)
	var narrow := width < 430.0
	reeling_title.size.x = width
	reel_hint.size.x = width
	reel_scene.size.x = width
	progress_label.size.x = width * 0.5
	mistakes_label.position.x = 24.0 + width * 0.5
	mistakes_label.size.x = width * 0.5
	pull_track.size.x = width
	pull_feedback.size.x = width
	reel_button.size.x = width
	for label in [reel_hint, progress_label, mistakes_label, pull_feedback]:
		var text_size := 18 if narrow else 24
		if int(label.get_meta("pixelmania_font_size", 0)) != text_size:
			label.set_meta("pixelmania_font_size", text_size)
			label.add_theme_font_size_override("font_size", text_size)
	var title_size := 26 if narrow else 36
	if int(reeling_title.get_meta("pixelmania_font_size", 0)) != title_size:
		reeling_title.set_meta("pixelmania_font_size", title_size)
		reeling_title.add_theme_font_size_override("font_size", title_size)
	var lane_width := maxf(1.0, width - 12.0)
	pull_zone.position = Vector2(6.0 + lane_width * float(pull_state.get("zone_start", 0.26)), 4)
	pull_zone.size = Vector2(lane_width * float(pull_state.get("zone_size", 0.44)), 32)
	pull_zone_label.size = pull_zone.size
	# Draw the authoritative cursor directly: interpolation would give false misses.
	pull_marker.position = Vector2(6.0 + lane_width * float(pull_state.get("cursor", 0.0)) - 3.0, -5)
	pull_marker.size = Vector2(6, 50)
	reel_fish.position = Vector2(lerpf(maxf(12.0, width - 76.0), 12.0, progress_value), 0)
	reel_line.size = Vector2(maxf(0.0, reel_fish.position.x + 20.0), 2)


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
		waiting_status.text = ("Waiting for server" if waiting_title.text == "Landing catch..." else "Waiting for bite") + dots


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


func _update_bite_timer(_delta: float) -> void:
	if bite_panel == null or not bite_panel.visible:
		return
	# The manager owns time; a second countdown here makes the bar run ahead.
	_apply_bite_bar()


func _apply_bite_bar() -> void:
	if bite_bar_fill == null:
		return
	var ratio: float = clampf(float(bite_time_left / max(0.1, bite_total_time)), 0.0, 1.0)
	bite_bar_fill.size.x = maxf(1.0, bite_panel.size.x - 50.0) * ratio
	if ratio < 0.28:
		bite_bar_fill.color = PixelUIStyle.WARNING_RED
	elif ratio < 0.55:
		bite_bar_fill.color = PixelUIStyle.GOLD_SOFT
	else:
		bite_bar_fill.color = PixelUIStyle.ACTION_YELLOW


func _update_pull_preview(delta: float) -> void:
	if reeling_panel == null or not reeling_panel.visible:
		return
	progress_value = move_toward(progress_value, progress_target, delta * 1.6)
	_layout_reeling_panel()


func _update_auto_hide(delta: float) -> void:
	if catch_timer > 0.0:
		catch_timer -= delta
		if catch_timer <= 0.0 and catch_card != null:
			_fade_out(catch_card)
	if escape_timer > 0.0:
		escape_timer -= delta
		if escape_timer <= 0.0 and escape_panel != null:
			_fade_out(escape_panel)


func _on_reel_pressed() -> void:
	if (bite_panel != null and bite_panel.visible) or (reeling_panel != null and reeling_panel.visible):
		reel_pressed.emit()


func _fade_out(node: Control) -> void:
	if node == null or not node.visible:
		return
	var tween: Tween = node.create_tween()
	node.set_meta("fishing_fade", tween)
	tween.tween_property(node, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(Callable(node, "hide"))


func _stop_panel_fade(node: Control) -> void:
	if node == null or not node.has_meta("fishing_fade"):
		return
	var tween = node.get_meta("fishing_fade")
	if tween is Tween and tween.is_valid():
		tween.kill()
	if node.has_meta("fishing_fade"):
		node.remove_meta("fishing_fade")


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
