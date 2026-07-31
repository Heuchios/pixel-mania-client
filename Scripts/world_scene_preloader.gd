extends RefCounted

const AtlasTextureFactory = preload("res://Scripts/atlas_texture_factory.gd")

const WORLD_SCENE_PATH := "res://Scenes/main.tscn"
const ITEM_DATABASE_PATH := "res://Scripts/item_database.gd"
const THREAD_LOAD_NOT_STARTED := -1
const MAX_VISUAL_LOAD_STARTS_PER_PUMP := 12
const MAX_CONCURRENT_VISUAL_LOADS := 24
const STARTUP_TEXTURE_KEYS := [
	"texture",
	"shirt_body_texture",
	"body_texture",
	"tree_textures",
	"world_lock_access_texture",
	"world_lock_no_access_texture"
]
const ALWAYS_WARM_VISUAL_PATHS := [
	"res://Assets/atlases/items.png",
	"res://Assets/seeds/seed_box.png",
	"res://Assets/seed_tree_sprites/block_tree_stage_0.png",
	"res://Assets/seed_tree_sprites/block_tree_stage_1.png",
	"res://Assets/seed_tree_sprites/block_tree_stage_2.png",
	"res://Assets/seed_tree_sprites/block_tree_mature.png",
	"res://Assets/seed_tree_sprites/bg_tree_stage0.png",
	"res://Assets/seed_tree_sprites/bg_tree_stage1.png",
	"res://Assets/seed_tree_sprites/bg_tree_stage2.png",
	"res://Assets/seed_tree_sprites/bg_tree_mature.png",
	"res://Assets/blocks/Tier_1/basic blocks/bedrock_block.png",
	"res://Assets/player/back_item/legendary_wings/legendary_wings_idle1.png",
	"res://Assets/player/back_item/legendary_wings/legendary_wings_idle2.png",
	"res://Assets/player/back_item/legendary_wings/legendary_wings_jump1.png",
	"res://Assets/player/back_item/legendary_wings/legendary_wings_jump2.png",
	"res://Assets/player/back_item/legendary_wings/legendary_wings_jump3.png"
]

static var _request_started := false
static var _loaded_scene: PackedScene = null
static var _last_error := OK
static var _item_database_request_started := false
static var _loaded_item_database: Script = null
static var _item_database_last_error := OK
static var _visual_requests_prepared := false
static var _visual_paths: Array[String] = []
static var _visual_launch_index := 0
static var _visual_in_flight: Dictionary = {}
static var _preloaded_visual_resources: Dictionary = {}
static var _visual_failed_paths: Dictionary = {}


static func start() -> Error:
	var item_database_error := _start_item_database_request()
	var world_scene_error := _start_world_scene_request()
	pump()
	if world_scene_error != OK:
		return world_scene_error
	return item_database_error


static func pump() -> void:
	if _loaded_scene == null and _request_started:
		if ResourceLoader.load_threaded_get_status(WORLD_SCENE_PATH) == ResourceLoader.THREAD_LOAD_LOADED:
			_capture_loaded_scene()
	if _loaded_item_database == null and _item_database_request_started:
		if ResourceLoader.load_threaded_get_status(ITEM_DATABASE_PATH) == ResourceLoader.THREAD_LOAD_LOADED:
			_capture_loaded_item_database()
	if _loaded_item_database != null:
		_prepare_visual_requests()
		_pump_visual_requests()


static func _prepare_visual_requests() -> void:
	if _visual_requests_prepared or _loaded_item_database == null:
		return

	var discovered_paths: Dictionary = {}
	for path_variant in ALWAYS_WARM_VISUAL_PATHS:
		_collect_visual_paths(path_variant, discovered_paths)

	var constant_map: Dictionary = _loaded_item_database.get_script_constant_map()
	var raw_items = constant_map.get("ITEMS", {})
	if raw_items is Dictionary:
		var items: Dictionary = raw_items
		for raw_item_data in items.values():
			if not raw_item_data is Dictionary:
				continue
			var item_data: Dictionary = raw_item_data
			for texture_key_variant in STARTUP_TEXTURE_KEYS:
				var texture_key := str(texture_key_variant)
				if item_data.has(texture_key):
					_collect_visual_paths(item_data.get(texture_key), discovered_paths)

	_visual_paths.clear()
	for path_variant in discovered_paths.keys():
		_visual_paths.append(str(path_variant))
	_visual_paths.sort()
	_visual_launch_index = 0
	_visual_requests_prepared = true


static func _collect_visual_paths(value, discovered_paths: Dictionary) -> void:
	if value is String or value is StringName:
		var path := str(value).strip_edges()
		if _is_visual_resource_path(path) and ResourceLoader.exists(path):
			discovered_paths[path] = true
		return

	if value is Array:
		var values: Array = value
		for nested_value in values:
			_collect_visual_paths(nested_value, discovered_paths)
		return

	if value is Dictionary:
		var values: Dictionary = value
		for nested_value in values.values():
			_collect_visual_paths(nested_value, discovered_paths)


static func _is_visual_resource_path(path: String) -> bool:
	if not path.begins_with("res://"):
		return false
	var extension := path.get_extension().to_lower()
	return extension in ["png", "webp", "jpg", "jpeg", "svg"]


static func _pump_visual_requests() -> void:
	if not _visual_requests_prepared:
		return

	var completed_paths: Array[String] = []
	for path_variant in _visual_in_flight.keys():
		var path := str(path_variant)
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_capture_visual_resource(path)
			completed_paths.append(path)
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_visual_failed_paths[path] = true
			completed_paths.append(path)
	for path in completed_paths:
		_visual_in_flight.erase(path)

	var started_count := 0
	while (
		_visual_launch_index < _visual_paths.size()
		and _visual_in_flight.size() < MAX_CONCURRENT_VISUAL_LOADS
		and started_count < MAX_VISUAL_LOAD_STARTS_PER_PUMP
	):
		var path := _visual_paths[_visual_launch_index]
		_visual_launch_index += 1
		started_count += 1

		if ResourceLoader.has_cached(path):
			var cached_resource := ResourceLoader.load(path)
			if cached_resource is Texture2D:
				_retain_visual_resource(path, cached_resource as Texture2D)
			else:
				_visual_failed_paths[path] = true
			continue

		var current_status := ResourceLoader.load_threaded_get_status(path)
		if current_status == ResourceLoader.THREAD_LOAD_LOADED:
			_capture_visual_resource(path)
			continue
		if current_status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_visual_in_flight[path] = true
			continue

		var request_error := ResourceLoader.load_threaded_request(
			path,
			"Texture2D",
			true,
			ResourceLoader.CACHE_MODE_REUSE
		)
		if request_error == OK:
			_visual_in_flight[path] = true
		else:
			_visual_failed_paths[path] = true


static func _capture_visual_resource(path: String) -> void:
	var loaded_resource := ResourceLoader.load_threaded_get(path)
	if loaded_resource is Texture2D:
		_retain_visual_resource(path, loaded_resource as Texture2D)
	else:
		_visual_failed_paths[path] = true


static func _retain_visual_resource(path: String, texture: Texture2D) -> void:
	_preloaded_visual_resources[path] = texture
	AtlasTextureFactory.prime_texture(path, texture)


static func _start_world_scene_request() -> Error:
	if _loaded_scene != null:
		return OK

	if ResourceLoader.has_cached(WORLD_SCENE_PATH):
		var cached_resource := load(WORLD_SCENE_PATH)
		if cached_resource is PackedScene:
			_loaded_scene = cached_resource as PackedScene
			_request_started = true
			_last_error = OK
			return OK

	var current_status := ResourceLoader.load_threaded_get_status(WORLD_SCENE_PATH)
	if current_status == ResourceLoader.THREAD_LOAD_LOADED:
		return _capture_loaded_scene()
	if current_status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		_request_started = true
		_last_error = OK
		return OK

	_last_error = ResourceLoader.load_threaded_request(
		WORLD_SCENE_PATH,
		"PackedScene",
		true,
		ResourceLoader.CACHE_MODE_REUSE
	)
	_request_started = _last_error == OK
	return _last_error


static func _start_item_database_request() -> Error:
	if _loaded_item_database != null:
		return OK

	if ResourceLoader.has_cached(ITEM_DATABASE_PATH):
		var cached_resource := load(ITEM_DATABASE_PATH)
		if cached_resource is Script:
			_loaded_item_database = cached_resource as Script
			_item_database_request_started = true
			_item_database_last_error = OK
			return OK

	var current_status := ResourceLoader.load_threaded_get_status(ITEM_DATABASE_PATH)
	if current_status == ResourceLoader.THREAD_LOAD_LOADED:
		return _capture_loaded_item_database()
	if current_status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		_item_database_request_started = true
		_item_database_last_error = OK
		return OK

	_item_database_last_error = ResourceLoader.load_threaded_request(
		ITEM_DATABASE_PATH,
		"Script",
		true,
		ResourceLoader.CACHE_MODE_REUSE
	)
	_item_database_request_started = _item_database_last_error == OK
	return _item_database_last_error


static func get_status(progress: Array = []) -> int:
	if _loaded_scene != null:
		if not progress.is_empty():
			progress[0] = 1.0
		return ResourceLoader.THREAD_LOAD_LOADED
	if not _request_started:
		return THREAD_LOAD_NOT_STARTED
	return ResourceLoader.load_threaded_get_status(WORLD_SCENE_PATH, progress)


static func get_progress() -> float:
	if _loaded_scene != null:
		return 1.0
	var progress: Array = []
	var status := get_status(progress)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		return 1.0
	if progress.is_empty():
		return 0.0
	return clampf(float(progress[0]), 0.0, 1.0)


static func get_item_database_status(progress: Array = []) -> int:
	if _loaded_item_database != null:
		if not progress.is_empty():
			progress[0] = 1.0
		return ResourceLoader.THREAD_LOAD_LOADED
	if not _item_database_request_started:
		return THREAD_LOAD_NOT_STARTED
	return ResourceLoader.load_threaded_get_status(ITEM_DATABASE_PATH, progress)


static func get_visual_progress() -> float:
	if not _visual_requests_prepared:
		return 0.0
	if _visual_paths.is_empty():
		return 1.0
	var completed_count := _preloaded_visual_resources.size() + _visual_failed_paths.size()
	return clampf(float(completed_count) / float(_visual_paths.size()), 0.0, 1.0)


static func get_combined_progress() -> float:
	var world_progress := get_progress()
	var item_progress_values: Array = []
	var item_status := get_item_database_status(item_progress_values)
	var item_progress := 0.0
	if item_status == ResourceLoader.THREAD_LOAD_LOADED:
		item_progress = 1.0
	elif not item_progress_values.is_empty():
		item_progress = clampf(float(item_progress_values[0]), 0.0, 1.0)
	return clampf(
		world_progress * 0.60
		+ item_progress * 0.10
		+ get_visual_progress() * 0.30,
		0.0,
		1.0
	)


static func is_ready() -> bool:
	pump()
	return _loaded_scene != null and _loaded_item_database != null


static func is_fully_warmed() -> bool:
	pump()
	return (
		_loaded_scene != null
		and _loaded_item_database != null
		and _visual_requests_prepared
		and _visual_launch_index >= _visual_paths.size()
		and _visual_in_flight.is_empty()
	)


static func get_loaded_scene() -> PackedScene:
	if _loaded_scene != null:
		return _loaded_scene
	if get_status() != ResourceLoader.THREAD_LOAD_LOADED:
		return null
	if _capture_loaded_scene() != OK:
		return null
	return _loaded_scene


static func get_loaded_item_database_script() -> Script:
	if _loaded_item_database != null:
		return _loaded_item_database
	if get_item_database_status() != ResourceLoader.THREAD_LOAD_LOADED:
		return null
	if _capture_loaded_item_database() != OK:
		return null
	return _loaded_item_database


static func get_last_error() -> Error:
	if _last_error != OK:
		return _last_error
	return _item_database_last_error


static func _capture_loaded_scene() -> Error:
	var loaded_resource := ResourceLoader.load_threaded_get(WORLD_SCENE_PATH)
	if loaded_resource is PackedScene:
		_loaded_scene = loaded_resource as PackedScene
		_request_started = true
		_last_error = OK
		return OK

	_loaded_scene = null
	_request_started = false
	_last_error = ERR_CANT_OPEN
	return _last_error


static func _capture_loaded_item_database() -> Error:
	var loaded_resource := ResourceLoader.load_threaded_get(ITEM_DATABASE_PATH)
	if loaded_resource is Script:
		_loaded_item_database = loaded_resource as Script
		_item_database_request_started = true
		_item_database_last_error = OK
		return OK

	_loaded_item_database = null
	_item_database_request_started = false
	_item_database_last_error = ERR_CANT_OPEN
	return _item_database_last_error
