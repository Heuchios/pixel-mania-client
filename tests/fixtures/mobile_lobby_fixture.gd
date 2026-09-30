extends "res://tests/lobby_ui_fixture.gd"

var mobile := false

func _is_mobile_lobby() -> bool:
	return mobile

func _process(delta: float) -> void:
	super._process(delta)
	_update_lobby_parallax_background(delta)
	_layout_mobile_lobby()
	if mobile:
		get_node("/root/MobileUIScale").apply_branch(self, get_viewport_rect().size)
