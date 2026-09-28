from pathlib import Path
p=Path('Scripts/crafting_ui.gd');s=p.read_text(encoding='utf-8')
s=s.replace('Vector2(1080, 700)','Vector2(1080, 760)').replace('Vector2(470, 212)','Vector2(470, 240)').replace('144 + recipe.cost.size() * 34','168 + recipe.cost.size() * 34')
s=s.replace('Select a recipe to craft one item.','Each craft gives the quantity shown on the recipe.')
s=s.replace('Vector2(8, 8)','Vector2(20, 16)').replace('Vector2(panel.size.x - 16.0, 84)','Vector2(panel.size.x - 40.0, 80)')
s=s.replace('\ttop_line.color =', '\ttop_line.visible = false\n\ttop_line.color =',1)
s=s.replace('\tfor child in recipe_root.get_children():\n\t\tchild.queue_free()','\tfor child in recipe_root.get_children():\n\t\trecipe_root.remove_child(child)\n\t\tchild.queue_free()')
s=s.replace('\tinfo_label = _card_label', '''	var footer := Panel.new()
	footer.name = "Footer"
	footer.position = Vector2(32, panel.size.y - 42)
	footer.size = Vector2(panel.size.x - 64, 30)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_theme_stylebox_override("panel", station_section_style())
	panel.add_child(footer)
	info_label = _card_label''',1)
s=s.replace('\tcard.add_theme_stylebox_override("panel", PixelUIStyle.atlas_style("input_field"))','''	card.add_theme_stylebox_override("panel", PixelUIStyle.panel_style())''',1)
s=s.replace('\trecipe_root.add_child(card)\n\tvar icon_frame', '''	recipe_root.add_child(card)
	var inner := Panel.new()
	inner.name = "InnerPanel"
	inner.position = Vector2(3, 3)
	inner.size = card.size - Vector2(6, 6)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_stylebox_override("panel", station_section_style())
	card.add_child(inner)
	var icon_frame''',1)
s=s.replace('Vector2(90, 15), Vector2(360, 44), 22','Vector2(90, 14), Vector2(274, 42), 22')
s=s.replace('\ttitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART','\ttitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART\n\ttitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS\n\ttitle.max_lines_visible = 2',1)
s=s.replace('Vector2(90, 62), Vector2(350, 24), 13','Vector2(90, 58), Vector2(350, 24), 15')
s=s.replace('\tfor i in range(recipe.cost.size()):', '''	var output_count := _card_label(card, "OutputCount", "x%d" % int(output.amount), Vector2(376, 20), Vector2(76, 30), 22)
	output_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	output_count.modulate = Color("ffe577")
	_card_label(card, "MaterialsLabel", "INGREDIENTS", Vector2(20, 88), Vector2(260, 22), 13)
	var column_label := _card_label(card, "CountsLabel", "HAVE / NEED", Vector2(322, 88), Vector2(128, 22), 13)
	column_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for i in range(recipe.cost.size()):''',1)
s=s.replace('var row_y := 86.0 + i * 34.0','''var row_y := 112.0 + i * 34.0
		var row_back := Panel.new()
		row_back.position = Vector2(14, row_y)
		row_back.size = Vector2(442, 30)
		row_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var row_style := StyleBoxFlat.new()
		row_style.bg_color = Color("26122f")
		row_back.add_theme_stylebox_override("panel", row_style)
		card.add_child(row_back)''')
s=s.replace('button.text = "CRAFT ×%d" % int(output.amount) if can_make else "NEED MATERIALS"','button.text = "CRAFT x%d" % int(output.amount) if can_make else "NEED MATERIALS"')
s=s.replace('\tapply_station_arcade_button_style(button, true, false, 17)','\tPixelUIStyle.apply_atlas_button(button, "green_button" if can_make else "pink_button")\n\tbutton.set_meta("pixelmania_font_size", 17)',1)
p.write_text(s,encoding='utf-8')
