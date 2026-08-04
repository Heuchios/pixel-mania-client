extends Control

signal emote_selected(emote_id: String)

const EMOTES_BUTTON_SIZE := Vector2(64, 64)
const EMOTES_BUTTON_Y := 304.0
const EMOTES_PANEL_SIZE := Vector2(312, 294)
const EMOTES_PANEL_MARGIN_RIGHT := 26.0
const EMOTES_PANEL_GAP := 8.0

@onready var emotes_button: Button = $EmotesButton
@onready var emotes_icon: TextureRect = $EmotesButton/EmotesIcon
@onready var emotes_icon_shadow: TextureRect = $EmotesButton/EmotesIconShadow
@onready var emotes_panel_clip: Control = $EmotesPanelClip
@onready var emotes_panel: Control = $EmotesPanelClip/EmotesPanel
@onready var emotes_grid: GridContainer = $EmotesPanelClip/EmotesPanel/EmotesGrid

var emotes_button_tween: Tween = null
var emotes_panel_tween: Tween = null
var emotes_button_hovered := false
var is_panel_open := false
var panel_open_amount := 0.0
var emotes_icon_base_position := Vector2.ZERO
var emotes_shadow_base_position := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 124

	emotes_icon_base_position = emotes_icon.position
	emotes_shadow_base_position = emotes_icon_shadow.position

	emotes_button.pressed.connect(toggle_emotes_panel)
	emotes_button.mouse_entered.connect(_on_emotes_button_mouse_entered)
	emotes_button.mouse_exited.connect(_on_emotes_button_mouse_exited)
	emotes_button.button_down.connect(_on_emotes_button_down)
	emotes_button.button_up.connect(_on_emotes_button_up)

	for child in emotes_grid.get_children():
		var button := child as Button
		if button != null:
			button.pressed.connect(_on_emote_button_pressed.bind(button))

	set_panel_open_amount(0.0)
	update_emotes_layout()


func _process(_delta: float) -> void:
	update_emotes_layout()


func toggle_emotes_panel() -> void:
	set_emotes_panel_open(not is_panel_open)


func set_emotes_panel_open(open: bool) -> void:
	is_panel_open = open
	if emotes_panel_tween != null:
		emotes_panel_tween.kill()

	var target := 1.0 if is_panel_open else 0.0
	emotes_panel_tween = create_tween()
	emotes_panel_tween.tween_method(
		set_panel_open_amount,
		panel_open_amount,
		target,
		0.22
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func set_panel_open_amount(amount: float) -> void:
	panel_open_amount = clampf(amount, 0.0, 1.0)
	update_emotes_layout()


func update_emotes_layout() -> void:
	if emotes_button == null or emotes_panel_clip == null:
		return

	var screen_size := get_viewport_rect().size
	var button_x := screen_size.x - 102.0
	var button_y := EMOTES_BUTTON_Y
	if screen_size.y < EMOTES_BUTTON_Y + EMOTES_BUTTON_SIZE.y + 14.0:
		button_y = max(60.0, screen_size.y - EMOTES_BUTTON_SIZE.y - 62.0)

	emotes_button.size = EMOTES_BUTTON_SIZE
	emotes_button.custom_minimum_size = EMOTES_BUTTON_SIZE
	emotes_button.position = Vector2(max(8.0, button_x), button_y)

	var panel_x := screen_size.x - EMOTES_PANEL_SIZE.x - EMOTES_PANEL_MARGIN_RIGHT
	var panel_y := emotes_button.position.y + EMOTES_BUTTON_SIZE.y + EMOTES_PANEL_GAP
	var max_panel_height: float = max(0.0, screen_size.y - panel_y - 16.0)
	var target_panel_height: float = min(EMOTES_PANEL_SIZE.y, max_panel_height)

	emotes_panel_clip.position = Vector2(max(8.0, panel_x), panel_y)
	emotes_panel_clip.size = Vector2(EMOTES_PANEL_SIZE.x, target_panel_height * panel_open_amount)
	emotes_panel_clip.visible = panel_open_amount > 0.001
	emotes_panel_clip.mouse_filter = Control.MOUSE_FILTER_STOP if is_panel_open else Control.MOUSE_FILTER_IGNORE

	emotes_panel.size = Vector2(EMOTES_PANEL_SIZE.x, target_panel_height)
	emotes_panel.position = Vector2(0.0, -target_panel_height * (1.0 - panel_open_amount))
	emotes_panel.modulate = Color(1.0, 1.0, 1.0, lerp(0.70, 1.0, panel_open_amount))


func _on_emotes_button_mouse_entered() -> void:
	emotes_button_hovered = true
	animate_emotes_button_icon(false)


func _on_emotes_button_mouse_exited() -> void:
	emotes_button_hovered = false
	animate_emotes_button_icon(false)


func _on_emotes_button_down() -> void:
	animate_emotes_button_icon(true)


func _on_emotes_button_up() -> void:
	animate_emotes_button_icon(false)


func animate_emotes_button_icon(pressed: bool) -> void:
	if emotes_icon == null or emotes_icon_shadow == null:
		return

	if emotes_button_tween != null:
		emotes_button_tween.kill()

	var icon_position := emotes_icon_base_position
	var shadow_position := emotes_shadow_base_position
	var icon_scale := Vector2.ONE
	var shadow_alpha := 0.38
	var icon_alpha := 0.96

	if emotes_button_hovered:
		icon_position = emotes_icon_base_position + Vector2(-2, -3)
		shadow_position = emotes_shadow_base_position + Vector2(2, 3)
		icon_scale = Vector2(1.06, 1.06)
		shadow_alpha = 0.48
		icon_alpha = 1.0

	if pressed:
		icon_position = emotes_icon_base_position + Vector2(1, 2)
		shadow_position = emotes_shadow_base_position + Vector2(-2, -3)
		icon_scale = Vector2(0.96, 0.96)
		shadow_alpha = 0.28

	emotes_button_tween = create_tween()
	emotes_button_tween.set_parallel(true)
	emotes_button_tween.tween_property(emotes_icon, "position", icon_position, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	emotes_button_tween.tween_property(emotes_icon, "scale", icon_scale, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	emotes_button_tween.tween_property(emotes_icon, "modulate", Color(1.0, 1.0, 1.0, icon_alpha), 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	emotes_button_tween.tween_property(emotes_icon_shadow, "position", shadow_position, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	emotes_button_tween.tween_property(emotes_icon_shadow, "scale", icon_scale, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	emotes_button_tween.tween_property(emotes_icon_shadow, "modulate", Color(0.0, 0.0, 0.0, shadow_alpha), 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_emote_button_pressed(button: Button) -> void:
	var emote_id := String(button.name).to_snake_case()
	emote_selected.emit(emote_id)
