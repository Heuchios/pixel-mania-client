extends "res://Scripts/world.gd"

func _ready(): pass
func _process(_delta): pass
func _physics_process(_delta): pass
func should_use_server_authoritative_world_actions() -> bool: return true
func play_player_place_animation(): pass
func spawn_tree_growth_particles(_grid: Vector2i, _type: String = "", _stage: int = 0): pass
func spawn_tree_break_particles(_grid: Vector2i, _type: String = ""): pass
func show_notification(_message): pass
func play_sound_hit(_position): pass
func play_sound_place(_position: Vector2 = Vector2.ZERO): pass
func play_sound_break(_position: Vector2 = Vector2.ZERO): pass
