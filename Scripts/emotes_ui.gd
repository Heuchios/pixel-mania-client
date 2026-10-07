extends Control

signal emote_selected(emote_id: String)
const EMOTES = preload("res://Scripts/player_emotes.gd")
const FACES = preload("res://Assets/player/expressions/face_expressions.tres")
const UI_ATLAS = preload("res://Scripts/UIAtlasDB.gd")
const PANEL_SIZE := Vector2(244, 256)
var world = null
var is_panel_open := false
var last_selection_msec := -1000
@onready var emotes_button: Button = $EmotesButton
@onready var emotes_panel: PanelContainer = $EmotesPanel
@onready var choices: VBoxContainer = $EmotesPanel/Margin/Choices

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 124
	set_meta("ignore_mobile_ui_scale", true)
	set_meta("pixelmania_text_shadow", false)
	emotes_panel.add_theme_stylebox_override("panel", UI_ATLAS.get_stylebox("outer_panel"))
	emotes_button.pressed.connect(toggle_emotes_panel)
	for id in ["wave", "laugh", "sad"]:
		var button := Button.new()
		button.name = id.capitalize()
		button.custom_minimum_size = Vector2(212, 60)
		button.text = "      " + id.capitalize()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.set_meta("pixelmania_font_role", "preserve")
		button.add_theme_font_size_override("font_size", 23)
		button.add_theme_stylebox_override("normal", UI_ATLAS.get_stylebox("inner_panel"))
		button.add_theme_stylebox_override("hover", UI_ATLAS.get_stylebox("blue_button"))
		button.add_theme_stylebox_override("pressed", UI_ATLAS.get_stylebox("pink_button"))
		var icon := TextureRect.new()
		icon.name = "Face"
		icon.texture = FACES.get_frame_texture(id, 1 if id == "laugh" else 0)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(10, 7)
		icon.size = Vector2(50, 50)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		button.pressed.connect(_select.bind(id))
		choices.add_child(button)
	set_emotes_panel_open(false)
	update_emotes_layout()

func set_world(value) -> void:
	world = value

func _process(_delta: float) -> void:
	if world != null:
		var available: bool = world.in_world and not world.is_gameplay_hud_blocked() and not world.is_player_dead_or_respawning()
		if not available:
			set_emotes_panel_open(false)
			EMOTES.cancel(world.player)
		visible = available
	update_emotes_layout()

func toggle_emotes_panel() -> void:
	set_emotes_panel_open(not is_panel_open)

func set_emotes_panel_open(open: bool) -> void:
	is_panel_open = open
	if is_instance_valid(emotes_panel): emotes_panel.visible = open

func update_emotes_layout() -> void:
	if not is_instance_valid(emotes_button): return
	var screen := get_viewport_rect().size
	MobileUIScale.layout_corner_button(emotes_button, 3, screen)
	emotes_button.position.y = minf(emotes_button.position.y, maxf(8.0, screen.y - emotes_button.size.y * emotes_button.scale.y - 8.0))
	var factor := minf(MobileUIScale.get_layout_scale(), minf((screen.x - 16.0) / PANEL_SIZE.x, (screen.y - 16.0) / PANEL_SIZE.y))
	factor = maxf(0.25, factor)
	emotes_panel.scale = Vector2.ONE * factor
	emotes_panel.size = PANEL_SIZE
	var footprint := PANEL_SIZE * factor
	var button_rect := emotes_button.get_global_rect()
	var top := button_rect.end.y + 8.0
	var left := button_rect.end.x - footprint.x
	if top + footprint.y > screen.y - 8.0:
		left = button_rect.position.x - footprint.x - 10.0
		top = clampf(button_rect.position.y, 8.0, screen.y - footprint.y - 8.0)
	emotes_panel.position = Vector2(clampf(left, 8.0, maxf(8.0, screen.x - footprint.x - 8.0)), top)

func is_emotes_ui_at_point(point: Vector2) -> bool:
	if not is_visible_in_tree(): return false
	# Block world actions even on the click that dismisses this popup.
	return is_panel_open or emotes_button.get_global_rect().has_point(point)

func _input(event: InputEvent) -> void:
	if not is_panel_open or not is_visible_in_tree(): return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		set_emotes_panel_open(false)
		get_viewport().set_input_as_handled()
	elif (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		if not emotes_button.get_global_rect().has_point(event.position) and not emotes_panel.get_global_rect().has_point(event.position):
			set_emotes_panel_open(false)
			get_viewport().set_input_as_handled()

func _select(id: String) -> void:
	if not EMOTES.DURATIONS.has(id): return
	if Time.get_ticks_msec() - last_selection_msec < EMOTES.COOLDOWN_MSEC: return
	last_selection_msec = Time.get_ticks_msec()
	set_emotes_panel_open(false)
	emote_selected.emit(id)
