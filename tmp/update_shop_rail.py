from pathlib import Path
p=Path('Scripts/ui/shop_scene_redesign.gd');s=p.read_text(encoding='utf-8')
s=s.replace('var _shop_fit_scale := 1.0','var _shop_fit_scale := 1.0\nvar category_rail: Panel\nvar category_scroll: ScrollContainer\nconst CATEGORY_RAIL_WIDTH := 140.0\nconst CATEGORY_RAIL_GAP := 16.0')
a=s.index('\t# Keep categories reachable');b=s.index('\tcategory_title_label.custom_minimum_size',a)
s=s[:a]+'''	# Detached inventory-style rail; it shares the window's scale and fit budget.
	category_rail = Panel.new()
	category_rail.name = "CategoryRail"
	category_rail.add_theme_stylebox_override("panel", preload("res://Scripts/ui/pixel_ui_style.gd").section_style())
	add_child(category_rail)
	move_child(category_rail, shop_window.get_index())
	category_scroll = ScrollContainer.new()
	category_scroll.name = "CategoryScroll"
	category_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	category_rail.add_child(category_scroll)
	sidebar.reparent(category_scroll)
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar.add_theme_constant_override("separation", 10)
	for button in _sidebar_buttons:
		button.custom_minimum_size = Vector2(116, 58)
		button.custom_maximum_size = Vector2(-1, -1)
		button.set_meta("preserve_selected_style", true)
		button.set_meta("pixelmania_font_size", 15)
		var normal := StyleBoxEmpty.new()
		var selected := StyleBoxFlat.new()
		selected.bg_color = Color("573164")
		selected.border_color = Color("e6c7ef")
		selected.border_width_left = 3
		var hover := StyleBoxFlat.new()
		hover.bg_color = Color("46264f")
		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", selected)
		button.add_theme_stylebox_override("hover_pressed", selected)
		button.add_theme_stylebox_override("focus", selected)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			button.add_theme_color_override(state, Color.WHITE)
''' +s[b:]
s=s.replace('\t\t_wire_hover_lift(button)','\t\t# Keep category tabs aligned while hovering.',1)
s=s.replace('\t_play_panel_open(shop_window)','\t# Fit the detached rail and window together; popups retain their open animation.',1)
a=s.index('\tvar available := Vector2(maxf(616.0');b=s.index('\tfor popup in [detail_card, reward_card]:',a)
s=s[:a]+'''	var rail_space := CATEGORY_RAIL_WIDTH + CATEGORY_RAIL_GAP
	var available := Vector2(maxf(772.0, size.x - 24.0), maxf(300.0, size.y - 24.0))
	var group_size := Vector2(minf(1100.0, available.x), minf(700.0, available.y))
	shop_window.size = Vector2(group_size.x - rail_space, group_size.y)
	_shop_fit_scale = minf(1.0, minf(maxf(1.0, size.x - 24.0) / group_size.x, maxf(1.0, size.y - 24.0) / group_size.y))
	var origin := (size - group_size * _shop_fit_scale) * 0.5
	shop_window.pivot_offset = Vector2.ZERO
	shop_window.scale = Vector2.ONE * _shop_fit_scale
	shop_window.position = origin + Vector2(rail_space * _shop_fit_scale, 0)
	category_rail.size = Vector2(CATEGORY_RAIL_WIDTH, group_size.y)
	category_rail.scale = Vector2.ONE * _shop_fit_scale
	category_rail.position = origin
	category_scroll.position = Vector2(12, 18)
	category_scroll.size = category_rail.size - Vector2(24, 36)
	_reflow_product_grid.call_deferred()
''' +s[b:]
s=s.replace('\tvar body := $ShopWindow/Margin/Layout/Body as HBoxContainer\n','')
s=s.replace('\tcontent_width -= sidebar.get_parent().size.x + body.get_theme_constant("separation")\n','')
p.write_text(s,encoding='utf-8')
