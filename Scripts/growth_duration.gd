extends RefCounted

static func format_seconds(seconds: float) -> String:
	var remaining := int(ceil(maxf(0.0, seconds)))
	var parts := PackedStringArray()
	for unit in [[86400, "d"], [3600, "h"], [60, "m"], [1, "s"]]:
		var amount := int(float(remaining) / float(unit[0]))
		remaining %= int(unit[0])
		if amount > 0:
			parts.append(str(amount) + str(unit[1]))
	return " ".join(parts) if not parts.is_empty() else "0s"
