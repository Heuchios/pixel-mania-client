# Device UI scaling audit

Inspected the active `pixel-mania` client, preserving existing uncommitted UI work.

## Findings and changes

- `project.godot` uses a 1920x1080 logical canvas with `canvas_items` and `expand`.
  A 1280x720 window still has a 1920x1080 logical canvas; a 1600x720 phone has
  a 2400x1080 canvas. This is expected aspect-ratio adaptation, not distortion.
  Kept this policy: changing it globally to `keep` would add letterboxing.
- `inventory_manager.gd` added a mobile-only 1.08–1.18 HUD multiplier based on
  a separate 1280x720 reference. At the production logical resolution it reaches
  1.18. Removed this extra multiplier so hotbar dimensions and the drawer's hotbar
  allowance match PC. Touch action buttons keep their separate accessibility size.
- `mobile_controls.gd` only clamped custom layouts or controls with a nonzero
  drawer offset to the safe rectangle. Default controls now clamp too. OS screen
  pixels are converted using the control's inverse screen transform, rather than
  a full-display ratio that assumed the window filled the entire display.
- `recipe_book_scene.gd` fitted an assumed 1024x660 window while the current
  container layout measured 1024x1443 in the test. The fitter now uses actual
  layout dimensions and refits on window resize. This prevents clipping; it does
  not redesign the recipe book's tall content layout.
- `tests/ui_atlas_render.gd --phone` previously disabled scaling and used a
  640x360 logical canvas. It now preserves production scaling and previews a
  1600x720 physical window. `--resolution=WIDTHxHEIGHT` supports other devices.

## Other inspected paths

Login uses center/edge anchors. Lobby uses the existing `DesignBox` helper to
center its absolute-coordinate composition; edge-anchored event UI is separate.
Settings, menu, shop, leaderboard, inventory and recipe book have their own fit
or center logic. Camera zoom is applied in `player_manager.gd` independently of
HUD scale. Wider canvases therefore show more world at the same zoom.

For future UI, use center anchors for dialogs, edge anchors for HUD, containers
for content, and logical canvas units throughout. Avoid applying a physical
resolution multiplier to controls already scaled by Godot. A shared safe-area
root for all edge HUD is a useful follow-up; this patch protects touch controls,
not every existing HUD element.

## Validation

Godot 4.7.1 headless:

- `tests/device_ui_scaling_test.gd`: PC/Android HUD parity and touch safe bounds
  at four logical sizes; settings, inventory and recipe window containment at
  1280x720, 1920x1080, 1600x720, 2400x1080 and 1024x768 physical sizes, using
  production canvas scaling. Passed.
- `tests/mobile_inventory_layout_test.gd`: passed.
- `git diff --check`: passed (existing CRLF normalization warnings).

Use an explicit writable `--log-file` when running this Godot build in the
sandbox; its default logging launch crashed. Runs also reported an environment
certificate-store error from the network autoload, unrelated to layout assertions.

No Android APK was rebuilt or installed. Automated tests simulate platform
branches and safe bounds; they do not prove native Android cutout coordinates,
touch usability, GPU rendering or every dialog/content state. Before release,
visually compare the same scene and zoom on PC and a landscape Android phone,
including gesture navigation, a cutout, open inventory and customized controls.

References:
- https://docs.godotengine.org/en/4.5/tutorials/rendering/multiple_resolutions.html
- https://docs.godotengine.org/en/stable/tutorials/2d/2d_transforms.html
