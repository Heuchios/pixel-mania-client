extends Control
## Shared atlas meter. Existing Range values or legacy fill geometry remain authoritative.
const ATLAS = preload("res://Assets/ui/UI_3.0.png")
var source: Control
var legacy_fill: Control
var inset := 0.0
var clip: Control
var artwork: Panel
var frame_style: StyleBoxTexture
var fill_style: StyleBoxTexture

static func bind(track: Control, fill: Control = null, horizontal_inset: float = 0.0) -> void:
	if track == null or track.has_node("AtlasProgressVisual"):
		return
	var visual = load("res://Scripts/ui/atlas_progress_visual.gd").new()
	visual.name = "AtlasProgressVisual"
	visual.source = track
	visual.legacy_fill = fill
	visual.inset = horizontal_inset
	track.add_child(visual)
	track.move_child(visual, 0)
	track.self_modulate.a = 0.0
	if fill != null:
		fill.self_modulate.a = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame_style = _style(Rect2(32, 107, 32, 10), 5)
	fill_style = _style(Rect2(2, 110, 27, 4), 2)
	clip = Control.new()
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clip)
	artwork = Panel.new()
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	artwork.add_theme_stylebox_override("panel", fill_style)
	clip.add_child(artwork)
	_process(0)

func _style(region: Rect2, edge: float) -> StyleBoxTexture:
	var texture := AtlasTexture.new()
	texture.atlas = ATLAS
	texture.region = region
	texture.filter_clip = true
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = edge
	style.texture_margin_right = edge
	return style

func _process(_delta: float) -> void:
	if not is_instance_valid(source):
		return
	if not source.is_visible_in_tree():
		return
	var height := clampf(source.size.y, 10.0, 24.0)
	size = Vector2(source.size.x, height)
	position = Vector2(0, (source.size.y - height) * 0.5)
	var ratio := 0.0
	if source is Range:
		ratio = source.get_as_ratio()
	elif is_instance_valid(legacy_fill):
		ratio = legacy_fill.size.x / maxf(1.0, source.size.x - 2.0 * inset)
	var pixel_scale := height / 10.0
	frame_style.texture_margin_left = 5.0 * pixel_scale
	frame_style.texture_margin_right = 5.0 * pixel_scale
	fill_style.texture_margin_left = 2.0 * pixel_scale
	fill_style.texture_margin_right = 2.0 * pixel_scale
	var fill_size := Vector2(maxf(0, size.x - 4.0 * pixel_scale), 4.0 * pixel_scale)
	clip.position = Vector2(2.0 * pixel_scale, 3.0 * pixel_scale)
	clip.size = Vector2(fill_size.x * clampf(ratio, 0, 1), fill_size.y)
	clip.visible = ratio > 0.0
	artwork.size = fill_size
	queue_redraw()

func _draw() -> void:
	if frame_style != null:
		draw_style_box(frame_style, Rect2(Vector2.ZERO, size))
