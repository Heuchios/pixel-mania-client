extends "res://Scripts/player.gd"
var fixture_world = null
func get_world_controller(): return fixture_world
func is_floor_support_block_type(_world, block_type: String) -> bool: return block_type == "dirt"
func _ready(): pass
func _process(_delta): pass
func _physics_process(_delta): pass
