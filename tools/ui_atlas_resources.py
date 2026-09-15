"""Generate Inspector-editable atlas resources from UIAtlasDB.gd.

Run with --check in CI. Region coordinates belong to UIAtlasDB, never hand
edit them in generated resources. Per-style margins/content/state properties
are kept in metadata/atlas_properties and survive regeneration.
"""
from pathlib import Path
import argparse
import json
import re

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'Assets/ui/atlas'
SHEET = 'res://Assets/ui/UI_3.0.png'


def catalogue():
    source = (ROOT / 'Scripts/UIAtlasDB.gd').read_text(encoding='utf-8-sig')
    regions = {}
    for name, x, y, w, h in re.findall(
        r'"(\w+)": \{"cell": Vector2i\((\d+), (\d+)\)(?:, "size_in_atlas": Vector2i\((\d+), (\d+)\))?\}', source
    ):
        regions[name] = tuple(32 * int(n) for n in (x, y, w or 1, h or 1))
    for name, x, y, w, h in re.findall(
        r'"(\w+)": \{"pixel_region": Rect2\((\d+), (\d+), (\d+), (\d+)\)\}', source
    ):
        regions[name] = tuple(map(int, (x, y, w, h)))
    margins = {}
    block = source.split('const DEFAULT_MARGINS := {', 1)[1].split('\n}', 1)[0]
    for name, props in re.findall(r'"(\w+)": (\{[^}]+\})', block):
        margins[name] = json.loads(props)
    return regions, margins


def resource(kind, name, rect, props=None):
    props = props or {}
    field = 'atlas' if kind == 'AtlasTexture' else 'texture'
    region_field = 'region' if kind == 'AtlasTexture' else 'region_rect'
    lines = [f'[gd_resource type="{kind}" format=3]', '',
             f'[ext_resource type="Texture2D" path="{SHEET}" id="1_atlas"]', '',
             '[resource]', f'{field} = ExtResource("1_atlas")',
             f'{region_field} = Rect2({", ".join(map(str, rect))})']
    if kind == 'AtlasTexture':
        lines.append('filter_clip = true')
    lines.extend(f'{k} = {v}' for k, v in sorted(props.items()))
    lines.append(f'metadata/atlas_region = "{name}"')
    # JSON string in Godot string syntax, to retain deliberate per-control padding.
    lines.append('metadata/atlas_properties = ' + json.dumps(json.dumps(props, sort_keys=True)))
    return '\n'.join(lines) + '\n'


def generate(check=False):
    regions, margins = catalogue()
    expected = {}
    for name, rect in regions.items():
        expected[OUTPUT / 'textures' / f'{name}.tres'] = resource('AtlasTexture', name, rect)
        props = {f'texture_margin_{k}': f'{v}.0' for k, v in margins.get(name, {}).items()}
        expected[OUTPUT / 'styles' / f'{name}.tres'] = resource('StyleBoxTexture', name, rect, props)
    for name in ['blue_button', 'green_button', 'red_button', 'pink_button']:
        for state, tint in [('normal', 'Color(1, 1, 1, 1)'), ('hover', 'Color(1.15, 1.15, 1.15, 1)'), ('pressed', 'Color(0.72, 0.72, 0.72, 1)'), ('disabled', 'Color(0.55, 0.55, 0.55, 0.7)')]:
            props = {f'texture_margin_{k}': f'{v}.0' for k, v in margins[name].items()}
            props.update({f'content_margin_{side}': '3.0' for side in ['left', 'top', 'right', 'bottom']})
            props['modulate_color'] = tint
            expected[OUTPUT / 'styles' / f'{name}_{state}.tres'] = resource('StyleBoxTexture', name, regions[name], props)
    focus = {f'texture_margin_{side}': '1.0' for side in ['left', 'top', 'right', 'bottom']}
    focus.update({'draw_center': 'false', 'modulate_color': 'Color(1.5, 1.5, 1.5, 1)'})
    expected[OUTPUT / 'styles/focus.tres'] = resource('StyleBoxTexture', 'inner_panel', regions['inner_panel'], focus)
    for path in list(OUTPUT.rglob('*.tres')) + list((ROOT / 'Scenes/ui/vending/styles').glob('*.tres')):
        if path in expected:
            continue
        text = path.read_text(encoding='utf-8')
        region = re.search(r'metadata/atlas_region = "(\w+)"', text)
        properties = re.search(r'metadata/atlas_properties = (.+)', text)
        if region and properties:
            name = region[1]
            props = {f'texture_margin_{k}': f'{v}.0' for k, v in margins.get(name, {}).items()}
            props.update(json.loads(json.loads(properties[1])))
            kind = 'AtlasTexture' if '[gd_resource type="AtlasTexture"' in text else 'StyleBoxTexture'
            expected[path] = resource(kind, name, regions[name], props)
    stale = []
    for path, text in expected.items():
        if not path.exists() or path.read_text(encoding='utf-8') != text:
            stale.append(str(path.relative_to(ROOT)))
            if not check:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(text, encoding='utf-8', newline='\n')
    print(f'{len(regions)} regions, {len(expected)} resources; {len(stale)} ' + ('stale' if check else 'updated'))
    if check and stale:
        print('\n'.join(stale))
        raise SystemExit(1)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    generate(parser.parse_args().check)
