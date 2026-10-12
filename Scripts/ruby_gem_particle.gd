extends RefCounted
## Shared faceted ruby drawing for the Angelic Sword's trail and impact.

static var glow_texture: GradientTexture2D = _make_glow()


static func _make_glow() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.24, 0.58, 1.0])
	gradient.colors = PackedColorArray([Color(1.0, 0.06, 0.19, 0.7), Color(0.95, 0.02, 0.14, 0.38), Color(0.75, 0.0, 0.08, 0.10), Color(0.55, 0.0, 0.06, 0.0)])
	var texture := GradientTexture2D.new()
	texture.width = 64
	texture.height = 64
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.gradient = gradient
	return texture


static func draw_glow(canvas: CanvasItem, point: Vector2, radius: float, alpha: float) -> void:
	canvas.draw_texture_rect(glow_texture, Rect2(point - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), false, Color(1.0, 1.0, 1.0, alpha))


static func draw_gem(canvas: CanvasItem, point: Vector2, size: float, angle: float, alpha: float, glint: float = 0.0) -> void:
	var transform := Transform2D(angle, point)
	var corners := PackedVector2Array([
		Vector2(0, -size), Vector2(size * 0.58, -size * 0.26),
		Vector2(size * 0.42, size * 0.45), Vector2(0, size),
		Vector2(-size * 0.42, size * 0.45), Vector2(-size * 0.58, -size * 0.26)
	])
	for index in range(corners.size()):
		corners[index] = transform * corners[index]
	var center := transform * Vector2(-size * 0.08, -size * 0.16)
	var facets := [Color("ff4561"), Color("b90935"), Color("790820"), Color("cf123b"), Color("fa2850"), Color("ff8e9e")]
	for index in range(corners.size()):
		var tint: Color = facets[index]
		tint = tint.lerp(Color("ffd6df"), glint * (0.45 if index >= 4 else 0.15))
		canvas.draw_colored_polygon(PackedVector2Array([center, corners[index], corners[(index + 1) % corners.size()]]), Color(tint, alpha))
	canvas.draw_line(corners[5], corners[0], Color(1.0, 0.73, 0.80, alpha * (0.65 + glint * 0.35)), maxf(0.35, size * 0.12), false)
	canvas.draw_line(corners[0], center, Color(1.0, 0.58, 0.69, alpha * 0.65), maxf(0.25, size * 0.075), false)
