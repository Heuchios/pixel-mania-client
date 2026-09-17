extends Node2D

# One static draw behind the window; redraw only when its size changes.
var panel: Control
var style: StyleBox

func _ready() -> void:
	panel = get_parent() as Control
	show_behind_parent = true
	style = UIAtlasDB.get_stylebox("inner_panel").duplicate()
	self_modulate = Color(1, 1, 1, 0.4)
	panel.resized.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	if panel != null and style != null:
		style.draw(get_canvas_item(), Rect2(Vector2(11, 14), panel.size))
