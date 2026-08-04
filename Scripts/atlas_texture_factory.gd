extends RefCounted

const WEARABLE_ATLAS_MANIFEST_PATH := "res://Data/items/wearable_atlas.json"

static var _texture_path_cache: Dictionary = {}
static var _wearable_atlas_manifest_loaded := false
static var _wearable_atlas_manifest_modified_time := -1
static var _wearable_atlas_enabled := false
static var _wearable_atlas_lookup: Dictionary = {}


static func prime_texture(path: String, texture: Texture2D) -> void:
	var clean_path := path.strip_edges()
	if clean_path == "" or texture == null:
		return
	_texture_path_cache[clean_path] = texture


static func load_texture(texture_spec) -> Texture2D:
	if texture_spec == null:
		return null

	if texture_spec is Texture2D:
		return texture_spec

	if texture_spec is String or texture_spec is StringName:
		var clean_path := str(texture_spec).strip_edges()
		if clean_path == "":
			return null

		var wearable_spec = _resolve_wearable_atlas_texture_spec(clean_path)
		if wearable_spec is Dictionary:
			return load_texture_dictionary(wearable_spec)

		return load_texture_path(clean_path)

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
	var clean_path := path.strip_edges()
	if clean_path == "":
		return null

	var cached_texture = _texture_path_cache.get(clean_path, null)
	if cached_texture is Texture2D:
		return cached_texture as Texture2D

	if not ResourceLoader.exists(clean_path):
		return null

	var resource = ResourceLoader.load(clean_path)
	if resource is Texture2D:
		var texture := resource as Texture2D
		prime_texture(clean_path, texture)
		return texture

	return null


static func get_wearable_icon_layout(texture_spec) -> Dictionary:
	var spec := _coerce_wearable_icon_spec(texture_spec)
	if spec.is_empty():
		return {}

	var layout := {}

	var icon_position = spec.get("icon_position", spec.get("icon_offset", null))
	if icon_position != null:
		layout["icon_position"] = get_vector2(icon_position, Vector2.ZERO)

	var icon_size = spec.get("icon_size", spec.get("icon_size_px", spec.get("size", null)))
	if icon_size != null:
		layout["icon_size"] = get_vector2(icon_size, Vector2.ZERO)

	var icon_scale = spec.get("icon_scale", spec.get("scale", null))
	if icon_scale != null:
		layout["icon_scale"] = get_scale_vector(icon_scale, Vector2.ONE)

	var icon_shadow_position = spec.get(
		"icon_shadow_position",
		spec.get(
			"shadow_position",
			spec.get(
				"icon_shadow_offset",
				spec.get("shadow_offset", null)
			)
		)
	)
	if icon_shadow_position != null:
		layout["icon_shadow_position"] = get_vector2(icon_shadow_position, Vector2.ZERO)

	var icon_shadow_size = spec.get("icon_shadow_size", spec.get("shadow_size", null))
	if icon_shadow_size != null:
		layout["icon_shadow_size"] = get_vector2(icon_shadow_size, Vector2.ZERO)

	var icon_shadow_scale = spec.get("icon_shadow_scale", spec.get("shadow_scale", null))
	if icon_shadow_scale != null:
		layout["icon_shadow_scale"] = get_scale_vector(icon_shadow_scale, Vector2.ONE)

	return layout


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
		var rect_position = get_vector2(
			dictionary.get("position", dictionary.get("pos", null)),
			Vector2(float(dictionary.get("x", fallback.position.x)), float(dictionary.get("y", fallback.position.y)))
		)
		var rect_size = get_vector2(
			dictionary.get("size", null),
			Vector2(
				float(dictionary.get("w", dictionary.get("width", fallback.size.x))),
				float(dictionary.get("h", dictionary.get("height", fallback.size.y)))
			)
		)

		return Rect2(rect_position, rect_size)

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


static func get_scale_vector(value, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value

	if value is Vector2i:
		return Vector2(float(value.x), float(value.y))

	if value is float or value is int:
		var scalar := float(value)
		return Vector2(scalar, scalar)

	if value is Array:
		if value.size() >= 2:
			return Vector2(float(value[0]), float(value[1]))
		if value.size() >= 1:
			var scalar := float(value[0])
			return Vector2(scalar, scalar)

	if value is Dictionary:
		var dictionary: Dictionary = value
		if dictionary.has("x") or dictionary.has("y"):
			return Vector2(
				float(dictionary.get("x", fallback.x)),
				float(dictionary.get("y", fallback.y))
			)
		if dictionary.has("w") or dictionary.has("h"):
			return Vector2(
				float(dictionary.get("w", fallback.x)),
				float(dictionary.get("h", fallback.y))
			)

	return fallback


static func _coerce_wearable_icon_spec(texture_spec) -> Dictionary:
	if texture_spec == null:
		return {}

	if texture_spec is Dictionary:
		return (texture_spec as Dictionary).duplicate(true)

	if texture_spec is String or texture_spec is StringName:
		var clean_path := str(texture_spec).strip_edges()
		if clean_path == "":
			return {}
		var resolved_spec = _resolve_wearable_atlas_texture_spec(clean_path)
		if resolved_spec is Dictionary:
			return (resolved_spec as Dictionary).duplicate(true)

	return {}


static func _reload_wearable_atlas_manifest_if_needed() -> void:
	var current_modified_time := _get_wearable_atlas_manifest_modified_time()
	if _wearable_atlas_manifest_loaded and current_modified_time == _wearable_atlas_manifest_modified_time:
		return

	_wearable_atlas_manifest_loaded = true
	_wearable_atlas_manifest_modified_time = current_modified_time
	_wearable_atlas_lookup.clear()
	_wearable_atlas_enabled = false

	if not ResourceLoader.exists(WEARABLE_ATLAS_MANIFEST_PATH):
		return

	var file = FileAccess.open(WEARABLE_ATLAS_MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return

	var raw_json = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(raw_json)
	if not (parsed is Dictionary):
		push_warning("AtlasTextureFactory: wearable atlas manifest has invalid format: %s" % WEARABLE_ATLAS_MANIFEST_PATH)
		return

	var manifest := parsed as Dictionary
	_wearable_atlas_enabled = bool(manifest.get("enabled", false))
	if not _wearable_atlas_enabled:
		return

	var atlas_path := str(manifest.get("atlas_path", "")).strip_edges()
	if atlas_path == "":
		push_warning("AtlasTextureFactory: wearable atlas manifest is enabled but no atlas_path was provided.")
		_wearable_atlas_enabled = false
		return

	var default_cell_size := get_vector2(
		manifest.get("cell_size", manifest.get("frame_size", manifest.get("cell", Vector2i(32, 32)))),
		Vector2(32, 32)
	)
	var default_separation := get_vector2(manifest.get("separation", manifest.get("spacing", Vector2.ZERO)), Vector2.ZERO)
	var default_offset := get_vector2(manifest.get("offset", manifest.get("atlas_offset", Vector2.ZERO)), Vector2.ZERO)
	var default_filter_clip := bool(manifest.get("filter_clip", true))

	var frame_specs = manifest.get("frames", manifest.get("entries", manifest.get("sprites", {})))
	if frame_specs is Dictionary:
		for raw_key in frame_specs.keys():
			var key = str(raw_key).strip_edges().to_lower()
			var raw_spec = frame_specs[raw_key]
			if key == "":
				continue

			var resolved_spec = _build_wearable_atlas_frame_spec(raw_spec, atlas_path, default_cell_size, default_separation, default_offset, default_filter_clip)
			if resolved_spec.is_empty():
				continue

			_wearable_atlas_lookup[key] = resolved_spec

	var aliases = manifest.get("aliases", {})
	if aliases is Dictionary:
		for raw_alias in aliases.keys():
			var alias_key := str(raw_alias).strip_edges().to_lower()
			if alias_key == "":
				continue

			var alias_target = aliases[raw_alias]
			var mapped_spec: Dictionary = {}

			if alias_target is Dictionary:
				mapped_spec = _build_wearable_atlas_frame_spec(alias_target, atlas_path, default_cell_size, default_separation, default_offset, default_filter_clip)
			elif alias_target is String:
				var target_key := str(alias_target).strip_edges().to_lower()
				if _wearable_atlas_lookup.has(target_key):
					mapped_spec = (_wearable_atlas_lookup[target_key] as Dictionary).duplicate(true)

			if mapped_spec.is_empty():
				continue

			_wearable_atlas_lookup[alias_key] = mapped_spec


static func _build_wearable_atlas_frame_spec(raw_spec, atlas_path: String, default_cell_size: Vector2, default_separation: Vector2, default_offset: Vector2, default_filter_clip: bool) -> Dictionary:
	if raw_spec == null:
		return {}

	var spec := {}
	if raw_spec is Dictionary:
		spec = (raw_spec as Dictionary).duplicate(true)
	elif raw_spec is Array and raw_spec.size() >= 4:
		spec = {
			"region": raw_spec
		}
	elif raw_spec is Array and raw_spec.size() >= 2:
		spec = {
			"cell": raw_spec
		}
	else:
		return {}

	if not spec.has("atlas") and not spec.has("atlas_path"):
		spec["atlas"] = atlas_path
	if not spec.has("filter_clip"):
		spec["filter_clip"] = default_filter_clip
	if not spec.has("cell_size"):
		spec["cell_size"] = default_cell_size
	if not spec.has("separation"):
		spec["separation"] = default_separation
	if not spec.has("offset") and not spec.has("atlas_offset"):
		spec["offset"] = default_offset

	return spec


static func _resolve_wearable_atlas_texture_spec(texture_path: String):
	_reload_wearable_atlas_manifest_if_needed()
	if not _wearable_atlas_enabled or _wearable_atlas_lookup.is_empty():
		return null

	var clean_path := texture_path.strip_edges()
	if clean_path == "":
		return null

	var file_name := clean_path.get_file().to_lower()
	var file_stem := file_name.get_basename()
	var candidates := [clean_path.to_lower(), file_name, file_stem]
	for candidate in candidates:
		if _wearable_atlas_lookup.has(candidate):
			var frame_spec = _wearable_atlas_lookup[candidate]
			if frame_spec is Dictionary:
				return (frame_spec as Dictionary).duplicate(true)

	return null


static func _get_wearable_atlas_manifest_modified_time() -> int:
	var global_path := ProjectSettings.globalize_path(WEARABLE_ATLAS_MANIFEST_PATH)
	if global_path == "":
		return -1
	return int(FileAccess.get_modified_time(global_path))
