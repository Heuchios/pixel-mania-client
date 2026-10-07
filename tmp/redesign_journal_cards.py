from pathlib import Path
p=Path('Scripts/ui/fishing_journal_ui.gd');s=p.read_text(encoding='utf-8').replace('const CARD_W := 288.0','const CARD_W := 432.0').replace('const CARD_H := 212.0','const CARD_H := 202.0').replace('cards_root.columns = 3','cards_root.columns = 2')
a=s.index('func _create_fish_card(');b=s.index('\n\nfunc _format_weight',a)
s=s[:a]+'''func _create_fish_card(entry: Dictionary) -> void:
	var discovered := bool(entry.get("discovered", false))
	var rarity := str(entry.get("rarity", "common")).to_lower()
	var accent := _rarity_color(rarity) if discovered else Color("786480")
	var card := Panel.new()
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", PixelUIStyle.atlas_style("outer_panel", Color.WHITE if discovered else Color("95859d"), 3))
	cards_root.add_child(card)
	_journal_panel(card, "Inner", Rect2(4, 4, CARD_W - 8, CARD_H - 8), PixelUIStyle.section_style())
	var art_style := StyleBoxFlat.new()
	art_style.bg_color = Color("22132e").lerp(accent, 0.13 if discovered else 0.02)
	art_style.border_color = accent
	art_style.border_width_bottom = 3
	_journal_panel(card, "FishDisplay", Rect2(16, 16, 136, 114), art_style)
	var icon := TextureRect.new()
	icon.name = "FishArtwork"
	icon.position = Vector2(28, 30)
	icon.size = Vector2(112, 84)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var icon_value = entry.get("icon", null)
	icon.texture = icon_value as Texture2D if icon_value is Texture2D else null
	if icon.texture != null:
		var image := icon.texture.get_image()
		if image != null and image.get_used_rect().has_area():
			var artwork := AtlasTexture.new()
			artwork.atlas = icon.texture
			artwork.region = Rect2(image.get_used_rect())
			artwork.filter_clip = true
			icon.texture = artwork
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = Color.WHITE if discovered else Color(0.05, 0.02, 0.08, 0.9)
	card.add_child(icon)
	if not discovered:
		var mystery := _journal_text(card, "Mystery", "?", Rect2(28, 30, 112, 84), 32, Color("c9b5d2"))
		mystery.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_journal_text(card, "FishName", "UNDISCOVERED", Rect2(168, 24, 246, 36), 19, Color("c9b5d2"))
		_journal_text(card, "DiscoveryHint", "Your next catch could fill this page.", Rect2(168, 64, 244, 60), 16, PixelUIStyle.TEXT_SOFT)
		_journal_text(card, "LockedRecords", "Catch this fish to reveal its records.", Rect2(20, 148, 392, 36), 15, Color("a58cb1"))
		return
	var name_label := _journal_text(card, "FishName", str(entry.get("name", "Fish")), Rect2(168, 16, 246, 54), 22, Color.WHITE)
	name_label.tooltip_text = name_label.text
	_journal_text(card, "Rarity", rarity.to_upper(), Rect2(168, 72, 246, 24), 15, accent)
	_journal_text(card, "Habitat", str(entry.get("location", "Any Water")), Rect2(168, 101, 246, 28), 15, PixelUIStyle.TEXT_SOFT)
	var record_values := [str(int(entry.get("total_caught", 0))), _format_weight(float(entry.get("biggest_weight", 0.0))), str(int(entry.get("best_value", 0))) + " gems"]
	var record_titles := ["CAUGHT", "BIGGEST", "BEST VALUE"]
	for i in range(3):
		var x := 16.0 + i * 136.0
		var record_style := StyleBoxFlat.new()
		record_style.bg_color = Color("24112e")
		_journal_panel(card, "Record%d" % i, Rect2(x, 142, 128, 44), record_style)
		_journal_text(card, "RecordTitle%d" % i, record_titles[i], Rect2(x + 8, 146, 112, 15), 11, Color("b8a3c5"))
		_journal_text(card, "RecordValue%d" % i, record_values[i], Rect2(x + 8, 162, 112, 22), 16, Color.WHITE)


func _journal_panel(parent: Control, node_name: String, bounds: Rect2, style: StyleBox) -> void:
	var section := Panel.new()
	section.name = node_name
	section.position = bounds.position
	section.size = bounds.size
	section.mouse_filter = Control.MOUSE_FILTER_IGNORE
	section.add_theme_stylebox_override("panel", style)
	parent.add_child(section)


func _journal_text(parent: Control, node_name: String, text: String, bounds: Rect2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.position = bounds.position
	label.size = bounds.size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.clip_text = true
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_meta("pixelmania_font_size", font_size)
	PixelUIStyle.apply_label_shadow(label, font_size, color)
	parent.add_child(label)
	return label
'''+s[b:];p.write_text(s,encoding='utf-8')
