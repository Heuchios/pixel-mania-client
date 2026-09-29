from pathlib import Path
import re
p=Path('Scenes/ui/trade/TradeScene.tscn');s=p.read_text(encoding='utf-8')
def edit(path,**props):
 global s
 parent,name=path.rsplit('/',1) if '/' in path else ('.',path)
 pat=r'(\[node name="'+name+r'"[^\n]* parent="'+re.escape(parent)+r'"[^\n]*\]\n)(.*?)(?=\n\[|\Z)'
 m=re.search(pat,s,re.S);assert m,path
 b=m[2]
 for k,v in props.items():
  line=k+' = '+str(v)
  if re.search(r'^'+re.escape(k)+r' = .*$',b,re.M):b=re.sub(r'^'+re.escape(k)+r' = .*$',lambda _:line,b,flags=re.M)
  else:b+='\n'+line+'\n'
 s=s[:m.start(2)]+b+s[m.end(2):]
def rect(path,x,y,w,h,**props):edit(path,offset_left=x,offset_top=y,offset_right=x+w,offset_bottom=y+h,**props)
rect('TradePanel',0,0,920,600);rect('TradePanel/PanelBack',0,0,920,600)
rect('TradePanel/TopBar',20,20,880,84)
rect('TradePanel/Title',36,28,760,32)
rect('TradePanel/StatusLabel',36,67,800,26,horizontal_alignment=0,clip_text='true')
for side,x in [('Local',20),('Remote',468)]:
 c='TradePanel/'+side+'Column';rect(c,x,120,432,382)
 rect(c+'/NameLabel',18,14,272,30,text_overrun_behavior=3,clip_text='true')
 rect(c+'/AcceptCheck',290,17,124,24,text='"ACCEPTED"',**{'metadata/pixelmania_font_size':14})
 rect(c+'/SlotGrid',18,84,396,276)
 for i in range(6):
  slot=c+'/SlotGrid/'+side+'Slot'+str(i)
  edit(slot,custom_minimum_size='Vector2(124, 132)')
  rect(slot+'/ItemIcon',37,12,50,50)
  rect(slot+'/ItemLabel',8,72,108,52,**{'metadata/pixelmania_font_size':14,'text_overrun_behavior':3})
  if side=='Local':rect(slot+'/ClearButton',96,6,22,22,text='"-"',**{'metadata/pixelmania_font_size':14})
 s+=f'\n[node name="OfferHint" type="Label" parent="{c}"]\noffset_left = 18.0\noffset_top = 48.0\noffset_right = 414.0\noffset_bottom = 72.0\ntext = "'+('YOUR OFFER / Click a slot to add' if side=='Local' else 'THEIR OFFER / Items you receive')+'"\nmetadata/pixelmania_font_size = 14\n'
rect('TradePanel/AcceptButton',676,536,208,44)
rect('TradePanel/CancelButton',520,536,142,44)
# Footer sits behind the controls.
pos=s.index('[node name="AcceptButton"')
s=s[:pos]+'''[node name="Footer" type="Panel" parent="TradePanel"]
offset_left = 20.0
offset_top = 518.0
offset_right = 900.0
offset_bottom = 584.0
mouse_filter = 2
theme_override_styles/panel = ExtResource("panel_role_1")

[node name="TradeHint" type="Label" parent="TradePanel"]
offset_left = 36.0
offset_top = 538.0
offset_right = 500.0
offset_bottom = 576.0
text = "Check both offers before accepting."
autowrap_mode = 2
metadata/pixelmania_font_size = 14

'''+s[pos:]
p.write_text(s,encoding='utf-8')
p=Path('Scripts/trade_ui.gd');s=p.read_text(encoding='utf-8')
s=s.replace('PixelUIStyle.apply_yellow_button(accept_button, 18)','PixelUIStyle.apply_atlas_button(accept_button, "green_button")')
s=s.replace('PixelUIStyle.apply_close_button(clear_button)','PixelUIStyle.apply_atlas_button(clear_button, "red_button")\n\t\t\tclear_button.tooltip_text = "Remove from offer"')
a=s.index('func update_position():');b=s.index('\n\nfunc handle_trade_message',a)
s=s[:a]+'''func _process(_delta: float) -> void:
	if visible:
		update_position()


func update_position():
	var screen := get_viewport_rect().size
	var windows: Array = [panel]
	if picker_overlay != null:
		windows.append(picker_overlay.get_node_or_null("PickerPanel"))
	if final_overlay != null:
		windows.append(final_overlay.get_node_or_null("FinalPanel"))
	for window in windows:
		if window == null:
			continue
		var fit: float = minf(1.0, minf((screen.x - 24.0) / window.size.x, (screen.y - 24.0) / window.size.y))
		window.scale = Vector2.ONE * maxf(0.1, fit)
		window.position = (screen - window.size * window.scale) / 2.0
'''+s[b:]
a=s.index('\tvar fill = slot_fill_filled');b=s.index('\n\nfunc get_status_text',a)
s=s[:a]+'''	var normal := PixelUIStyle.slot_style("common")
	for state in ["normal", "disabled", "pressed"]:
		button.add_theme_stylebox_override(state, normal)
	button.add_theme_stylebox_override("hover", PixelUIStyle.slot_style("uncommon") if filled else normal)
'''+s[b:]
s=s.replace('\tbutton.text = ""\n\tvar icon', '\tbutton.text = ""\n\tvar icon',1)
s=s.replace('\t\t\tlabel.text = label_text','\t\t\tlabel.position.y = 72 if item is Dictionary else 38\n\t\t\tlabel.text = label_text')
p.write_text(s,encoding='utf-8')
