extends SceneTree
func _initialize():
	call_deferred("run")
func run():
	var crafting = load("res://Scripts/crafting_ui.gd").new()
	for style in [crafting.station_panel_style(), crafting.station_header_style(), crafting.station_section_style(), crafting.station_chip_style()]:
		assert(style is StyleBoxTexture)
		assert(style.modulate_color.a == 1.0)
	assert(crafting.station_panel_style().get_meta("atlas_region") == "outer_panel")
	var card := Panel.new()
	for ready in [true, false]:
		crafting.apply_station_card_style(card, ready)
		assert(card.get_theme_stylebox("panel").modulate_color.a == 1.0)
	card.free()
	crafting.free()
	print("CRAFTING_STYLE_OK")
	quit()
