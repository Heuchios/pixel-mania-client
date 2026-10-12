# Hair under hats and crowns

The shared equipment renderer clips upper hair along the equipped hat's lower
edge in each pixel column. It preserves hair below the brim, including the
front fringe, raised corners, long sides and pigtails. The initial flat cutoff
used the deepest brim everywhere and removed hair under the raised corners and
crown band; the contour mask corrects those gaps.
Only opaque hat pixels define that edge. Translucent brim shadows and glows
render over the hair underneath; including them in the cutoff left a thin bare
seam at the front of the red cap.
Unequipping the hat restores the original material and full hair immediately;
equipped IDs, source textures, inventory icons and animation frames never change.
The same equipment path handles local and remote players.

New hats and hairstyles inherit this behavior. Decorative hat-slot accessories
can set `tucks_hair: false`; existing bows, headband and headphones do so.
Full-head covers keep the existing `hides_hair` behavior. Hat contours include
all animation frames to keep the clipped hairline stable and are cached by atlas
region so repeated equips do not repeatedly read pixels or grow the cache.
Transparent side margins inherit the nearest occupied column's lower edge.

`hair_hat_clip.gdshader` uses sprite-local vertex coordinates, independently of
atlas UVs and texture size. See the [Godot CanvasItem shader reference](https://docs.godotengine.org/en/4.5/tutorials/shaders/shader_reference/canvas_item_shader.html).

## Validation (2026-10-12)

- `hair_hat_occlusion_test.gd`: all 19 hairstyles and 27 head items, both facings,
  1,026 pair/facing cases; remote cached snapshots, animation changes, future IDs,
  accessory exceptions, full covers and unequip restoration.
- Rendered checks passed with Compatibility/OpenGL and Mobile/D3D12. Eight
  example pairs in both facings removed 19,890 upper hair pixels, preserved
  8,928 lower hair pixels and restored the exact original portraits after unequip.
  The contour retains 2,952 hair pixels previously lost to the flat cutoff.
  Rendered negative controls specifically verify visible corner-hair recovery
  with Messy Brown Hair/Red Baseball Cap and front-fringe recovery with Crazy
  Hair/Royal Crown, in both directions.
- The Crazy Hair/Red Baseball Cap/Electric Goggles regression reproduced the
  remaining front seam: 81 hair pixels per facing were incorrectly cut beneath
  translucent brim pixels. All 162 now match the original untrimmed layering;
  fully opaque hat coverage and upper-hair clipping still pass. The failing
  control is saved in `front-shadow-before.log` / `.err` in the evidence folder.
- Existing helmet layering, hair/hat expansion and remote equipment performance
  tests passed. Evidence and before/tucked/unequipped previews are under
  `D:/Pixelmania/work/hair-tuck/`.

Run `--script res://tests/hair_hat_occlusion_test.gd` for logic coverage, or use
a rendering driver with `-- --render` for pixel checks and the preview at
`user://hair_hat_preview.png`. Rendering was tested on desktop; this is not a
claim of physical Android-device validation.
`user://hair_hat_corner_correction.png` shows the old flat cutoff, corrected
contour and hat removed, for both reported combinations and both facings.

Client-only change. Backend deployment and published binaries are unchanged.
