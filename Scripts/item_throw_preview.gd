extends Node2D

const EFFECT := preload("res://Scenes/particles/BloodBattleaxeThrowFX.tscn")
var _timer := 0.0


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("18202d"))
	var camera := Camera2D.new()
	camera.position = Vector2(240, 135)
	camera.zoom = Vector2(3, 3)
	add_child(camera)
	var label := Label.new()
	label.text = "BLOOD BATTLEAXE\nMiniature spinning throw"
	label.position = Vector2(115, 45)
	label.add_theme_font_size_override("font_size", 16)
	add_child(label)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 1.8
	for facing in [-1, 1]:
		var effect := EFFECT.instantiate()
		add_child(effect)
		var start := Vector2(240 - facing * 80, 135 if facing == 1 else 195)
		effect.launch_to(start, start + Vector2(facing * 160, 0), facing)
