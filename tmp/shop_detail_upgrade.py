from pathlib import Path
import re
p=Path('Scenes/ui/shop/ShopSceneRedesign.tscn');s=p.read_text(encoding='utf-8')
def edit(name,parent,values):
 global s
 m=re.search(r'(\[node name="'+name+r'"[^\n]*parent="'+re.escape(parent)+r'"[^\n]*\]\n)(.*?)(?=\n\[|\Z)',s,re.S);assert m,name
 body=m[2]
 for key,value in values.items():
  line=key+' = '+value
  if re.search('^'+re.escape(key)+' = .*$',body,re.M):body=re.sub('^'+re.escape(key)+' = .*$',lambda _:line,body,flags=re.M)
  else:body+='\n'+line+'\n'
 s=s[:m.start(2)]+body+s[m.end(2):]
b='DetailOverlay/DetailCard';c=b+'/Margin/Column'
edit('DetailCard','DetailOverlay',{'offset_left':'-280.0','offset_right':'280.0','offset_top':'-340.0','offset_bottom':'340.0'})
edit('Margin',b,{'offset_top':'0.0','offset_bottom':'0.0','theme_override_constants/margin_left':'30','theme_override_constants/margin_right':'30','theme_override_constants/margin_top':'20','theme_override_constants/margin_bottom':'24'})
edit('DetailIconSpacer',c,{'custom_minimum_size':'Vector2(0, 194)'})
edit('DetailNameLabel',c,{'custom_minimum_size':'Vector2(0, 66)','autowrap_mode':'3','vertical_alignment':'1','metadata/pixelmania_font_size':'30'})
edit('DetailDescLabel',c,{'custom_minimum_size':'Vector2(0, 112)','metadata/pixelmania_font_size':'19'})
edit('DetailIconSlot',b,{'anchor_right':'0.0','offset_left':'188.0','offset_top':'88.0','offset_right':'372.0','offset_bottom':'272.0'})
edit('DetailIcon',b+'/DetailIconSlot',{'offset_left':'16.0','offset_top':'16.0','offset_right':'-16.0','offset_bottom':'-16.0','expand_mode':'1','modulate':'Color(1, 1, 1, 1)','texture_filter':'1'})
pos=s.index('[node name="Margin" type="MarginContainer" parent="'+b+'"')
s=s[:pos]+'''[node name="DetailTextPanel" type="Panel" parent="DetailOverlay/DetailCard"]
layout_mode = 0
offset_left = 16.0
offset_top = 282.0
offset_right = 544.0
offset_bottom = 664.0
mouse_filter = 2
theme_override_styles/panel = ExtResource("atlas_StyleBoxTexture_card_n")

[node name="DetailHeading" type="Label" parent="DetailOverlay/DetailCard"]
layout_mode = 0
offset_left = 30.0
offset_top = 26.0
offset_right = 450.0
offset_bottom = 62.0
text = "ITEM DETAILS"
theme_override_colors/font_color = Color(0.196, 0.106, 0.239, 1)
theme_override_fonts/font = ExtResource("31_font")
metadata/pixelmania_font_size = 28
metadata/pixelmania_text_shadow = false

'''+s[pos:]
p.write_text(s,encoding='utf-8')
p=Path('Scripts/ui/shop_scene_redesign.gd');s=p.read_text(encoding='utf-8')
s=s.replace('detail_icon_slot.modulate = card_icon_slot.modulate','''detail_icon_slot.modulate = Color.WHITE
	detail_icon_slot.texture = UIAtlasDB.get_texture("inv_slot_normal")''')
s=s.replace('detail_buy_button.text = "BUY  " + _detail_price_text if affordable else "NEED %s MORE GEMS" % (_detail_price - _available_gems)','detail_buy_button.text = ("CLAIM FREE" if _detail_price == 0 and not _detail_is_gem_pack else "BUY  " + _detail_price_text) if affordable else "NEED %s MORE GEMS" % (_detail_price - _available_gems)')
p.write_text(s,encoding='utf-8')
p=Path('Scripts/ui/shop_pack_info.gd');s=p.read_text(encoding='utf-8')
s=s.replace('var reserved := 52.0 if info_button.visible else 0.0','var reserved := 0.0 # Detail panel reserves space for the optional INFO action.')
p.write_text(s,encoding='utf-8')
