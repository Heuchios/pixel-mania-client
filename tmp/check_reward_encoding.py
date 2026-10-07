from pathlib import Path
p=Path('Scripts/shop_ui.gd')
p.write_bytes(p.read_bytes().replace(b'\x97', b'-'))
for name in ['Scripts/shop_ui.gd', 'Scripts/ui/shop_scene_redesign.gd', 'Scenes/ui/shop/ShopSceneRedesign.tscn']:
 Path(name).read_text(encoding='utf-8')
