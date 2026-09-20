extends "res://Scripts/ui/lobby_scene.gd"

var joined_world := ""
var saved_favorites: Array[String] = []
var event_requests := 0

func _ready() -> void:
	DesignBox.attach(self)
	_setup_lobby_parallax_background()
	_bind_scene_nodes()
	_setup_active_world_list()
	_connect_scene_buttons()
	_add_landfill_buttons()

func _process(delta: float) -> void:
	_update_lobby_button_animation(delta)

func _join_world_name(world_name: String) -> void:
	joined_world = world_name

func _save_favorite_world_names() -> void:
	saved_favorites.assign(favorite_world_names)

func _load_recent_world_names() -> Array[String]:
	return ["LAST", "EARLIER"]

func _request_owned_worlds_refresh() -> void:
	pass

func _on_landfill_join_pressed() -> void:
	event_requests += 1
