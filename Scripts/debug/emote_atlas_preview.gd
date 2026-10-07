extends Node2D

## Run this scene with F6 to inspect the same atlas resources used by both players.
var paused := false
var mirrored := false

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		get_tree().quit()
	elif event.keycode == KEY_F:
		mirrored = not mirrored
		for child in get_children():
			if child is AnimatedSprite2D:
				child.flip_h = mirrored
	elif event.keycode == KEY_SPACE:
		paused = not paused
		for child in get_children():
			if child is AnimatedSprite2D:
				if paused:
					child.pause()
				else:
					child.play()
