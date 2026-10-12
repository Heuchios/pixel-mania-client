from pathlib import Path
import re
p=Path('Scenes/ui/shop/ShopSceneRedesign.tscn');s=p.read_text(encoding='utf-8')
for name in ['DetailTextPanel','DetailHeading']:
 s=re.sub(r'\[node name="'+name+r'"[^\n]*\]\n.*?(?=\n\[)', '', s, count=1, flags=re.S)
a=s.index('[node name="DetailNameLabel"');b=s.index('\n[node ',a+1)
s=s[:a]+'''[node name="DetailNameLabel" type="Label" parent="DetailOverlay/DetailCard"]
layout_mode = 0
offset_left = 30.0
offset_top = 20.0
offset_right = 470.0
offset_bottom = 116.0
mouse_filter = 2
theme_override_colors/font_color = Color(0.196, 0.106, 0.239, 1)
theme_override_colors/font_shadow_color = Color(0, 0, 0, 0)
theme_override_fonts/font = ExtResource("31_font")
theme_override_font_sizes/font_size = 40
text = "Item name"
autowrap_mode = 3
metadata/pixelmania_font_size = 40
metadata/pixelmania_text_shadow = false
'''+s[b:]
# Relocate the direct title ahead of the container, so its parent already exists.
a=s.index('[node name="DetailNameLabel"');b=s.index('\n[node ',a+1);title=s[a:b];s=s[:a]+s[b:];pos=s.index('[node name="Margin" type="MarginContainer" parent="DetailOverlay/DetailCard"');s=s[:pos]+title+'\n'+s[pos:]
a=s.index('[node name="DetailCard"');b=s.index('[node name="PurchaseRewardOverlay"',a);t=s[a:b]
t=t.replace('Vector2(0, 194)','Vector2(0, 238)').replace('offset_top = 88.0','offset_top = 132.0').replace('offset_bottom = 272.0','offset_bottom = 316.0')
t=t.replace('theme_override_colors/font_color = Color(0.86, 0.96, 1, 1)','theme_override_colors/font_color = Color(0.196, 0.106, 0.239, 1)').replace('theme_override_colors/font_shadow_color = Color(0, 0, 0, 1)','theme_override_colors/font_shadow_color = Color(0, 0, 0, 0)').replace('theme_override_constants/shadow_offset_x = 2','theme_override_constants/shadow_offset_x = 0').replace('theme_override_constants/shadow_offset_y = 2','theme_override_constants/shadow_offset_y = 0')
t=t.replace('theme_override_styles/panel = ExtResource("panel_role_5")','theme_override_styles/panel = ExtResource("panel_role_5")\nmetadata/pixelmania_text_shadow = false\nmetadata/pixelmania_panel_shadow = false',1)
s=s[:a]+t+s[b:];p.write_text(s,encoding='utf-8')
p=Path('Scripts/ui/shop_scene_redesign.gd');s=p.read_text(encoding='utf-8').replace('$DetailOverlay/DetailCard/Margin/Column/DetailNameLabel','$DetailOverlay/DetailCard/DetailNameLabel');p.write_text(s,encoding='utf-8')
