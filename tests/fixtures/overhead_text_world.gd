extends "res://Scripts/world.gd"

var camera := Camera2D.new()

func _ready() -> void:
	set_process(false)
	set_physics_process(false)

func get_player_camera(): return camera
func is_movement_blocking_ui_open() -> bool: return false
