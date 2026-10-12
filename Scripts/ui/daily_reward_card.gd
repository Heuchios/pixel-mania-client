extends Panel
## Cached pixel frame with a single, GPU-animated light behind the prize.

const Style = preload("res://Scripts/ui/pixel_ui_style.gd")
const LIGHT = preload("res://Assets/shaders/daily_reward_card_light.gdshader")
const ACCENTS := [Color("eed5ff"), Color("bee9ff"), Color("fff0b5")]
const METALS := [Color("b889d5"), Color("668ee0"), Color("eeb452")]
const BACKGROUNDS := [Color("261331"), Color("101a38"), Color("321c22")]

var tier := 2
var accent := ACCENTS[2]
var light: ColorRect
var light_material: ShaderMaterial

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	light_material = ShaderMaterial.new()
	light_material.shader = LIGHT
	light = ColorRect.new()
	light.material = light_material
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(light)
	resized.connect(_layout)
	_layout()
	set_reward(5000)

func _layout() -> void:
	light.position = Vector2(size.x * 0.5 - 122, 51)
	light.size = Vector2(244, 125)
	queue_redraw()

func set_reward(gems: int) -> void:
	tier = 2 if gems >= 5000 else (1 if gems >= 1000 else 0)
	accent = ACCENTS[tier]
	add_theme_stylebox_override("panel", Style.slot_style(["common", "rare", "legendary"][tier]))
	if light_material != null:
		light_material.set_shader_parameter("tint", METALS[tier].lerp(accent, 0.45))
		light_material.set_shader_parameter("strength", [0.65, 0.85, 1.0][tier])
	queue_redraw()

func _cut_rect(rect: Rect2, cut: float) -> PackedVector2Array:
	var a := rect.position
	var b := rect.end
	return PackedVector2Array([Vector2(a.x + cut, a.y), Vector2(b.x - cut, a.y),
		Vector2(b.x, a.y + cut), Vector2(b.x, b.y - cut), Vector2(b.x - cut, b.y),
		Vector2(a.x + cut, b.y), Vector2(a.x, b.y - cut), Vector2(a.x, a.y + cut)])

func _face(rect: Rect2, cut: float, top: Color, bottom: Color) -> void:
	var points := _cut_rect(rect, cut)
	var colors := PackedColorArray()
	for point in points:
		colors.append(top.lerp(bottom, (point.y - rect.position.y) / rect.size.y))
	draw_polygon(points, colors)

func _outline(points: PackedVector2Array, color: Color, width: float = 1.0) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, color, width, true)

func _diamond(point: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([point + Vector2(0, -radius), point + Vector2(radius, 0),
		point + Vector2(0, radius), point + Vector2(-radius, 0)]), color)

func _spark(point: Vector2, radius: float) -> void:
	_diamond(point, radius + 3, Color(accent, 0.07))
	draw_rect(Rect2(point - Vector2(radius, 1), Vector2(radius * 2, 2)), Color(accent, 0.75))
	draw_rect(Rect2(point - Vector2(1, radius), Vector2(2, radius * 2)), Color(accent, 0.75))
	draw_rect(Rect2(point - Vector2.ONE, Vector2(2, 2)), Color.WHITE)

func _draw() -> void:
	var body: Color = BACKGROUNDS[tier]
	var metal: Color = METALS[tier]
	var cx := size.x * 0.5
	# Inset bevels retain the inventory frame while giving it a deeper metal edge.
	draw_rect(Rect2(5, 5, size.x - 10, size.y - 10), body.darkened(0.5))
	_face(Rect2(9, 9, size.x - 18, size.y - 18), 11, body.lightened(0.07), body)
	_outline(_cut_rect(Rect2(10, 10, size.x - 20, size.y - 20), 11), Color(metal, 0.45))
	# Large, quiet facets give the dark interior some depth without texture noise.
	for side in [-1.0, 1.0]:
		var edge: float = cx + side * (cx - 12)
		draw_colored_polygon(PackedVector2Array([Vector2(edge, 25), Vector2(cx + side * 77, 57),
			Vector2(cx + side * 126, 174), Vector2(edge, size.y - 25)]), Color(metal, 0.045))
		draw_line(Vector2(edge, 59), Vector2(cx + side * 125, 111), Color(metal, 0.13), 1)
		draw_line(Vector2(cx + side * 125, 111), Vector2(edge, 164), Color(metal, 0.13), 1)
	# Raised title ribbon, with folded ends and a crisp light-catching top edge.
	for side in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([Vector2(cx + side * 123, 22), Vector2(cx + side * 151, 22),
			Vector2(cx + side * 145, 34), Vector2(cx + side * 151, 47), Vector2(cx + side * 123, 47)]), metal.darkened(0.62))
	_face(Rect2(cx - 132, 14, 264, 36), 7, body.darkened(0.65), body.darkened(0.65))
	_face(Rect2(cx - 132, 11, 264, 36), 7, metal.lerp(body, 0.55), metal.lerp(body, 0.82))
	draw_line(Vector2(cx - 124, 12), Vector2(cx + 124, 12), Color(accent, 0.75), 2)
	draw_line(Vector2(cx - 124, 46), Vector2(cx + 124, 46), Color(metal, 0.7), 1)
	# A faceted medallion sits behind the original, unfiltered gem sprite.
	var center := Vector2(cx, 111)
	var medallion := Rect2(center - Vector2(62, 58), Vector2(124, 116))
	_face(medallion, 32, Color(metal, 0.10), Color(metal, 0.025))
	_outline(_cut_rect(medallion, 32), Color(metal, 0.28))
	_outline(_cut_rect(medallion.grow(-5), 29), Color(accent, 0.07))
	for side in [-1.0, 1.0]:
		_spark(center + Vector2(side * 82, -20), 4)
		_spark(center + Vector2(side * 107, 22), 2)
		_diamond(center + Vector2(side * 92, 2), 2, Color(metal, 0.5))
	# A small lit plinth grounds the gem, with a dark base and a beveled face.
	_face(Rect2(cx - 52, 161, 104, 12), 6, body.darkened(0.6), body.darkened(0.6))
	_face(Rect2(cx - 52, 157, 104, 10), 5, metal.darkened(0.25), metal.darkened(0.60))
	draw_line(Vector2(cx - 42, 157), Vector2(cx + 42, 157), Color(accent, 0.65), 1)
	# Recessed amount plaque has its own bevel, rather than a full-width stripe.
	_face(Rect2(29, size.y - 62, size.x - 58, 47), 7, metal.darkened(0.2), metal.darkened(0.55))
	_face(Rect2(31, size.y - 59, size.x - 62, 42), 6, body.darkened(0.30), body.darkened(0.65))
	draw_line(Vector2(cx - 42, size.y - 16), Vector2(cx + 42, size.y - 16), Color(accent, 0.65), 1)
	# Corner clamps and inset jewels use the same stepped shapes as inventory UI.
	for side in [-1.0, 1.0]:
		var x := 5.0 if side < 0 else size.x - 5.0
		for bottom in [false, true]:
			var y := size.y - 5 if bottom else 5.0
			var down := -1.0 if bottom else 1.0
			draw_polyline(PackedVector2Array([Vector2(x, y + down * 24), Vector2(x, y), Vector2(x - side * 24, y)]), metal, 5)
			draw_polyline(PackedVector2Array([Vector2(x - side * 2, y + down * 22), Vector2(x - side * 2, y + down * 2), Vector2(x - side * 22, y + down * 2)]), accent, 1)
		_diamond(Vector2(x - side * 12, size.y - 39), 5, metal.darkened(0.6))
		_diamond(Vector2(x - side * 12, size.y - 40), 3, accent)
