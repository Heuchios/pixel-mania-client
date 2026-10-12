extends RefCounted

const Style = preload("res://Scripts/ui/pixel_ui_style.gd")
# Stay just inside the same nearest-filter sample at fractional font scales.
# Floating-point transform error at an exact texel boundary can change a glyph
# by one pixel even after rounding. This bias is only 1/100 of an output pixel.
const SAMPLE_BIAS := Vector2(0.01, 0.01)

static func prepare_label(label: Label) -> void:
	label.set_meta("pixelmania_pixel_text", true)
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var font := Style.get_pixel_game_font()
	if font != null:
		label.add_theme_font_override("font", font)
		if label.label_settings != null:
			label.label_settings.font = font

static func snap_render_position(label: Control) -> void:
	if not is_instance_valid(label) or not label.is_inside_tree():
		return
	# Round at the actual output resolution, including fractional window stretch.
	# Keep logical layout/anchors intact; only offset this frame's render transform.
	var local := label.get_transform()
	var output := label.get_viewport().get_stretch_transform() * label.get_global_transform_with_canvas()
	var parent_output := output * local.affine_inverse()
	local.origin += parent_output.affine_inverse().basis_xform(output.origin.round() + SAMPLE_BIAS - output.origin)
	RenderingServer.canvas_item_set_transform(label.get_canvas_item(), local)
