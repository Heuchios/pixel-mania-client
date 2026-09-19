extends RefCounted
## Small, deterministic state machine shared by the fishing manager and its tests.
## One fresh press per sweep; resting or repeated presses never spend another try.

const MAX_MISSES := 3
const SWEEP_SECONDS := 3.0
const REST_SECONDS := 0.65
const ZONE_CENTERS := [0.48, 0.60, 0.43, 0.55, 0.48, 0.56]

var required_pulls := 3
var pulls := 0
var misses := 0
var round_index := 0
var cursor := 0.0
var zone_start := 0.26
var zone_size := 0.44
var base_zone_size := 0.44
var rest_left := 0.0
var outcome := ""
var feedback := "Tap REEL in the green zone."


func start(is_rare: bool, lure_bonus: float = 0.0) -> void:
	required_pulls = 4 if is_rare else 3
	pulls = 0
	misses = 0
	round_index = 0
	cursor = 0.0
	base_zone_size = clampf(0.44 + lure_bonus, 0.44, 0.56)
	rest_left = 0.35 # The hook press cannot also count as the first pull.
	outcome = ""
	feedback = "Fish hooked! Get ready..."
	_update_zone()


func update(delta: float) -> void:
	if outcome != "":
		return
	# A stalled frame must not jump over a player's entire timing window.
	var step := clampf(delta, 0.0, 0.1)
	if rest_left > 0.0:
		rest_left = maxf(0.0, rest_left - step)
		if rest_left <= 0.0:
			cursor = 0.0
			_update_zone()
			feedback = "Tap REEL in the green zone."
		return
	cursor = minf(1.0, cursor + step / SWEEP_SECONDS)
	if cursor >= 1.0:
		_finish_pull(false)


func pull() -> void:
	if outcome != "" or rest_left > 0.0:
		return
	_finish_pull(cursor >= zone_start and cursor <= zone_start + zone_size)


func _finish_pull(hit: bool) -> void:
	if hit:
		pulls += 1
		feedback = "Good pull! Getting closer..."
		if pulls >= required_pulls:
			outcome = "caught"
			feedback = "Reeled in!"
	else:
		misses += 1
		feedback = "Try again! Your progress is safe."
		if misses >= MAX_MISSES:
			outcome = "escaped"
			feedback = "The fish slipped away."
	rest_left = REST_SECONDS
	round_index += 1


func _update_zone() -> void:
	zone_size = minf(0.64, base_zone_size + misses * 0.06)
	zone_start = float(ZONE_CENTERS[round_index % ZONE_CENTERS.size()]) - zone_size * 0.5


func snapshot() -> Dictionary:
	return {
		"pulls": pulls, "required_pulls": required_pulls,
		"misses": misses, "max_misses": MAX_MISSES,
		"cursor": cursor, "zone_start": zone_start, "zone_size": zone_size,
		"resting": rest_left > 0.0, "feedback": feedback, "outcome": outcome
	}
