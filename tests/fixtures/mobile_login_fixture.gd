extends "res://Scripts/login_screen.gd"

func _ready() -> void:
	assert(_bind_login_scene_ui())
	empty_news_label.text = "No news yet."

func _process(_delta: float) -> void:
	_layout_mobile_login()
