from pathlib import Path
for kind,x in [('normal',256),('legendary',352),('special',448)]:
 name='shop_card_'+kind
 Path('Assets/ui/atlas/textures/'+name+'.tres').write_text('[gd_resource type="AtlasTexture" format=3]\n\n[ext_resource type="Texture2D" path="res://Assets/ui/UI_3.0.png" id="1_atlas"]\n\n[resource]\natlas = ExtResource("1_atlas")\nregion = Rect2(%d, 352, 96, 96)\nfilter_clip = true\nmetadata/atlas_region = "%s"\n' % (x,name),encoding='utf-8')
