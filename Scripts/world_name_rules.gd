extends RefCounted

const MESSAGE := "World names must be 1-32 letters or numbers (A-Z, 0-9). No spaces or symbols."

static func is_valid(value: String) -> bool:
	if value.is_empty() or value.length() > 32:
		return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if not ((code >= 65 and code <= 90) or (code >= 97 and code <= 122) or (code >= 48 and code <= 57)):
			return false
	return true

static func is_valid_door_destination(value: String) -> bool:
	return value == "" or value.to_lower().begins_with("door:") or is_valid(value.get_slice(":", 0))

static func is_event_instance(value: String) -> bool:
	var suffix := value.to_upper().trim_prefix("LANDFILL")
	if suffix == value.to_upper():
		return false
	# Recognize old transient instances for cleanup as well as new numeric names.
	suffix = suffix.trim_prefix("_")
	return not suffix.is_empty() and suffix.is_valid_int() and suffix.to_int() >= 0
