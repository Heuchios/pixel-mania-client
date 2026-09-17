extends RefCounted
## Presentation only: server energy values and production rules are unchanged.

static func describe(state: Dictionary) -> Dictionary:
	var count := maxi(0, int(state.get("produced_count", state.get("output_count", 0))))
	var capacity := maxi(1, int(state.get("output_capacity", 200)))
	var enabled := bool(state.get("enabled", false))
	var running := bool(state.get("running", false))
	var battery := maxi(0, int(state.get("battery_watts", 0)))
	var linked := bool(state.get("linked_pole", false))
	var source := str(state.get("power_source", "none"))
	var result := {"badge": "OFF", "hint": "Turn on to start production", "icon": "II", "color": Color(0.7, 0.75, 0.85)}
	if count >= capacity:
		result = {"badge": "FULL", "hint": "Collect oil, then turn on to continue", "icon": "!", "color": Color(1.0, 0.8, 0.2)}
	elif not enabled:
		pass
	elif running:
		result = {"badge": "RUNNING", "hint": "Producing 1 oil per powered hour", "icon": ">", "color": Color(0.4, 1.0, 0.65)}
		if source == "battery" or source == "hybrid":
			result.badge = "BACKUP"
			result.hint = "Using backup batteries" if source == "battery" else "Batteries cover the network shortfall"
			result.icon = "B"
			result.color = Color(1.0, 0.8, 0.2)
	elif not linked and battery <= 0:
		result = {"badge": "NO LINK", "hint": "Connect a pole or add batteries", "icon": "?", "color": Color(1.0, 0.5, 0.4)}
	elif battery <= 0 and int(state.get("transformer_watts", 0)) <= 0:
		result = {"badge": "EMPTY", "hint": "Charge connected transformers or add batteries", "icon": "!", "color": Color(1.0, 0.5, 0.4)}
	else:
		result = {"badge": "STARTING", "hint": "Waiting for the next production update", "icon": "...", "color": Color(0.7, 0.8, 1.0)}
	result["storage_ratio"] = clampf(float(count) / capacity, 0.0, 1.0)
	result["progress"] = clampf(float(state.get("crude_progress", 0.0)), 0.0, 1.0)
	result["next_text"] = ("%dm left" % maxi(1, int(ceil((1.0 - result.progress) * 60.0 - 0.000001)))) if running else "Paused"
	if count >= capacity:
		result.next_text = "Full"
	result["reserve_text"] = "Backup: %dm" % int(floor(float(battery) / 100.0 * 60.0))
	return result
