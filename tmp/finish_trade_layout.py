from pathlib import Path
import re
p=Path('Scenes/ui/trade/TradeScene.tscn');s=p.read_text(encoding='utf-8')
start=s.index('[node name="FinalSummaryLabel"');end=s.index('[node name="FinalConfirmButton"',start)
s=s[:start]+'''[node name="Header" type="Panel" parent="FinalConfirmOverlay/FinalPanel"]
offset_left = 16.0
offset_top = 12.0
offset_right = 624.0
offset_bottom = 60.0
show_behind_parent = true
mouse_filter = 2
theme_override_styles/panel = ExtResource("panel_role_1")

[node name="SummaryBack" type="Panel" parent="FinalConfirmOverlay/FinalPanel"]
offset_left = 16.0
offset_top = 66.0
offset_right = 624.0
offset_bottom = 340.0
mouse_filter = 2
theme_override_styles/panel = ExtResource("panel_role_1")

[node name="SummaryScroll" type="ScrollContainer" parent="FinalConfirmOverlay/FinalPanel"]
offset_left = 28.0
offset_top = 78.0
offset_right = 612.0
offset_bottom = 328.0
horizontal_scroll_mode = 0

[node name="FinalSummaryLabel" type="Label" parent="FinalConfirmOverlay/FinalPanel/SummaryScroll"]
custom_minimum_size = Vector2(558, 0)
size_flags_horizontal = 3
autowrap_mode = 2
metadata/pixelmania_font_size = 17

'''+s[end:]
# Header must draw before its title, above the outer panel.
a=s.index('[node name="Header" type="Panel" parent="FinalConfirmOverlay/FinalPanel"]');b=s.index('[node name="SummaryBack"',a);header=s[a:b].replace('show_behind_parent = true\n','');s=s[:a]+s[b:];idx=s.index('[node name="Title" type="Label" parent="FinalConfirmOverlay/FinalPanel"');s=s[:idx]+header+s[idx:]
p.write_text(s,encoding='utf-8')
p=Path('Scripts/trade_ui.gd');s=p.read_text(encoding='utf-8').replace('FinalPanel/FinalSummaryLabel','FinalPanel/SummaryScroll/FinalSummaryLabel');s=s.replace('PixelUIStyle.apply_yellow_button(final_confirm_button, 16)','PixelUIStyle.apply_atlas_button(final_confirm_button, "green_button")');p.write_text(s,encoding='utf-8')
