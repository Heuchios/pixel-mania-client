extends RefCounted
## Gloss is shared per atlas region. Access changes still use Sprite2D.modulate.

const GLOSS_SHADER = preload("res://Assets/shaders/area_lock_gloss.gdshader")
static var _materials: Dictionary = {}

static func apply(visual: Sprite2D, enabled: bool) -> void:
	if not enabled:
		if visual.material is ShaderMaterial and visual.material.shader == GLOSS_SHADER:
			visual.material = null
		return
	var texture := visual.texture
	if texture == null:
		return
	var region := Rect2(Vector2.ZERO, texture.get_size())
	if texture is AtlasTexture:
		region = texture.region
		texture = texture.atlas
	if visual.region_enabled:
		region = visual.region_rect
	if texture == null:
		return
	var key := str(texture.get_rid().get_id()) + ":" + str(region)
	if not _materials.has(key):
		var material := ShaderMaterial.new()
		material.shader = GLOSS_SHADER
		material.set_shader_parameter("atlas_region_px", Vector4(region.position.x, region.position.y, region.size.x, region.size.y))
		_materials[key] = material
	visual.material = _materials[key]
