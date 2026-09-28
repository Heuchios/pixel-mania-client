from pathlib import Path
import re
p=Path('Scenes/ui/vending/VendingMachineGUI.tscn')
s=p.read_text(encoding='utf-8')
def edit(path, **props):
 global s
 parent,name=path.rsplit('/',1) if '/' in path else ('.',path)
 pat=r'(\[node name="'+re.escape(name)+r'"[^\n]*'+(' parent="'+re.escape(parent)+r'"' if parent!='.' else '')+r'[^\n]*\]\n)(.*?)(?=\n\[|\Z)'
 matches=list(re.finditer(pat,s,re.S))
 if parent=='.': matches=[m for m in matches if 'parent=' not in m[1] or 'parent="."' in m[1]]
 assert len(matches)==1,(path,len(matches))
 m=matches[0]; body=m[2]
 for k,v in props.items():
  line=k+' = '+str(v)
  if re.search(r'^'+re.escape(k)+r' = .*$',body,re.M): body=re.sub(r'^'+re.escape(k)+r' = .*$',lambda _:line,body,flags=re.M)
  else: body+='\n'+line+'\n'
 s=s[:m.start(2)]+body+s[m.end(2):]
def rect(path,x,y,w,h,**props):
 edit(path,offset_left=float(x),offset_top=float(y),offset_right=float(x+w),offset_bottom=float(y+h),**props)
P='VendingPanel'
rect(P,0,0,920,650)
rect(P+'/PanelBack',0,0,920,650)
rect(P+'/TopBar',20,20,880,82,visible='true',mouse_filter=2)
rect(P+'/Title',36,26,530,36,**{'theme_override_font_sizes/font_size':26})
rect(P+'/Subtitle',36,65,700,23,**{'theme_override_font_sizes/font_size':13,'theme_override_colors/font_color':'Color(0.75, 0.85, 0.94, 1)','metadata/pixelmania_font_role':'"preserve"'})
rect(P+'/StatusBack',640,30,180,32)
rect(P+'/StatusBack/Status',0,0,180,32,**{'theme_override_font_sizes/font_size':14})
rect(P+'/CloseButton',840,28,44,44)
rect(P+'/ItemCard',20,118,330,390)
rect(P+'/PriceCard',366,118,534,390)
for n,w in [('Item',330),('Price',534)]:
 rect(P+'/'+n+'Card/'+n+'CardSkin',0,0,w,390,texture='ExtResource("3_panel_inner")',patch_margin_left=1,patch_margin_right=1,patch_margin_top=1,patch_margin_bottom=1,mouse_filter=2)
rect(P+'/ItemCard/ItemTitle',18,16,294,30,**{'theme_override_font_sizes/font_size':20})
rect(P+'/ItemCard/ItemSlot',92,58,146,146)
rect(P+'/ItemCard/ItemSlot/Icon',20,20,106,106)
rect(P+'/ItemCard/Hint',18,220,294,98,**{'theme_override_font_sizes/font_size':16,'text_overrun_behavior':3})
rect(P+'/ItemCard/SelectItem',36,332,258,42)
rect(P+'/PriceCard/SetupTitle',20,16,494,30,horizontal_alignment=0)
for node,y in [('StockLabel',64),('PerSaleLabel',124),('PriceLabel',184)]: rect(P+'/PriceCard/'+node,20,y,238,40)
for node,y in [('StockSpin',64),('PriceMode',124),('PriceSpin',184)]: rect(P+'/PriceCard/'+node,270,y,244,40)
rect(P+'/PriceCard/PriceReadout',20,118,494,62,**{'theme_override_colors/font_color':'Color(0.86, 0.96, 1, 1)','theme_override_font_sizes/font_size':17,'metadata/pixelmania_font_role':'"preserve"'})
rect(P+'/PriceCard/MaxQuantity',270,184,244,40)
rect(P+'/PriceCard/Formula',36,290,462,72,**{'theme_override_font_sizes/font_size':16})
# Framed summary, inserted below the form but before labels to keep draw order.
header='[node name="SetupTitle"'
idx=s.index(header)
new=''
for name,x,y,w,h,tex in [('SummaryFrame',20,246,494,128,'3_81mko'),('SummaryInset',23,249,488,122,'3_panel_inner')]:
 new+=f'[node name="{name}" type="NinePatchRect" parent="VendingPanel/PriceCard"]\nmouse_filter = 2\noffset_left = {x}.0\noffset_top = {y}.0\noffset_right = {x+w}.0\noffset_bottom = {y+h}.0\ntexture = ExtResource("{tex}")\npatch_margin_left = 1\npatch_margin_right = 1\npatch_margin_top = 1\npatch_margin_bottom = 1\n\n'
new+='[node name="SummaryTitle" type="Label" parent="VendingPanel/PriceCard"]\noffset_left = 36.0\noffset_top = 260.0\noffset_right = 498.0\noffset_bottom = 284.0\ntext = "SALE SUMMARY"\ntheme_override_font_sizes/font_size = 14\ntheme_override_colors/font_color = Color(1, 0.88, 0.25, 1)\nmetadata/pixelmania_font_role = "preserve"\n\n'
s=s[:idx]+new+s[idx:]
rect(P+'/ActionBack',20,524,880,106,visible='true',mouse_filter=2)
for n,x,w in [('ListButton',652,230),('BuyButton',510,372),('CollectButton',36,236),('LogButton',286,140),('CancelListingButton',440,198)]: rect(P+'/'+n,x,574,w,40,custom_minimum_size=f'Vector2({w}, 40)',**{'theme_override_font_sizes/font_size':15})
s+='\n[node name="ActionHint" type="Label" parent="VendingPanel"]\noffset_left = 36.0\noffset_top = 539.0\noffset_right = 884.0\noffset_bottom = 563.0\ntext = "EARNINGS"\ntheme_override_font_sizes/font_size = 14\ntheme_override_colors/font_color = Color(0.86, 0.96, 1, 1)\nmetadata/pixelmania_font_role = "preserve"\n'
p.write_text(s,encoding='utf-8')
p=Path('Scripts/vending_ui.gd');s=p.read_text(encoding='utf-8')
# The scene owns button geometry in both owner and buyer modes.
s=re.sub(r'^\t(?:list_button|buy_button|collect_button|cancel_button|log_button)\.(?:position|size) = Vector2\([^\n]+\)\n','',s[s.index('extends Control'):],flags=re.M) if False else s
start=s.index('func refresh_buttons(');end=s.index('\nfunc refresh_log_text',start)
block=s[start:end]
block=re.sub(r'^\t(?:list_button|buy_button|collect_button|cancel_button|log_button)\.(?:position|size) = Vector2\([^\n]+\)\n','',block,flags=re.M)
block=block.replace('\tlist_button.visible = can_manage','\tpanel.get_node("ActionHint").text = "EARNINGS / %d WL READY TO COLLECT" % pending if can_manage else "Pay with World Locks. Review the total before confirming."\n\tlist_button.visible = can_manage')
s=s[:start]+block+s[end:]
s=s.replace('"OWNER / Stock items, set a price, collect earnings" if can_manage else "SHOP / Choose your quantity and review the total"','"OWNER / Manage stock and pricing" if can_manage else "SHOP / Choose your quantity"')
s=s.replace('"SET YOUR PRICE" if can_manage else "YOUR PURCHASE"','"PRICING & STOCK" if can_manage else "YOUR PURCHASE"')
p.write_text(s,encoding='utf-8')
