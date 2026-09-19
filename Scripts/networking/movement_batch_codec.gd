extends RefCounted
## Complete snapshots with field names shared once per batch; no delta state.
const MAX_ROWS := 128
const MAX_FIELDS := 64

static func decode_players(packet: Dictionary) -> Array:
	if not packet.has("player_rows"):
		return packet.get("players", []) if packet.get("players", []) is Array else []
	var fields = packet.get("player_fields", [])
	var rows = packet.get("player_rows", [])
	if not fields is Array or not rows is Array or fields.is_empty() or fields.size() > MAX_FIELDS or rows.size() > MAX_ROWS:
		return []
	var seen := {}
	for field in fields:
		if not field is String or field.is_empty() or field.length() > 64 or seen.has(field):
			return []
		seen[field] = true
	var players := []
	for row in rows:
		if not row is Array or row.size() != fields.size():
			return []
		var player := {}
		for index in range(fields.size()):
			player[fields[index]] = row[index]
		players.append(player)
	return players
