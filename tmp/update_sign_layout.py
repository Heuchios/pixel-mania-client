from pathlib import Path
p=Path('Scripts/sign_ui.gd');s=p.read_text(encoding='utf-8')
s=s.replace('\tupdate_panel_position()\n\tupdate_char_count()\n\n\nfunc setup_panel()', '\tif is_sign_open():\n\t\tupdate_panel_position()\n\n\nfunc setup_panel()',1)
s=s.replace('Vector2(620, 370)','Vector2(680, 468)')
s=s.replace('\t\tchild.queue_free()','\t\tpanel.remove_child(child)\n\t\tchild.queue_free()',1)
replacements={
'Vector2(14, 14)':'Vector2(16, 16)','Vector2(592, 56)':'Vector2(648, 64)',
'Vector2(34, 25)':'Vector2(34, 30)','Vector2(552, 24)':'Vector2(616, 26)',
'Vector2(26, 84)':'Vector2(16, 94)','Vector2(568, 44)':'Vector2(648, 52)',
'Write the message players will see when standing on this sign.':'Write a message for players who stand on this sign.',
'Vector2(42, 94)':'Vector2(34, 100)','Vector2(536, 24)':'Vector2(612, 40)',
'Vector2(26, 144)':'Vector2(16, 160)','Vector2(568, 132)':'Vector2(648, 220)',
'Vector2(42, 158)':'Vector2(32, 200)','Vector2(536, 102)':'Vector2(616, 164)',
'Vector2(42, 282)':'Vector2(32, 410)','Vector2(250, 22)':'Vector2(260, 24)',
'Vector2(316, 306)':'Vector2(380, 402)','Vector2(458, 306)':'Vector2(522, 402)',
'PixelUIStyle.apply_yellow_button(save_button, 16)':'PixelUIStyle.apply_atlas_button(save_button, "green_button")',
'PixelUIStyle.style_box(PixelUIStyle.GLASS_SECTION, PixelUIStyle.GLASS_BORDER, 4, 14, 5)':'PixelUIStyle.section_style()',
}
for a,b in replacements.items():s=s.replace(a,b)
s=s.replace('\tinfo_label.vertical_alignment', '\tinfo_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART\n\tinfo_label.vertical_alignment',1)
s=s.replace('\tpanel.add_child(input_back)','''\tpanel.add_child(input_back)

	var message_label := Label.new()
	message_label.name = "MessageLabel"
	message_label.text = "SIGN MESSAGE"
	message_label.position = Vector2(32, 172)
	message_label.size = Vector2(616, 24)
	PixelUIStyle.apply_small_label(message_label, 14)
	message_label.set_meta("pixelmania_font_size", 14)
	panel.add_child(message_label)

	var footer := Panel.new()
	footer.name = "Footer"
	footer.position = Vector2(16, 394)
	footer.size = Vector2(648, 58)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_theme_stylebox_override("panel", PixelUIStyle.section_style())
	panel.add_child(footer)''',1)
s=s.replace('\tpanel.add_child(sign_text_edit)','\tsign_text_edit.text_changed.connect(update_char_count)\n\tpanel.add_child(sign_text_edit)',1)
s=s.replace('\tvar normal_style = PixelUIStyle.style_box(PixelUIStyle.GLASS_INPUT, PixelUIStyle.GLASS_BORDER, 3, 10, 4)\n\tvar focus_style = PixelUIStyle.style_box(PixelUIStyle.GLASS_INPUT_FOCUS, Color(0.85, 0.96, 1.0, 0.94), 3, 10, 6)', '''\ttext_edit.set_meta("pixelmania_font_size", 17)
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color("1c0b24")
	normal_style.border_color = Color("92659e")
	normal_style.set_border_width_all(2)
	normal_style.content_margin_left = 12
	normal_style.content_margin_right = 12
	normal_style.content_margin_top = 10
	normal_style.content_margin_bottom = 10
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color.TRANSPARENT
	focus_style.border_color = Color("e7c9ef")
	focus_style.set_border_width_all(2)''')
s=s.replace('\t\tsign_text_edit.text = current_text','\t\tsign_text_edit.text = current_text',1)
s=s.replace('\tsign_grid_pos = grid_pos','\tsign_grid_pos = grid_pos\n\tupdate_panel_position()',1)
s=s.replace('\tpanel.position = Vector2((screen_size.x - panel.size.x) / 2.0, max(50.0, (screen_size.y - panel.size.y) / 2.0))','\tvar fit_scale: float = minf(1.0, minf((screen_size.x - 24.0) / panel.size.x, (screen_size.y - 24.0) / panel.size.y))\n\tpanel.scale = Vector2.ONE * maxf(0.1, fit_scale)\n\tpanel.position = (screen_size - panel.size * panel.scale) / 2.0')
p.write_text(s,encoding='utf-8')
