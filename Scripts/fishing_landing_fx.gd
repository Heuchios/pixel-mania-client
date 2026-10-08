extends Node2D
signal landed
var age := 0.0
var accent := Color.WHITE
var artwork: Texture2D
var sprite: Sprite2D
var context_valid: Callable
const DURATION := 1.0
func setup(texture: Texture2D, color: Color) -> void:
	accent = color
	artwork = texture
	sprite = Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if texture != null:
		sprite.scale = Vector2.ONE * (28.0 / maxf(texture.get_width(), texture.get_height()))
	add_child(sprite)
func _process(delta: float) -> void:
	if context_valid.is_valid() and not context_valid.call():
		queue_free()
		return
	age += delta
	var rise := clampf(age / 0.45, 0.0, 1.0)
	var ease := 1.0 - pow(1.0 - rise, 3.0)
	sprite.position.y = -52.0 * ease
	sprite.rotation = sin(rise * PI) * -0.22
	var shine := sin(clampf((age - 0.3) / 0.6, 0.0, 1.0) * PI)
	sprite.modulate = Color.WHITE.lerp(accent.lightened(0.6), shine * 0.45)
	modulate.a = 1.0 - clampf((age - 0.85) / 0.15, 0.0, 1.0)
	queue_redraw()
	if age >= DURATION:
		set_process(false)
		landed.emit()
		queue_free()
func _draw() -> void:
	if sprite == null: return
	var shine := sin(clampf((age - 0.25) / 0.65, 0.0, 1.0) * PI)
	for i in 8:
		var angle := i * TAU / 8.0 + 0.2
		var point := sprite.position + Vector2.from_angle(angle) * (18.0 + shine * 8.0)
		var color := Color(accent.lightened(0.3), shine * 0.9)
		draw_line(point - Vector2(2,0), point + Vector2(2,0), color, 1.0)
		draw_line(point - Vector2(0,2), point + Vector2(0,2), color, 1.0)
