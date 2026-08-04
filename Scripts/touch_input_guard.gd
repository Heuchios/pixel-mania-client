extends RefCounted


static func is_emulated_mouse_from_touch(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton or event is InputEventMouseMotion):
		return false
	return event.device == InputEvent.DEVICE_ID_EMULATION
