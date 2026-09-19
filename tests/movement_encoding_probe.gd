extends SceneTree
const Codec = preload("res://Scripts/networking/movement_batch_codec.gd")

func _init():
	var raw := FileAccess.get_file_as_string("res://tests/fixtures/movement_batch_legacy.json")
	var packet: Dictionary = JSON.parse_string(raw)
	var wire := FileAccess.get_file_as_string("res://tests/fixtures/movement_batch_columns.json")
	for mode in ["original", "columns"]:
		var times := []
		for sample in range(21):
			var started := Time.get_ticks_usec()
			for iteration in range(100):
				var parsed: Dictionary = JSON.parse_string(raw if mode == "original" else wire)
				assert(Codec.decode_players(parsed) == packet.players)
			if sample > 0: times.append(float(Time.get_ticks_usec() - started) / 100000.0)
		times.sort()
		print("ENCODING_PROBE ", JSON.stringify({"mode": mode, "players": packet.players.size(), "wire_bytes": raw.length() if mode == "original" else wire.length(), "median_ms": times[10], "p95_ms": times[19]}))
	quit()
