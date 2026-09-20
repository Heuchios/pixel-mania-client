extends "res://Scripts/login_screen.gd"

func _ready() -> void:
	_bind_login_scene_ui()
	_update_server_status_indicator(true)
	_render_login_news([])

func _process(_delta: float) -> void:
	pass
