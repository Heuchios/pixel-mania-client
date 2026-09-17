extends SceneTree
class FixtureWorld extends Node:
	const BLOCK_SIZE = 32
	var blocks = {Vector2i.ZERO: {"type": "dirt"}}

func _initialize(): call_deferred("run")

func run():
	var block := StaticBody2D.new()
	var block_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(32, 32)
	block_shape.shape = rectangle
	block.add_child(block_shape)
	root.add_child(block)
	var player = load("res://tests/corner_contact_fixture.gd").new()
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var body_rectangle := RectangleShape2D.new()
	body_rectangle.size = Vector2(17, 24)
	shape.shape = body_rectangle
	shape.position = Vector2(0.5, -5)
	player.add_child(shape)
	root.add_child(player)
	player.configure_player_floor_collision()
	var contacts := 0
	var injected := 0
	var wall := StaticBody2D.new()
	var wall_shape := CollisionShape2D.new()
	wall_shape.shape = rectangle
	wall.add_child(wall_shape)
	root.add_child(wall)
	for side in [-1, 1]:
		wall.position = Vector2(-side * 32, 32)
		for x in range(-13, 29):
			for y in range(32, 38):
				player.position = Vector2(side * x, y)
				player.velocity = Vector2(-side * 160, -200)
				player.ceiling_release_refire_cooldown = 0
				await physics_frame
				player.move_and_slide()
				var solved_velocity: Vector2 = player.velocity
				var solved_position: Vector2 = player.position
				if player.release_airborne_block_corner_contact(-side * 160, -200):
					contacts += 1
					if player.position != solved_position or absf(player.velocity.x) > absf(solved_velocity.x) + 0.01:
						injected += 1
	print("CORNER_CONTACT_PROBE contacts=%d injected=%d" % [contacts, injected])
	assert(contacts > 0 and injected == 0)
	var fixture_world := FixtureWorld.new()
	root.add_child(fixture_world)
	player.fixture_world = fixture_world
	player.position = Vector2(22, -24)
	player.velocity = Vector2(0, 200)
	await physics_frame
	player.move_and_slide()
	var before: Vector2 = player.position
	var floor_contact: bool = player.is_on_floor()
	assert(floor_contact)
	for frame in range(10):
		player.velocity = Vector2(0, 20)
		await physics_frame
		player.move_and_slide()
		player.release_airborne_block_corner_contact(0, 20)
		player.recover_airborne_block_corner_overlap(before, [])
		assert(player.is_on_floor())
		assert(absf(player.position.x - before.x) < 0.01, "Valid edge landing must not be shoved sideways")
		assert(absf(player.velocity.y) < 0.01, "Floor contact must not restore falling velocity")
	print("CORNER_CONTACT_TEST_OK: 504 mirrored corner approaches and stable edge landing")
	fixture_world.free()
	player.free()
	block.free()
	wall.free()
	quit(0)
