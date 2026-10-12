# Smooth zoom and startup splash

Desktop wheel/key zoom and mobile zoom-button taps now ease to their destination.
Rapid inputs accumulate from the requested destination, so zooming again or
reversing direction during a transition preserves each input. Holding a mobile
zoom button follows a continuous target; releasing the button or cancelling it
through UI eases back to a whole-pixel resting scale.

Zoom easing uses elapsed time and gives the same response at 30, 60 and 120 FPS.
Existing minimum/maximum limits and square artwork pixels remain intact. World
entry applies the default immediately and cancels a previous world's transition.
Camera translation and overhead text retain their final-frame alignment.

The engine startup logo is disabled with
`application/boot_splash/show_image=false`. The Android export preset also sets
`splash_screen/disable_godot_boot_splash=true`; its existing PixelMania icon is
preserved for the Android system launch screen. No startup artwork was replaced.

Verification on 2026-10-12:

- `smooth_camera_zoom_test.gd`: intermediate scales, rapid wheel input,
  reversal, equal timing at 30/60/120 FPS, real mobile-control routing,
  touch ownership, UI cancellation, limits, resize and immediate world entry.
- `mobile_zoom_test.gd`: tap/hold/release and frame-rate behavior passed.
- `camera_pixel_alignment_test.gd`: settled pixel widths, scrolling, zoom,
  parallax and resize passed.
- `username_camera_alignment_test.gd`: zero local/remote anchor drift passed.
- `overhead_text_stability_test.gd`: zero changing glyph crops and zero machine
  anchor drift, including during smooth zoom, in Compatibility/OpenGL and
  Forward Mobile/D3D12.

These are client source/export configuration changes for staging. No backend
update is needed. Existing published Windows/Android binaries need rebuilding
to include these changes.
