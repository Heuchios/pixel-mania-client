extends Panel
## Cached reward presentation; only the existing reveal/confetti layer animates.

const Style = preload("res://Scripts/ui/pixel_ui_style.gd")
const ACCENTS := [Color("dbb7f1"), Color("9acaff"), Color("ffe09a")]
const BACKGROUNDS := [Color("281b35"), Color("171b38"), Color("321d2b")]
static var halo := _make_halo()

var tier := 2
var accent := ACCENTS[2]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)
	set_reward(5000)

static func _make_halo() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0.30), Color(1, 1, 1, 0.14), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.width = 128
	texture.height = 128
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.gradient = gradient
	return texture

func set_reward(gems: int) -> void:
	tier = 2 if gems >= 5000 else (1 if gems >= 1000 else 0)
	accent = ACCENTS[tier]
	var frame := Style.slot_style(["common", "rare", "legendary"][tier])
	add_theme_stylebox_override("panel", frame)
	queue_redraw()

func _diamond(point: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([point + Vector2(0, -radius), point + Vector2(radius, 0), point + Vector2(0, radius), point + Vector2(-radius, 0)]), color)

func _draw() -> void:
	var body: Color = BACKGROUNDS[tier]
	# Preserve the game's atlas bevel, replacing the stretched slot interior.
	var interior := Rect2(9, 9, size.x - 18, size.y - 18)
	draw_polygon(PackedVector2Array([interior.position, Vector2(interior.end.x, interior.position.y), interior.end, Vector2(interior.position.x, interior.end.y)]),
		PackedColorArray([body.lightened(0.07), body.lightened(0.07), body, body]))
	draw_rect(Rect2(14, 14, size.x - 28, 36), Color(0, 0, 0, 0.18))
	draw_line(Vector2(28, 54), Vector2(size.x - 28, 54), Color(accent, 0.28), 1.0)
	for x in [17.0, size.x - 17.0]:
		_diamond(Vector2(x, 32), 3.0, accent)
	var center := Vector2(size.x * 0.5, 109)
	draw_texture_rect(halo, Rect2(center - Vector2(80, 70), Vector2(160, 140)), false, accent)
	draw_arc(center, 53, -PI * 0.80, -PI * 0.20, 32, Color(accent, 0.28), 1.5, true)
	draw_arc(center, 53, PI * 0.20, PI * 0.80, 32, Color(accent, 0.28), 1.5, true)
	for side in [-1.0, 1.0]:
		_diamond(center + Vector2(side * 61, 0), 4, Color(accent, 0.65))
		draw_line(center + Vector2(side * 70, 0), center + Vector2(side * 88, 0), Color(accent, 0.25), 1)
	draw_set_transform(center + Vector2(0, 46), 0, Vector2(1, 0.16))
	draw_circle(Vector2.ZERO, 39, Color(0, 0, 0, 0.24), true, -1, true)
	draw_set_transform(Vector2.ZERO)
	var band_y := size.y - 61
	draw_rect(Rect2(14, band_y, size.x - 28, 47), Color(0, 0, 0, 0.25))
	draw_line(Vector2(28, band_y), Vector2(size.x - 28, band_y), Color(accent, 0.45), 1)
	for x in [18.0, size.x - 18.0]:
		for y in [12.0, size.y - 12.0]:
			draw_line(Vector2(x, y), Vector2(x + (12 if x < size.x * 0.5 else -12), y), accent, 2)
