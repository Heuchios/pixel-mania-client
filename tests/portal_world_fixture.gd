extends "res://Scripts/world.gd"

var flushed_position := Vector2.ZERO
func _ready(): pass
func _process(_delta): pass
func _physics_process(_delta): pass
func get_player_camera(): return null
func flush_multiplayer_position(_allow_join: bool = false, _bypass_rate_limit: bool = false) -> bool:
	flushed_position = player.global_position
	return true
