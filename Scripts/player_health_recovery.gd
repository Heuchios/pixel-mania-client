extends RefCounted
const MAX_HEALTH := 10
const DELAY := 3.0
const STEP := 0.5
var quiet_time := 0.0
var healing_time := 0.0

func damaged() -> void:
	quiet_time = 0.0
	healing_time = 0.0

func advance(delta: float, health: int, enabled: bool) -> int:
	if not enabled or health <= 0 or health >= MAX_HEALTH:
		damaged()
		return health
	var before := quiet_time
	quiet_time += maxf(0.0, delta)
	healing_time += maxf(0.0, quiet_time - maxf(before, DELAY))
	while healing_time >= STEP and health < MAX_HEALTH:
		healing_time -= STEP
		health += 1
	return health
