"""Keep authored World Lock and shop card previews aligned with runtime layout.

Run after changing the desktop _place() layout or card geometry; --check is read-only.
Responsive layout remains runtime-owned.
"""
from pathlib import Path
import argparse
import re

ROOT = Path(__file__).resolve().parents[1]

def property_set(block, name, value):
    pattern = rf'^{re.escape(name)} = .*?$'
    if re.search(pattern, block, re.M):
        return re.sub(pattern, f'{name} = {value}', block, flags=re.M)
    return block.rstrip() + f'\n{name} = {value}\n'

def edit_scene(path, updates):
    original = path.read_text(encoding='utf-8')
    def edit(match):
        block = match[0]
        header = block.splitlines()[0]
        name = re.search(r'name="([^"]+)"', header)[1]
        parent = re.search(r'parent="([^"]+)"', header)
        full = name if not parent or parent[1] == '.' else parent[1] + '/' + name
        for key, value in updates(full, header).items():
            block = property_set(block, key, value)
        return block.rstrip() + '\n'
    updated = re.sub(r'\[node [^\n]+\][\s\S]*?(?=\n\[|\Z)', edit, original)
    return original, updated

def rect_props(x,y,w,h):
    return {'anchor_left':'0.0', 'anchor_top':'0.0', 'anchor_right':'0.0', 'anchor_bottom':'0.0',
            'offset_left':str(float(x)), 'offset_top':str(float(y)),
            'offset_right':str(float(x+w)), 'offset_bottom':str(float(y+h))}

def main(check):
    source = (ROOT/'Scripts/world_lock_scene_ui.gd').read_text(encoding='utf-8')
    layout = source.split('func _layout_simple_panel()',1)[1].split('\nfunc ',1)[0]
    rects = { 'Window/'+name:rect_props(*map(float,nums.split(',')))
              for name,nums in re.findall(r'_place\("([^"]+)", Rect2\(([\d., ]+)\)\)',layout) }
    texts={'Window/AccessTitle':'PLAYER ACCESS','Window/ActionsTitle':'PERMISSIONS',
           'Window/ActionsCard/AddPlayerLabel':'ADD A PLAYER','Window/ActionsCard/AddAccessButton':'ADD',
           'Window/ActionsCard/LimitLabel':'BUILDER SLOTS', 'Window/ActionsCard/SetLimitButton':'SAVE LIMIT',
           'Window/ActionsCard/HintLabel':'Only the owner can edit access.'}
    hidden={'LockSlot','LockIcon','LockIconShadow','LockedLabel','StatusLabel','PositionLabel'}
    def world(full,header):
        props = dict(rects.get(full,{}))
        if full == 'Window':
            props.update({'offset_left':'-500.0','offset_top':'-330.0','offset_right':'500.0','offset_bottom':'330.0'})
        if full in texts: props['text'] = '"'+texts[full]+'"'
        if full.split('/')[-1] in hidden: props['visible']='false'
        if full in ['Window/InfoCard','Window/AccessCard','Window/ActionsCard']: props['modulate']='Color(1, 1, 1, 1)'
        if '/Limit' in full or full.endswith('SetLimitButton'): props['visible']='true'
        if 'type="Label"' in header: props['theme_override_font_sizes/font_size']='36' if full.endswith(('Title','TitleLabel')) else '24'
        return props
    def shop(full,header):
        if '/Card_' not in full: return {}
        name=full.split('/')[-1]
        if name.startswith('Card_'): return {'custom_minimum_size':'Vector2(210, 250)'}
        if name in ['NameLabel','NameLabel2']:
            top=8 if name=='NameLabel' else 56
            return {'offset_top':str(float(top)), 'offset_bottom':str(float(top+48)),
                    'autowrap_mode':'2','clip_text':'false','theme_override_font_sizes/font_size':'24'}
        if name=='IconSlot': return {'offset_bottom':'214.0'}
        if name=='Icon': return {'offset_top':'104.0'}
        if name=='PriceLabel': return {'offset_top':'216.0','offset_bottom':'246.0','theme_override_font_sizes/font_size':'24'}
        return {}
    def settings(full,header):
        rects={'Window/WindowSkin':(0,0,560,300),'Window/HeaderSkin':(12,12,536,52),
               'Window/HeaderSkin/TitleLabel':(12,0,448,52),'Window/CloseButton':(500,16,44,44)}
        for index,name in enumerate(['FullScreenRow','SfxRow','ChatFilterRow','MobileControlsRow']):
            rects['Window/'+name]=(24,78+50*index,512,44)
        props=rect_props(*rects[full]) if full in rects else {}
        if full=='Window': props.update({'offset_left':'-280.0','offset_top':'-150.0','offset_right':'280.0','offset_bottom':'150.0'})
        if full.endswith('SettingsScrollSlider'): props['visible']='false'
        if 'type="Label"' in header: props['theme_override_font_sizes/font_size']='36' if full.endswith('TitleLabel') else '24'
        return props
    def inventory(full,header):
        if full.endswith('/Count'):
            props=rect_props(4,66,88,26)
            props.update({'horizontal_alignment':'2','clip_text':'true','theme_override_font_sizes/font_size':'24'})
            return props
        return {}
    stale=[]
    for relative,fn in [('Scenes/ui/locks/WorldLockGUI.tscn',world),('Scenes/ui/shop/ShopSceneRedesign.tscn',shop),('Scenes/ui/settings/SettingsPanel.tscn',settings),('Scenes/ui/inventory/InventoryScene.tscn',inventory)]:
        path=ROOT/relative
        old,new=edit_scene(path,fn)
        if old != new:
            stale.append(relative)
            if not check: path.write_text(new,encoding='utf-8',newline='\n')
    print(f'Scene previews: {len(stale)} '+('stale' if check else 'updated'))
    if check and stale: raise SystemExit(1)

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check',action='store_true')
    main(parser.parse_args().check)
