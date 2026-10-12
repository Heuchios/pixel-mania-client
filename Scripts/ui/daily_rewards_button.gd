extends Button

const Style = preload("res://Scripts/ui/pixel_ui_style.gd")
const ICON_ATLAS = preload("res://Assets/ui/UI_3.0.png")
const ICON_FRAME_COUNT := 5
const ICON_FPS := 5.0
var reward_ready := false
var icon_frame := 0
var icon_time := 0.0

func _ready() -> void:
	text = "DAILY REWARDS"
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size = Vector2(272, 48)
	set_meta(Style.GLOBAL_FONT_ROLE_META, "body")
	Style.apply_global_typography_to_node(self)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := get_theme_stylebox(state).duplicate() as StyleBoxTexture
		box.content_margin_left = 44
		box.content_margin_right = 8
		add_theme_stylebox_override(state, box)

func set_reward_ready(ready: bool) -> void:
	if reward_ready == ready:
		return
	reward_ready = ready
	icon_time = 0.0
	icon_frame = 0
	queue_redraw()

func _process(delta: float) -> void:
	if not reward_ready or not is_visible_in_tree():
		return
	icon_time = fmod(icon_time + delta, ICON_FRAME_COUNT / ICON_FPS)
	var next := int(icon_time * ICON_FPS) % ICON_FRAME_COUNT
	if next != icon_frame:
		icon_frame = next
		queue_redraw()

func get_icon_region() -> Rect2:
	return Rect2((9 + icon_frame) * 32, 4 * 32, 32, 32)

func _draw() -> void:
	var origin := Vector2(10, roundf((size.y - 32) * 0.5))
	draw_texture_rect_region(ICON_ATLAS, Rect2(origin, Vector2(32, 32)), get_icon_region())
