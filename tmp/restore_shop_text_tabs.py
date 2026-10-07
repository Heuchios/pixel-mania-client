from pathlib import Path
p=Path('Scripts/ui/shop_scene_redesign.gd')
s=p.read_text(encoding='utf-8')
a=s.index('\tfor button in _sidebar_buttons:',s.index('func _ready()'))
b=s.index('\tcategory_title_label.custom_minimum_size',a)
s=s[:a]+'''	for button in _sidebar_buttons:
		# Keep the scene's original pink text-button and selected-tab styles.
		button.custom_minimum_size = Vector2(140, 48)
		button.custom_maximum_size = Vector2(-1, -1)
		button.set_meta("preserve_selected_style", true)
		button.set_meta("pixelmania_font_size", 16)
'''+s[b:]
s=s.replace('const CATEGORY_RAIL_WIDTH := 140.0','const CATEGORY_RAIL_WIDTH := 164.0')
p.write_text(s,encoding='utf-8')
