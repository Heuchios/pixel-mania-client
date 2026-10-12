# Stable usernames and machine labels

Machine labels were projected during `_process`, before the camera's final
render update. Overhead fonts also used fractional positioning, so scrolling
and window stretch could change which font pixels were sampled.

Usernames, tree text and timed machine labels now use the pixel font and snap
their render position at the actual output resolution. Machine labels and
remote usernames refresh after camera alignment, alongside the local username.
Logical anchors, movement, timer updates, fading and label layering remain
unchanged. A 0.01-output-pixel sampling bias avoids floating-point error at
nearest-filter boundaries when fonts are stretched by a fractional scale.
Render callbacks disconnect when their managers leave the tree.

Verification on 2026-10-12:

- `overhead_text_stability_test.gd`: rendered local/remote names, Bait Box and
  Coloured Block Maker at three viewport scales, with scrolling and player
  ascent/descent. Zero changing glyph crops and zero machine anchor drift in
  both Compatibility/OpenGL and Forward Mobile/D3D12. Also checks callback
  reuse, cleanup and machine-label hiding on world exit.
- `username_camera_alignment_test.gd`: zero local/remote anchor drift during
  jumps, falls, zoom and resize; UI hiding and growth fade timing passed.
- `camera_pixel_alignment_test.gd`: scrolling, parallax, zoom and resize passed.
- `remote_username_z_order_test.gd`: username layering and anchors passed.
- `timed_machine_harvest_test.gd`: provider cooldowns, harvest classification
  and ready/running visuals passed.

This is a client source change for staging. It needs no backend update;
published Windows and Android binaries have not been rebuilt by this change.
