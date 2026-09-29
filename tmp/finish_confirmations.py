from pathlib import Path
p=Path('Scripts/area_lock_ui.gd');s=p.read_text(encoding='utf-8').replace('info_label.custom_minimum_size.y = 142','info_label.custom_minimum_size.y = 110');s=s.replace('$Panel/VBox/InfoPanel.add_theme_stylebox_override("panel", PixelUIStyle.section_style())','''var info_style := StyleBoxFlat.new()
	info_style.bg_color = Color("24112d")
	info_style.border_color = Color("92659e")
	info_style.set_border_width_all(2)
	info_style.content_margin_left = 16
	info_style.content_margin_right = 16
	info_style.content_margin_top = 12
	info_style.content_margin_bottom = 12
	$Panel/VBox/InfoPanel.add_theme_stylebox_override("panel", info_style)
	$Panel/VBox/AccessScroll.add_theme_stylebox_override("panel", info_style.duplicate())''');s=s.replace('toggle.custom_minimum_size.y = 44','PixelUIStyle.apply_atlas_button(toggle, "blue_button")\n\t\ttoggle.custom_minimum_size.y = 44');p.write_text(s,encoding='utf-8')
p=Path('tmp/confirmation_layout_preview.gd');s=p.read_text(encoding='utf-8').replace('vend.stock_spin.value=100','vend.stock_spin.value=100\n\tvend.stock_spin.get_line_edit().text="100"');p.write_text(s,encoding='utf-8')
