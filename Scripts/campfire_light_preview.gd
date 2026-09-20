extends Node2D


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("18202d"))
	var camera := Camera2D.new()
	camera.position = Vector2(240, 135)
	camera.zoom = Vector2(3, 3)
	add_child(camera)
	var atlas_db = load("res://Scripts/ItemAtlasDB.gd")
	var fire := Sprite2D.new()
	fire.texture = atlas_db.get_item_icon(atlas_db.get_item_id_for_key("campfire"))
	fire.position = Vector2(240, 150)
	add_child(fire)
	var light := preload("res://Scenes/particles/CampfireLightFX.tscn").instantiate()
	light.position = fire.position + Vector2(0, -5)
	add_child(light)
	var label := Label.new()
	label.position = Vector2(114, 35)
	label.text = "CAMPFIRE / WARM FLICKER"
	label.add_theme_font_size_override("font_size", 14)
	add_child(label)


func _draw() -> void:
	# Neutral surfaces make the actual Light2D contribution easy to inspect.
	for column in range(10):
		for row in range(5):
			var tile_position := Vector2(80 + column * 32, 75 + row * 32)
			draw_rect(Rect2(tile_position, Vector2(31, 31)), Color("343943"))
	for column in range(10):
		draw_rect(Rect2(80 + column * 32, 166, 31, 31), Color("737680"))
