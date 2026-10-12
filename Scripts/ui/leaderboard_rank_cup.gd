@tool
extends TextureRect
## Five-frame atlas cups replace numeric ranks for the podium places.

const ATLAS = preload("res://Assets/ui/UI_3.0.png")
const FRAME_COUNT := 5
const FPS := 6.0

@export_range(0, 3) var rank: int = 0:
	set(value):
		rank = clampi(value, 0, 3)
		visible = rank > 0
		_update_texture()

var frame_index := 0
var elapsed := 0.0
var atlas_texture: AtlasTexture

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_update_texture()

func _process(delta: float) -> void:
	if rank == 0 or not is_visible_in_tree():
		return
	elapsed = fmod(elapsed + delta, FRAME_COUNT / FPS)
	var next := int(elapsed * FPS) % FRAME_COUNT
	if next != frame_index:
		frame_index = next
		_update_texture()

func get_frame_region() -> Rect2:
	return Rect2((7 + frame_index) * 32, (rank + 4) * 32, 32, 32)

func _update_texture() -> void:
	if atlas_texture == null:
		atlas_texture = AtlasTexture.new()
		atlas_texture.atlas = ATLAS
		texture = atlas_texture
	atlas_texture.region = get_frame_region()
