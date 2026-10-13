extends RefCounted
## A rectangular body's outside corner is wider than a supported foot stance.
## Release only a tiny overhang; ordinary landings and tile seams stay intact.

const MIN_SUPPORT_PIXELS := 3.0
const CONTACT_EPSILON := 0.05

static func release_unsupported_edge(player, world: Node) -> bool:
	if not player.is_on_floor() or player.velocity.y < 0.0 or world == null:
		return false
	# Sloped floors and nonrectangular actors keep their native physics behavior.
	if absf(player.get_floor_normal().x) > 0.01:
		return false
	var collision = player.cache_collision_shape()
	if collision == null or collision.disabled or not collision.shape is RectangleShape2D:
		return false
	var blocks = world.get("blocks")
	if not blocks is Dictionary or blocks.is_empty():
		return false
	var manager = world.get("block_manager")
	var body: Rect2 = player.get_player_collision_rect_at(player.global_position)
	var margin: float = player.safe_margin + CONTACT_EPSILON
	var query := Rect2(Vector2(body.position.x - margin, body.end.y - margin), Vector2(body.size.x + margin * 2.0, margin * 2.0))
	var spans: Array[Vector2] = []
	var floor_left := INF
	var floor_right := -INF
	var candidates: Array = player.get_candidate_grid_positions_for_rect(world, manager, query)
	# A large machine's collision can extend beyond its stored anchor tile.
	for index in range(player.get_slide_collision_count()):
		var contact: KinematicCollision2D = player.get_slide_collision(index)
		if contact != null and contact.get_normal().y < -0.99:
			var anchor: Vector2i = player.get_grid_pos_from_collision(contact)
			if not candidates.has(anchor):
				candidates.append(anchor)
	for grid in candidates:
		var data = blocks.get(grid, {})
		if not data is Dictionary:
			continue
		var block_type := str(data.get("type", ""))
		if not player.is_floor_support_block_type(world, block_type):
			continue
		var floor_rect: Rect2 = player.get_foreground_block_collision_rect(world, manager, grid, block_type)
		if absf(floor_rect.position.y - body.end.y) > margin:
			continue
		if floor_rect.end.x < body.position.x - margin or floor_rect.position.x > body.end.x + margin:
			continue
		# A deliberately narrow custom platform can support its whole width.
		if floor_rect.size.x < MIN_SUPPORT_PIXELS and body.get_center().x >= floor_rect.position.x and body.get_center().x <= floor_rect.end.x:
			return false
		floor_left = minf(floor_left, floor_rect.position.x)
		floor_right = maxf(floor_right, floor_rect.end.x)
		spans.append(Vector2(maxf(body.position.x, floor_rect.position.x), minf(body.end.x, floor_rect.end.x)))
	if spans.is_empty():
		# Unknown/moving floors are not guessed from world-grid metadata.
		return false
	spans.sort_custom(func(a: Vector2, b: Vector2): return a.x < b.x)
	var support := 0.0
	var covered_until := -INF
	for span in spans:
		support += maxf(0.0, span.y - maxf(span.x, covered_until))
		covered_until = maxf(covered_until, span.y)
	if support >= MIN_SUPPORT_PIXELS - CONTACT_EPSILON:
		return false
	var escape := floor_right - body.position.x + margin
	if body.get_center().x < (floor_left + floor_right) * 0.5:
		escape = floor_left - body.end.x - margin
	if absf(escape) > MIN_SUPPORT_PIXELS + margin * 2.0:
		# Multiple separated narrow supports are not a single block-corner sliver.
		return false
	# Clear the sliver through physics, never teleport through a neighboring wall.
	# Velocity is preserved: this is not horizontal knockback or a falling boost.
	var saved_velocity: Vector2 = player.velocity
	player.move_and_collide(Vector2(escape, 0.0))
	player.velocity = Vector2.ZERO
	player.move_and_slide()
	player.velocity = saved_velocity
	player.invalidate_movement_surface_cache()
	return not player.is_on_floor()
