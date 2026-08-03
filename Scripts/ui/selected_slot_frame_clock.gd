extends RefCounted


static func frame_index(frame_count: int, frame_seconds: float) -> int:
	if frame_count <= 0 or frame_seconds <= 0.0:
		return 0
	var frame_duration_ms: float = maxf(1.0, frame_seconds * 1000.0)
	return int(floor(float(Time.get_ticks_msec()) / frame_duration_ms)) % frame_count
