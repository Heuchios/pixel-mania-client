extends "res://Scripts/world.gd"
## Exercise the real cosmetic routing without starting a world/server session.


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
