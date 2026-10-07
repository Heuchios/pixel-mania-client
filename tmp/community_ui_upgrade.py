from pathlib import Path
p=Path('Scripts/donation_box_ui.gd');s=p.read_text(encoding='utf-8')
a=s.index('\tvar viewport_size := get_view_size()',s.index('func build_ui'))
b=s.index('\n\toverlay =',a)
s=s[:a]+'\tvar actual_panel_size := preferred_panel_size\n'+s[b:]
s=s.replace('PixelUIStyle.style_box(PixelUIStyle.GLASS_PANEL_STRONG, PixelUIStyle.GLASS_BORDER_BRIGHT, 4, 18, 16)','PixelUIStyle.panel_style()')
s=s.replace('header.size = Vector2(actual_panel_size.x, 94)','header.size = Vector2(actual_panel_size.x, 94)\n\theader.visible = false')
s=s.replace('top_line.color = accent_color','top_line.color = accent_color\n\ttop_line.visible = false')
s=s.replace('PixelUIStyle.apply_label_shadow(title, 44 if actual_panel_size.x >= 850 else 34)','title.set_meta("pixelmania_font_size", 38)\n\ttitle.set_meta("pixelmania_text_shadow", false)\n\tPixelUIStyle.apply_label_shadow(title, 38, Color("321b3d"))')
s=s.replace('PixelUIStyle.apply_small_label(subtitle, 13)','subtitle.set_meta("pixelmania_text_shadow", false)\n\tsubtitle.set_meta("pixelmania_font_size", 16)\n\tPixelUIStyle.apply_label_shadow(subtitle, 16, Color("321b3d"))')
s=s.replace('apply_button_style(close_button, false, true, 24)','PixelUIStyle.apply_close_button(close_button)')
s=s.replace('PixelUIStyle.apply_label_shadow(status_label, 16)','status_label.set_meta("pixelmania_text_shadow", false)\n\tstatus_label.set_meta("pixelmania_font_size", 18)\n\tPixelUIStyle.apply_label_shadow(status_label, 18, Color("321b3d"))')
s=s.replace('apply_button_style(donate_button, true, false, 17)','PixelUIStyle.apply_atlas_button(donate_button, "green_button")')
s=s.replace('"RETRIEVE ALL DONATIONS"','"RETRIEVE ALL"')
s=s.replace('hint_label.position = Vector2(552, action_y + 3)','hint_label.position = Vector2(30, 168)').replace('hint_label.size = Vector2(max(140.0, actual_panel_size.x - 582.0), 44)','hint_label.size = Vector2(actual_panel_size.x - 60, 32)').replace('hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT','hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT')
s=s.replace('PixelUIStyle.apply_small_label(hint_label, 12)','hint_label.set_meta("pixelmania_text_shadow", false)\n\thint_label.set_meta("pixelmania_font_size", 15)\n\tPixelUIStyle.apply_label_shadow(hint_label, 15, Color("321b3d"))')
s=s.replace('card.position = Vector2(30, 174)','card.position = Vector2(30, 210)').replace('actual_panel_size.y - 204.0','actual_panel_size.y - 240.0').replace('PixelUIStyle.style_box(PixelUIStyle.GLASS_SECTION, PixelUIStyle.GLASS_BORDER, 3, 14, 10)','PixelUIStyle.section_style()')
a=s.index('\tvar panel_position :=',s.index('func update_position'))
b=s.index('\n\n\nfunc has_donation_box',a)
s=s[:a]+'''\tvar fit := minf(1.0, minf((viewport_size.x - 24) / panel.size.x, (viewport_size.y - 24) / panel.size.y))
	panel.scale = Vector2.ONE * maxf(0.1, fit)
	panel.position = (viewport_size - panel.size * panel.scale) * 0.5
	if panel_shadow != null:
		panel_shadow.visible = false
'''+s[b:]
s=s.replace('PixelUIStyle.style_box(card_fill_color, card_border_color, 3, 9, 7)','PixelUIStyle.section_style()').replace('PixelUIStyle.style_box(card_fill_color.lightened(0.10), accent_border_color, 4, 9, 9)','PixelUIStyle.atlas_style("inner_panel", Color(1.18, 1.18, 1.18), 3)').replace('PixelUIStyle.style_box(card_fill_color.darkened(0.14), accent_color, 3, 9, 5)','PixelUIStyle.section_style()')
s=s.replace('var icon := TextureRect.new()','''var slot := Panel.new()
	slot.position = Vector2(10, 10)
	slot.size = Vector2(68, 68)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rarity := "common"
	if world != null and "item_database" in world:
		rarity = str(world.item_database.get(item_id, {}).get("rarity", "common"))
	slot.add_theme_stylebox_override("panel", PixelUIStyle.slot_style(rarity))
	button.add_child(slot)
	var icon := TextureRect.new()''')
s=s.replace('icon.position = Vector2(12, 12)','icon.position = Vector2(16, 16)').replace('icon.size = Vector2(62, 62)','icon.size = Vector2(56, 56)\n\ticon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST')
s=s.replace('"x" + str(max(1, int(entry.get("amount", 1))))','str(max(1, int(entry.get("amount", 1))))')
s=s.replace('PixelUIStyle.apply_label_shadow(name_label, 14)','name_label.set_meta("pixelmania_font_size", 16)\n\tPixelUIStyle.apply_label_shadow(name_label, 16)')
p.write_text(s,encoding='utf-8')
p=Path('Scripts/bulletin_board_ui.gd');s=p.read_text(encoding='utf-8').replace('Vector2(760, 560)','Vector2(760, 600)')
a=s.index('\tpanel.add_theme_stylebox_override("panel", PixelUIStyle.style_box(');b=s.index('\n\tadd_child(panel)',a)
s=s[:a]+'\tpanel.add_theme_stylebox_override("panel", PixelUIStyle.panel_style())'+s[b:]
s=s.replace('PixelUIStyle.apply_label_shadow(title_label, 34)','title_label.set_meta("pixelmania_font_size", 38)\n\ttitle_label.set_meta("pixelmania_text_shadow", false)\n\tPixelUIStyle.apply_label_shadow(title_label, 38, Color("321b3d"))')
s=s.replace('PixelUIStyle.apply_small_label(status_label, 15)','status_label.set_meta("pixelmania_text_shadow", false)\n\tstatus_label.set_meta("pixelmania_font_size", 16)\n\tPixelUIStyle.apply_label_shadow(status_label, 16, Color("321b3d"))')
s=s.replace('panel.add_child(messages_scroll)','messages_scroll.add_theme_stylebox_override("panel", PixelUIStyle.section_style())\n\tpanel.add_child(messages_scroll)')
s=s.replace('message_input = TextEdit.new()','message_input = TextEdit.new()\n\tmessage_input.placeholder_text = "Write a message for visitors..."')
s=s.replace('PixelUIStyle.apply_small_label(count_label, 14)','count_label.set_meta("pixelmania_text_shadow", false)\n\tPixelUIStyle.apply_label_shadow(count_label, 14, Color("321b3d"))')
s=s.replace('PixelUIStyle.apply_yellow_button(post_button, 18)','PixelUIStyle.apply_atlas_button(post_button, "green_button")')
s=s.replace('close_button.size = Vector2(42, 38)','close_button.size = Vector2(48, 48)')
a=s.index('\tvar target_size :=',s.index('func update_position'));b=s.index('\n\n\nfunc open_bulletin_board',a)
s=s[:a]+'''\tpanel.size = PANEL_BASE_SIZE
	var fit := minf(1.0, minf((screen_size.x - 24) / panel.size.x, (screen_size.y - 24) / panel.size.y))
	panel.scale = Vector2.ONE * maxf(0.1, fit)
	panel.position = (screen_size - panel.size * panel.scale) * 0.5
'''+s[b:]
s=s.replace('for child in messages_root.get_children():\n\t\tchild.queue_free()','for child in messages_root.get_children():\n\t\tmessages_root.remove_child(child)\n\t\tchild.queue_free()')
s=s.replace('add_empty_row("No posts yet.")','add_empty_row("No posts yet.\\nLeave the first message below.")')
s=s.replace('row.text = text','row.text = text\n\trow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER\n\trow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER').replace('Vector2(messages_root.custom_minimum_size.x, 0)','Vector2(messages_root.custom_minimum_size.x, 180)')
a=s.index('\tcard.add_theme_stylebox_override("panel", PixelUIStyle.style_box(');b=s.index('\n\tcard.size_flags_horizontal',a)
s=s[:a]+'''\tcard.set_meta("pixelmania_panel_shadow", false)
	var post_style := StyleBoxFlat.new()
	post_style.bg_color = Color("24112e")
	post_style.border_color = Color("92749f")
	post_style.set_border_width_all(2)
	card.add_theme_stylebox_override("panel", post_style)'''+s[b:]
s=s.replace('header.size_flags_horizontal = Control.SIZE_EXPAND_FILL','header.size_flags_horizontal = Control.SIZE_EXPAND_FILL\n\theader.clip_text = true\n\theader.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS\n\theader.set_meta("pixelmania_font_size", 16)')
s=s.replace('PixelUIStyle.apply_small_label(body, 16)','body.set_meta("pixelmania_font_size", 18)\n\tPixelUIStyle.apply_small_label(body, 18)')
s=s.replace('count_label.text = str(length) + "/" + str(MAX_MESSAGE_LENGTH)','count_label.text = str(length) + "/" + str(MAX_MESSAGE_LENGTH)\n\tif post_button != null:\n\t\tpost_button.disabled = message_input == null or message_input.text.strip_edges().is_empty() or is_anti_talk_blocking_post()')
p.write_text(s,encoding='utf-8')
