from pathlib import Path
import re
p=Path('Scripts/shop_ui.gd')
s=p.read_text()
s=s.replace('str(amount) + "x " + item_name', 'str(amount) + " " + item_name')
a=s.index('func populate_purchase_reward_slots(')
b=s.index('\n\nfunc get_reward_popup_accent_color',a)
s=s[:a]+'''func populate_purchase_reward_slots(root: Control, rewards: Array, scroll_size: Vector2):
	var slot_size := 112.0
	var cell_width := 148.0
	var gap := 16.0
	var content_width := maxf(0.0, rewards.size() * (cell_width + gap) - gap)
	root.custom_minimum_size = Vector2(maxf(scroll_size.x, content_width), 180)
	root.size = root.custom_minimum_size
	var start_x := maxf(0.0, (scroll_size.x - content_width) / 2.0)
	for i in range(rewards.size()):
		create_purchase_reward_slot(root, rewards[i], Vector2(start_x + i * (cell_width + gap) + 18, 8), slot_size, i)


func create_purchase_reward_slot(root: Control, reward: Dictionary, slot_position: Vector2, slot_size: float, slot_index: int):
	var item_id := str(reward.get("item_id", ""))
	var amount_text := str(int(reward.get("amount", 0)))
	var rarity := "common"
	if world != null and world.item_database.has(item_id):
		rarity = str(world.item_database[item_id].get("rarity", "common"))
	var slot := Panel.new()
	slot.name = "Reward_" + item_id
	slot.position = slot_position
	slot.size = Vector2.ONE * slot_size
	slot.pivot_offset = slot.size * 0.5
	slot.scale = Vector2.ONE * 0.9
	slot.modulate.a = 0.0
	slot.tooltip_text = get_item_display_name(item_id) + " — " + amount_text
	slot.mouse_filter = Control.MOUSE_FILTER_PASS
	slot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	slot.set_meta("pixelmania_panel_shadow", false)
	slot.add_theme_stylebox_override("panel", PixelUIStyle.slot_style(rarity))
	root.add_child(slot)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.position = Vector2(10, 10)
	icon.size = Vector2.ONE * (slot_size - 20)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = get_item_texture(item_id)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon)

	var amount_label := Label.new()
	amount_label.name = "Amount"
	amount_label.text = amount_text
	amount_label.position = Vector2(8, slot_size - 32)
	amount_label.size = Vector2(slot_size - 16, 26)
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	amount_label.set_meta("pixelmania_font_size", 22)
	PixelUIStyle.apply_label_shadow(amount_label, 22, Color.WHITE)
	slot.add_child(amount_label)

	var name_label := Label.new()
	name_label.name = "RewardItemName"
	name_label.text = get_item_display_name(item_id)
	name_label.position = slot_position + Vector2(-18, slot_size + 8)
	name_label.size = Vector2(148, 48)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.modulate.a = 0.0
	name_label.set_meta("pixelmania_font_size", 18)
	PixelUIStyle.apply_label_shadow(name_label, 18, PixelUIStyle.TEXT_LIGHT)
	root.add_child(name_label)

	var delay := minf(float(slot_index) * 0.05, 0.4)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(slot, "scale", Vector2.ONE, 0.18).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(slot, "modulate:a", 1.0, 0.18).set_delay(delay)
	tween.tween_property(name_label, "modulate:a", 1.0, 0.18).set_delay(delay)
''' + s[b:]
p.write_text(s)
p=Path('Scenes/ui/shop/ShopSceneRedesign.tscn')
s=p.read_text()
def node(name,parent,changes):
 global s
 pat=r'(\[node name="'+name+r'"[^\n]*parent="'+re.escape(parent)+r'"[^\n]*\]\n)(.*?)(?=\n\[|\Z)'
 m=re.search(pat,s,re.S)
 assert m, name
 body=m[2]
 for k,v in changes.items():
  line=k+' = '+v
  if re.search(r'^'+re.escape(k)+r' = .*$',body,re.M): body=re.sub(r'^'+re.escape(k)+r' = .*$',lambda _:line,body,flags=re.M)
  else: body+='\n'+line+'\n'
 s=s[:m.start(2)]+body+s[m.end(2):]
base='PurchaseRewardOverlay/RewardCard'
node('RewardCard','PurchaseRewardOverlay',{'offset_left':'-370.0','offset_right':'370.0','offset_top':'-215.0','offset_bottom':'215.0'})
node('Header',base,{'offset_right':'726.0','offset_bottom':'110.0'})
node('Title',base,{'offset_right':'710.0','metadata/pixelmania_font_size':'36'})
node('Subtitle',base,{'offset_top':'70.0','offset_bottom':'100.0','offset_right':'708.0','metadata/pixelmania_font_size':'18','text_overrun_behavior':'3'})
node('RewardsBack',base,{'offset_left':'14.0','offset_top':'122.0','offset_right':'726.0','offset_bottom':'344.0','theme_override_styles/panel':'ExtResource("atlas_StyleBoxTexture_card_n")'})
node('RewardScroll',base,{'offset_left':'30.0','offset_top':'138.0','offset_right':'710.0','offset_bottom':'328.0'})
node('RewardItems',base+'/RewardScroll',{'custom_minimum_size':'Vector2(680, 180)'})
node('ButtonRow',base,{'offset_top':'362.0','offset_bottom':'410.0'})
node('BuyAgainButton',base+'/ButtonRow',{'custom_minimum_size':'Vector2(222, 48)'})
node('CloseButton',base+'/ButtonRow',{'custom_minimum_size':'Vector2(182, 48)','text':'"DONE"'})
s=s.replace('[node name="CloseButton" type="Button" parent="'+base+'/ButtonRow"','[node name="DoneButton" type="Button" parent="'+base+'/ButtonRow"')
p.write_text(s)
p=Path('Scripts/ui/shop_scene_redesign.gd')
s=p.read_text().replace('$PurchaseRewardOverlay/RewardCard/ButtonRow/CloseButton','$PurchaseRewardOverlay/RewardCard/ButtonRow/DoneButton')
s=s.replace('reward_subtitle_label.text = subtitle_text','reward_subtitle_label.text = subtitle_text\n\treward_subtitle_label.tooltip_text = subtitle_text\n\tpreload("res://Scripts/ui/pixel_ui_style.gd").apply_atlas_button(reward_close_button, "pink_button")\n\treward_scroll.scroll_horizontal = 0')
p.write_text(s)
