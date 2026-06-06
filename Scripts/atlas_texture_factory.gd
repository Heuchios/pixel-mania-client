extends RefCounted


static func load_texture(texture_spec) -> Texture2D:
	if texture_spec == null:
		return null

	if texture_spec is Texture2D:
		return texture_spec

	if texture_spec is String or texture_spec is StringName:
		return load_texture_path(str(texture_spec))

	if texture_spec is Dictionary:
		return load_texture_dictionary(texture_spec)

	return null


static func load_texture_list(texture_specs: Array) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []

	for texture_spec in texture_specs:
		var texture = load_texture(texture_spec)
		if texture != null:
			textures.append(texture)

	return textures


static func load_first_existing(texture_specs: Array) -> Texture2D:
	for texture_spec in texture_specs:
		var texture = load_texture(texture_spec)
		if texture != null:
			return texture

	return null


static func get_source_path(texture_spec) -> String:
	if texture_spec == null:
		return ""

	if texture_spec is String or texture_spec is StringName:
		return str(texture_spec)

	if texture_spec is Dictionary:
		var dictionary: Dictionary = texture_spec

		for key in ["path", "texture_path", "source_path", "atlas", "atlas_path"]:
			var value = dictionary.get(key, null)
			if value is String or value is StringName:
				return str(value)

	return ""


static func load_texture_path(path: String) -> Texture2D:
	if path == "":
		return null

	if not ResourceLoader.exists(path):
		return null

	var resource = ResourceLoader.load(path)
	if resource is Texture2D:
		return resource

	return null


static func load_texture_dictionary(texture_spec: Dictionary) -> Texture2D:
	if texture_spec.is_empty():
		return null

	for key in ["path", "texture_path", "source_path"]:
		var direct_path = str(texture_spec.get(key, ""))
		if direct_path != "":
			return load_texture_path(direct_path)

	var atlas_spec = texture_spec.get("atlas", texture_spec.get("atlas_path", null))
	var atlas_texture = load_texture(atlas_spec)
	if atlas_texture == null:
		return null

	var texture := AtlasTexture.new()
	texture.atlas = atlas_texture
	texture.region = get_region(texture_spec, Vector2(atlas_texture.get_width(), atlas_texture.get_height()))
	texture.filter_clip = bool(texture_spec.get("filter_clip", true))

	if texture_spec.has("margin"):
		texture.margin = get_rect2(texture_spec.get("margin"), Rect2())

	return texture


static func get_region(texture_spec: Dictionary, atlas_size: Vector2) -> Rect2:
	if texture_spec.has("region"):
		return get_rect2(texture_spec.get("region"), Rect2(Vector2.ZERO, atlas_size))

	var cell_size = get_vector2(
		texture_spec.get("cell_size", texture_spec.get("tile_size", texture_spec.get("frame_size", Vector2.ZERO))),
		Vector2.ZERO
	)

	if cell_size.x <= 0.0 or cell_size.y <= 0.0:
		return Rect2(Vector2.ZERO, atlas_size)

	var cell = get_grid_cell(texture_spec)
	var separation = get_vector2(
		texture_spec.get("separation", texture_spec.get("spacing", Vector2.ZERO)),
		Vector2.ZERO
	)
	var offset = get_vector2(
		texture_spec.get("offset", texture_spec.get("atlas_offset", Vector2.ZERO)),
		Vector2.ZERO
	)

	return Rect2(
		offset.x + cell.x * (cell_size.x + separation.x),
		offset.y + cell.y * (cell_size.y + separation.y),
		cell_size.x,
		cell_size.y
	)


static func get_grid_cell(texture_spec: Dictionary) -> Vector2:
	if texture_spec.has("index"):
		var columns = max(1, int(texture_spec.get("columns", texture_spec.get("cols", 1))))
		var index = max(0, int(texture_spec.get("index", 0)))
		return Vector2(float(index % columns), float(int(floor(float(index) / float(columns)))))

	return get_vector2(
		texture_spec.get("cell", texture_spec.get("grid_cell", texture_spec.get("tile", texture_spec.get("frame", Vector2.ZERO)))),
		Vector2.ZERO
	)


static func get_rect2(value, fallback: Rect2) -> Rect2:
	if value is Rect2:
		return value

	if value is Rect2i:
		return Rect2(
			Vector2(float(value.position.x), float(value.position.y)),
			Vector2(float(value.size.x), float(value.size.y))
		)

	if value is Array and value.size() >= 4:
		return Rect2(
			float(value[0]),
			float(value[1]),
			float(value[2]),
			float(value[3])
		)

	if value is Dictionary:
		var dictionary: Dictionary = value
		var position = get_vector2(
			dictionary.get("position", dictionary.get("pos", null)),
			Vector2(float(dictionary.get("x", fallback.position.x)), float(dictionary.get("y", fallback.position.y)))
		)
		var size = get_vector2(
			dictionary.get("size", null),
			Vector2(
				float(dictionary.get("w", dictionary.get("width", fallback.size.x))),
				float(dictionary.get("h", dictionary.get("height", fallback.size.y)))
			)
		)

		return Rect2(position, size)

	return fallback


static func get_vector2(value, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value

	if value is Vector2i:
		return Vector2(float(value.x), float(value.y))

	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))

	if value is Dictionary:
		var dictionary: Dictionary = value
		return Vector2(
			float(dictionary.get("x", dictionary.get("w", dictionary.get("width", fallback.x)))),
			float(dictionary.get("y", dictionary.get("h", dictionary.get("height", fallback.y))))
		)

	return fallback
