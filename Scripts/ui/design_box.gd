@tool
extends Node
class_name DesignBox

## Keeps a UI scene that was authored at absolute coordinates composed on any screen.
##
## Background
## ----------
## Every UI scene in this project is laid out at fixed pixel positions inside the
## 1920x1080 design size (layout_mode = 0 / anchors_preset = 0). That is fine as long
## as the canvas is exactly 1920x1080.
##
## With window/stretch/mode = "canvas_items" Godot always scales the canvas
## UNIFORMLY -- it picks min(width / 1920, height / 1080) and applies that one factor
## to both axes, so nothing is ever stretched or distorted. What
## window/stretch/aspect = "expand" changes is the size of the logical canvas: instead
## of adding black bars, the viewport grows past the design size in whichever axis has
## room. On a 20:9 phone the canvas is about 2400x1080 rather than 1920x1080.
##
## Absolute coordinates are measured from the canvas's top-left corner, so on that
## wider canvas the whole composition stays pinned to the left and the extra ~480
## units open up as dead space on the right. That is the drift, and it is a position
## problem, not a scaling one.
##
## What this does
## --------------
## Shifts the scene's top-left-anchored children by half the surplus, which re-centres
## the design box on the canvas. Children anchored to an edge or stretched across the
## parent -- backgrounds, full-rect overlays -- are deliberately left alone so they
## keep covering the entire screen behind the centred UI.
##
## With aspect = "expand" the viewport is never SMALLER than the design size in either
## axis (it equals the design size in one axis and exceeds it in the other), so the
## offset is always >= 0 and no part of the UI is ever pushed off-screen.
##
## Usage: call DesignBox.attach(self) from the scene root's _ready(), after the
## Engine.is_editor_hint() guard.

const META_BASE_POSITION := &"design_box_base_position"

var _root: Control = null
var _design_size := Vector2(1920.0, 1080.0)
var _reapply_queued := false


## Adds a DesignBox to `root`, or returns the one already there.
static func attach(root: Control) -> DesignBox:
	if root == null:
		push_warning("DesignBox.attach was given a null root.")
		return null

	for child in root.get_children():
		if child is DesignBox:
			return child as DesignBox

	var box := DesignBox.new()
	box.name = "DesignBox"
	root.add_child(box)
	return box


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_root = get_parent() as Control
	if _root == null:
		push_warning("DesignBox must be a child of the Control it centres.")
		return

	_design_size = Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 1920)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 1080))
	)

	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_queue_apply):
		viewport.size_changed.connect(_queue_apply)

	# Panels added after _ready still need centring.
	if not _root.child_entered_tree.is_connected(_on_root_child_entered_tree):
		_root.child_entered_tree.connect(_on_root_child_entered_tree)

	_apply()


func _on_root_child_entered_tree(_node: Node) -> void:
	_queue_apply()


func _queue_apply() -> void:
	# A resize can fire several times in one frame; coalesce into a single pass.
	if _reapply_queued:
		return
	_reapply_queued = true
	call_deferred("_apply")


func _apply() -> void:
	_reapply_queued = false

	if _root == null or not is_instance_valid(_root):
		return

	var viewport := get_viewport()
	if viewport == null:
		return

	var viewport_size := viewport.get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	# floor() keeps the shift on whole canvas units. This project renders pixel art
	# with nearest-neighbour filtering (rendering/textures/canvas_textures/
	# default_texture_filter = 0), so a half-unit offset would make edges shimmer.
	var offset := ((viewport_size - _design_size) * 0.5).floor()
	offset.x = maxf(0.0, offset.x)
	offset.y = maxf(0.0, offset.y)

	for child in _root.get_children():
		var control := child as Control
		if control == null:
			continue
		if not _is_pinned_to_top_left(control):
			continue

		# The authored position is recorded once, so repeated passes stay idempotent
		# instead of compounding the offset on every resize.
		if not control.has_meta(META_BASE_POSITION):
			control.set_meta(META_BASE_POSITION, control.position)

		control.position = (control.get_meta(META_BASE_POSITION) as Vector2) + offset


## True only for children pinned to the parent's top-left corner, which is what
## layout_mode = 0 / anchors_preset = 0 produces. Anything anchored to an edge or
## stretched across the parent is left where it is.
func _is_pinned_to_top_left(control: Control) -> bool:
	return is_zero_approx(control.anchor_left) \
		and is_zero_approx(control.anchor_top) \
		and is_zero_approx(control.anchor_right) \
		and is_zero_approx(control.anchor_bottom)
