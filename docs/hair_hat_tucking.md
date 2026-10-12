# Hair under hats and crowns

The shared equipment renderer clips upper hair at the equipped hat's lower
edge. It preserves hair below the brim, including long sides and pigtails.
Unequipping the hat restores the original material and full hair immediately;
equipped IDs, source textures, inventory icons and animation frames never change.
The same equipment path handles local and remote players.

New hats and hairstyles inherit this behavior. Decorative hat-slot accessories
can set `tucks_hair: false`; existing bows, headband and headphones do so.
Full-head covers keep the existing `hides_hair` behavior. Hat bounds include all
animation frames to keep the clipped hairline stable and are cached by atlas
region so repeated equips do not repeatedly read pixels or grow the cache.

`hair_hat_clip.gdshader` uses sprite-local vertex coordinates, independently of
atlas UVs and texture size. See the [Godot CanvasItem shader reference](https://docs.godotengine.org/en/4.5/tutorials/shaders/shader_reference/canvas_item_shader.html).

## Validation (2026-10-12)

- `hair_hat_occlusion_test.gd`: all 19 hairstyles and 27 head items, both facings,
  1,026 pair/facing cases; remote cached snapshots, animation changes, future IDs,
  accessory exceptions, full covers and unequip restoration.
- Rendered checks passed with Compatibility/OpenGL and Mobile/D3D12. Six example
  pairs in both facings removed 16,380 upper hair pixels, preserved 4,266 lower
  hair pixels and restored the exact original portraits after unequip.
- Existing helmet layering, hair/hat expansion and remote equipment performance
  tests passed. Evidence and before/tucked/unequipped previews are under
  `D:/Pixelmania/work/hair-tuck/`.

Run `--script res://tests/hair_hat_occlusion_test.gd` for logic coverage, or use
a rendering driver with `-- --render` for pixel checks and the preview at
`user://hair_hat_preview.png`. Rendering was tested on desktop; this is not a
claim of physical Android-device validation.

Client-only change. Backend deployment and published binaries are unchanged.
