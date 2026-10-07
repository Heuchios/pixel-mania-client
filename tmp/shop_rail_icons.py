from pathlib import Path
p=Path('Scripts/ui/shop_scene_redesign.gd');s=p.read_text(encoding='utf-8');s=s.replace('Vector2(116, 58)','Vector2(116, 82)',1)
needle='\tcategory_title_label.custom_minimum_size = Vector2(0, 40)'
s=s.replace(needle,'''	var category_icons := [
		preload("res://Scripts/UIAtlasDB.gd").get_texture("inv_tab_all"),
		preload("res://Assets/currency/gem.png"),
		preload("res://Assets/ui/icons/shop_cat_locks.png"),
		preload("res://Assets/ui/icons/shop_cat_stations.png"),
		preload("res://Scripts/UIAtlasDB.gd").get_texture("inv_tab_clothes"),
		preload("res://Scripts/UIAtlasDB.gd").get_texture("inv_tab_tools"),
		preload("res://Assets/ui/icons/shop_cat_fishing.png"),
	]
	for i in range(_sidebar_buttons.size()):
		var button := _sidebar_buttons[i]
		var caption := Label.new()
		caption.text = button.text
		caption.position = Vector2(0, 54)
		caption.size = Vector2(116, 24)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.set_meta("pixelmania_font_size", 14)
		button.text = ""
		button.add_child(caption)
		var icon := TextureRect.new()
		icon.texture = category_icons[i]
		icon.position = Vector2(40, 10)
		icon.size = Vector2(36, 36)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
'''+needle,1);p.write_text(s,encoding='utf-8')
