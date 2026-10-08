extends RefCounted
## Validate a complete server snapshot before replacing the visible world.
const Atlas = preload("res://Scripts/ItemAtlasDB.gd")

static func validate(data: Dictionary, items: Dictionary, width: int, height: int, normalize_type: Callable) -> Dictionary:
	var result := {"ok": false, "reason": "", "foreground": [], "background": []}
	var gate_count := 0
	for layer in ["foreground", "background"]:
		var raw: Variant = data.get(layer)
		if not (raw is Dictionary or raw is Array):
			return _failure("missing_" + layer)
		if raw.size() > width * height:
			return _failure("oversized_" + layer)
		var cells := {}
		var entries: Array = []
		var values: Array = raw if raw is Array else raw.keys()
		for value in values:
			var entry: Dictionary
			if raw is Dictionary:
				var parts := str(value).split(",")
				if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
					return _failure("invalid_coordinate_" + layer)
				var tile: Variant = raw[value]
				entry = tile.duplicate(true) if tile is Dictionary else {"item_id": tile}
				# The dictionary key owns the coordinate; conflicting metadata is invalid.
				if (entry.has("x") and entry.x != int(parts[0])) or (entry.has("y") and entry.y != int(parts[1])):
					return _failure("conflicting_coordinate_" + layer)
				entry.x = int(parts[0])
				entry.y = int(parts[1])
			else:
				if not value is Dictionary:
					return _failure("invalid_tile_" + layer)
				entry = value.duplicate(true)
			if not _coordinate_valid(entry.get("x"), width) or not _coordinate_valid(entry.get("y"), height):
				return _failure("invalid_coordinate_" + layer)
			var grid := Vector2i(int(entry.x), int(entry.y))
			if cells.has(grid):
				return _failure("duplicate_coordinate_" + layer)
			cells[grid] = true
			var block_type := str(entry.get("block_type", entry.get("type", ""))).strip_edges()
			if block_type == "":
				block_type = Atlas.resolve_item_key(entry.get("item_id", entry.get("id", "")))
			if normalize_type.is_valid():
				block_type = str(normalize_type.call(block_type))
			if block_type == "" or not items.has(block_type) or str(items[block_type].get("category", "")) != "block":
				return _failure("unknown_tile_" + layer + ":" + block_type)
			entry.block_type = block_type
			entries.append(entry)
			if layer == "foreground" and block_type == "entrance_gate":
				gate_count += 1
		result[layer] = entries
	if gate_count != 1:
		return _failure("entrance_count:" + str(gate_count))
	result.ok = true
	return result

static func _coordinate_valid(value: Variant, limit: int) -> bool:
	if not (value is int or value is float):
		return false
	return is_finite(float(value)) and float(value) == floor(float(value)) and value >= 0 and value < limit

static func _failure(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}

static func matches_loaded(entries: Array, cells: Dictionary) -> bool:
	if entries.size() != cells.size():
		return false
	for entry in entries:
		var actual: Variant = cells.get(Vector2i(int(entry.x), int(entry.y)))
		if not actual is Dictionary or str(actual.get("type", "")) != str(entry.block_type):
			return false
	return true
