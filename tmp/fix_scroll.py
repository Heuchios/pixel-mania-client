from pathlib import Path
p=Path('Scripts/ui/fish_monger_ui.gd');t=p.read_text();a=t.index('\tvar scrollbar = fish_scroll.get_v_scroll_bar()',t.index('func apply_fish_monger_scrollbar_style'));b=t.index('\n\nfunc get_fish_row_content_width',a);t=t[:a]+'''	var scrollbar = fish_scroll.get_v_scroll_bar()
	scrollbar.custom_minimum_size.x = 12
	scrollbar.add_theme_stylebox_override("scroll", PixelUIStyle.atlas_style("scroll_bar", Color.WHITE, 0))
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		var thumb := PixelUIStyle.atlas_style("scroll_handle", Color.WHITE, 0)
		thumb.expand_margin_left = -2
		thumb.expand_margin_right = -2
		scrollbar.add_theme_stylebox_override(state, thumb)
''' +t[b:];t=t.replace('fish_rows_root.mouse_filter = Control.MOUSE_FILTER_IGNORE','fish_rows_root.mouse_filter = Control.MOUSE_FILTER_PASS');t=t.replace('fish_scroll.clip_contents = true','fish_scroll.clip_contents = true\n\tfish_scroll.mouse_filter = Control.MOUSE_FILTER_STOP\n\tfish_scroll.scroll_deadzone = 8');t=t.replace('var row := _surface(fish_rows_root, "FishRow_" + item_id, Rect2(row_position, Vector2(row_width, row_height)), true)','var row := _surface(fish_rows_root, "FishRow_" + item_id, Rect2(row_position, Vector2(row_width, row_height)), true)\n\trow.mouse_filter = Control.MOUSE_FILTER_PASS');p.write_text(t)
p=Path('Scripts/ui/mobile_scroll_policy.gd');t=p.read_text().replace('\tif not (OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()):\n\t\treturn\n','');t=t.replace('if control is ScrollContainer or control.mouse_filter != Control.MOUSE_FILTER_STOP:', 'if control is ScrollContainer:\n\t\tif not control.get_meta("custom_touch_scroll", false):\n\t\t\tcontrol.scroll_deadzone = 8\n\t\treturn\n\tif control.mouse_filter != Control.MOUSE_FILTER_STOP:');p.write_text(t)
p=Path('Scripts/input_manager.gd');t=p.read_text();a=t.index('func handle_input(event):');b=t.index('func handle_unhandled_input',a);chunk=t[a:b].replace('if _is_gameplay_ui_at_point(event.position):\n\t\t\t\tworld.get_viewport().set_input_as_handled()\n\t\t\t\treturn','if _is_gameplay_ui_at_point(event.position):\n\t\t\t\t# GUI scroll containers must receive the wheel before unhandled input.\n\t\t\t\treturn');p.write_text(t[:a]+chunk+t[b:])
