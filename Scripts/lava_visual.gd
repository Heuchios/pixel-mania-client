extends RefCounted
## Shared GPU animation for node-owned lava, including fully enclosed tiles.

const FLOW_SHADER = preload("res://Assets/shaders/lava_flow.gdshader")
static var _materials: Dictionary = {}


static func apply(visual: Sprite2D, enabled: bool) -> void:
	if not enabled:
		if visual.material is ShaderMaterial and visual.material.shader == FLOW_SHADER:
			visual.material = null
		return
	var texture := visual.texture
	if texture == null:
		return
	var region := Rect2(Vector2.ZERO, texture.get_size())
	if texture is AtlasTexture:
		region = texture.region
		texture = texture.atlas
	if texture == null:
		return
	if visual.region_enabled:
		region = visual.region_rect
	var key := str(texture.get_rid().get_id()) + ":" + str(region)
	if not _materials.has(key):
		var flow := ShaderMaterial.new()
		flow.shader = FLOW_SHADER
		flow.set_shader_parameter("atlas_region_px", Vector4(region.position.x, region.position.y, region.size.x, region.size.y))
		_materials[key] = flow
	visual.material = _materials[key]
