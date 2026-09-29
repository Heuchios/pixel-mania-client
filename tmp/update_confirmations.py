from pathlib import Path
import re
p=Path('Scenes/ui/vending/VendingMachineGUI.tscn');s=p.read_text(encoding='utf-8');idx=s.index('[node name="VendingUI"');s=s[:idx]+'[ext_resource type="Script" path="res://Scripts/ui/vending_purchase_confirmation.gd" id="purchase_modal"]\n\n'+s[idx:];s=re.sub(r'\[node name="PurchaseConfirmation".*?(?=\n\[)', '[node name="PurchaseConfirmation" type="Control" parent="."]\nscript = ExtResource("purchase_modal")\n',s,flags=re.S);p.write_text(s,encoding='utf-8')
p=Path('Scripts/vending_ui.gd');s=p.read_text(encoding='utf-8').replace('var purchase_confirmation: ConfirmationDialog','var purchase_confirmation');p.write_text(s,encoding='utf-8')
p=Path('Scripts/area_lock_ui.gd');s=p.read_text(encoding='utf-8')
s=s.replace('\t# Keep the authored atlas panel; legacy styling replaced it at runtime.', '''	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.size = Vector2(740, 650)
	var content = $Panel/VBox
	content.offset_left = 32
	content.offset_right = -32
	content.offset_top = 28
	content.offset_bottom = -28
	content.add_theme_constant_override("separation", 14)
	var inner := Panel.new()
	inner.name = "InnerPanel"
	inner.position = Vector2(16, 16)
	inner.size = panel.size - Vector2(32, 32)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_stylebox_override("panel", PixelUIStyle.section_style())
	panel.add_child(inner)
	panel.move_child(inner, 0)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	info_label.set_meta("pixelmania_font_size", 18)
	info_label.custom_minimum_size.y = 142
	info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	$Panel/VBox/InfoPanel.add_theme_stylebox_override("panel", PixelUIStyle.section_style())
	for toggle in [public_build_check, ignore_empty_space_check]:
		toggle.custom_minimum_size.y = 44
		toggle.set_meta("pixelmania_font_size", 18)
	$Panel/VBox/AddRow.custom_minimum_size.y = 44
	role_option.custom_minimum_size.x = 150
	PixelUIStyle.apply_atlas_button(role_option, "blue_button")
	add_button.custom_minimum_size.x = 100
	PixelUIStyle.apply_atlas_button(add_button, "green_button")
	$Panel/VBox/AccessScroll.custom_minimum_size.y = 100
	status_label.set_meta("pixelmania_font_size", 15)
	_fit_panel()''')
s+='''

func _process(_delta: float) -> void:
	if visible:
		_fit_panel()


func _fit_panel() -> void:
	var screen := get_viewport_rect().size
	var factor := minf(1.0, minf((screen.x - 24) / panel.size.x, (screen.y - 24) / panel.size.y))
	panel.scale = Vector2.ONE * maxf(0.1, factor)
	panel.position = (screen - panel.size * panel.scale) * 0.5


func _style_confirmation(card: Panel) -> void:
	card.add_theme_stylebox_override("panel", PixelUIStyle.panel_style())
	var inner := Panel.new()
	inner.position = Vector2(16, 16)
	inner.size = Vector2(528, 172)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_stylebox_override("panel", PixelUIStyle.section_style())
	card.add_child(inner)
'''
s=s.replace('Vector2(420, 180)','Vector2(560, 280)').replace('Vector2(420, 188)','Vector2(560, 280)')
s=re.sub(r'confirm_panel.add_theme_stylebox_override\("panel", PixelUIStyle.style_box\(.*?\n\t\)\)', '_style_confirmation(confirm_panel)',s,flags=re.S)
s=s.replace('label.position = Vector2(18, 18)','label.position = Vector2(32, 28)').replace('label.size = Vector2(384, 102)','label.size = Vector2(496, 148)').replace('label.size = Vector2(384, 100)','label.size = Vector2(496, 148)')
s=s.replace('PixelUIStyle.apply_label_shadow(label, 13)','label.set_meta("pixelmania_font_size", 18)\n\tPixelUIStyle.apply_label_shadow(label, 18)')
s=s.replace('Vector2(20, 132)','Vector2(292, 214)').replace('Vector2(220, 132)','Vector2(28, 214)').replace('Vector2(180, 38)','Vector2(240, 44)')
s=s.replace('PixelUIStyle.apply_yellow_button(confirm, 13)','PixelUIStyle.apply_atlas_button(confirm, "green_button")').replace('PixelUIStyle.apply_yellow_button(cancel, 13)','PixelUIStyle.apply_atlas_button(cancel, "blue_button")')
s=s.replace('row.add_theme_constant_override("separation", 8)','row.add_theme_constant_override("separation", 14)\n\t\trow.custom_minimum_size.y = 42')
s=s.replace('name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL','name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL\n\t\tname_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS\n\t\tname_label.clip_text = true')
p.write_text(s,encoding='utf-8')
