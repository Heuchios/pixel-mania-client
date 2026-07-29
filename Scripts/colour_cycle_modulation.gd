extends RefCounted

const DEFAULT_SPEED := 0.08
const DEFAULT_SATURATION := 0.85
const DEFAULT_VALUE := 1.0
const GRID_FLOW_X := 0.015
const GRID_FLOW_Y := 0.008


static func is_colour_cycle_item(item_data: Dictionary) -> bool:
	return bool(item_data.get("colour_cycle_block", false))


static func get_colour_cycle_modulate(item_data: Dictionary, phase_seed := 0.0) -> Color:
	var speed: float = maxf(0.0, float(item_data.get("colour_cycle_speed", DEFAULT_SPEED)))
	var saturation: float = clampf(float(item_data.get("colour_cycle_saturation", DEFAULT_SATURATION)), 0.0, 1.0)
	var value: float = clampf(float(item_data.get("colour_cycle_value", DEFAULT_VALUE)), 0.0, 1.0)
	var alpha: float = clampf(float(item_data.get("colour_cycle_alpha", 1.0)), 0.0, 1.0)
	var elapsed_seconds := float(Time.get_ticks_msec()) / 1000.0
	var hue := fposmod(elapsed_seconds * speed + float(phase_seed), 1.0)
	return Color.from_hsv(hue, saturation, value, alpha)


static func get_grid_phase_seed(grid_pos: Vector2i) -> float:
	return fposmod(float(grid_pos.x) * GRID_FLOW_X + float(grid_pos.y) * GRID_FLOW_Y, 1.0)
