extends SceneTree

const Dust = preload("res://Scripts/player_ground_dust.gd")
const DT := 1.0 / 60.0
var actor: CharacterBody2D


func _initialize() -> void:
	call_deferred("run")


func tick() -> void:
	await physics_frame
	actor.run_player_movement_step(DT)
	actor.ground_dust._process(DT)
	actor.ground_dust.set_process(false)


func run() -> void:
	create_timer(12.0).timeout.connect(func(): quit(1))
	var floor_body := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	var floor_rect := RectangleShape2D.new()
	floor_rect.size = Vector2(300, 32)
	floor_shape.shape = floor_rect
	floor_body.add_child(floor_shape)
	floor_body.position = Vector2(100, 136)
	root.add_child(floor_body)
	actor = load("res://tests/ground_dust_player_fixture.gd").new()
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(17, 24)
	collision.shape = shape
	collision.position = Vector2(0.5, -5)
	actor.add_child(collision)
	actor.position = Vector2(80, 113)
	root.add_child(actor)
	actor.set_physics_process(false)
	actor.collision_trace_enabled = false
	for i in range(5):
		await tick()
	assert(actor.is_on_floor())
	assert(actor.ground_dust.particles.is_empty(), "Spawning grounded must not burst")
	actor.holding_jump = true
	await tick()
	assert(not actor.is_on_floor())
	assert(actor.ground_dust.particles.size() == 8, "Real takeoff emits one small burst")
	var first_origin: Vector2 = actor.ground_dust.particles[0].origin
	for i in range(5):
		await tick()
	assert(actor.ground_dust.particles.size() == 8, "Holding jump must not stream dust")
	assert(actor.ground_dust.particles[0].origin == first_origin, "Dust stays on the ground as actor moves")
	actor.do_jump()
	await tick()
	assert(actor.ground_dust.particles.size() == 8, "An air jump cannot kick up ground dust")
	var landed := false
	for i in range(100):
		await tick()
		if actor.is_on_floor():
			landed = true
			break
	assert(landed)
	assert(actor.ground_dust.particles.size() == 12, "Real floor collision emits the fuller landing burst")
	assert(actor.ground_dust.particles[0].origin.y < 120.0, "Dust begins above the floor")
	for i in range(40):
		await tick()
	assert(actor.ground_dust.particles.is_empty() and not actor.ground_dust.is_processing(), "Burst expires and idle dust costs no process loop")
	actor.holding_jump = false
	await tick()
	actor.wet = true
	actor.holding_jump = true
	await tick()
	assert(actor.ground_dust.particles.is_empty(), "Swimming must keep its own water effect")
	actor.free()
	floor_body.free()
	check_contact_edges()
	check_remote_route()
	print("GROUND_DUST_PASS: real takeoff/landing, held input, air jumps, world anchoring, water, teleports, idle jitter, remote contacts and cleanup")
	quit()


func check_contact_edges() -> void:
	var effect := Dust.new()
	root.add_child(effect)
	effect.observe_contact(Vector2.ZERO, true, 0, DT)
	effect.observe_contact(Vector2(0, -0.5), false, 20, DT)
	effect.observe_contact(Vector2.ZERO, true, 30, DT)
	assert(effect.particles.is_empty(), "Tiny floor jitter is not a landing")
	effect.observe_contact(Vector2(0, -10), false, 100, 0.1)
	effect.observe_contact(Vector2(200, 0), true, 300, 0.1)
	assert(effect.particles.is_empty(), "Teleports must reset contact history")
	effect.observe_contact(Vector2(200, -10), false, -430, DT, false)
	assert(effect.particles.is_empty(), "Disabled/dead/noclip actors must be quiet")
	for i in range(20):
		effect.emit_burst(Vector2.ZERO, true)
	assert(effect.particles.size() <= effect.MAX_PARTICLES)
	effect._process(1.0)
	assert(effect.particles.is_empty())
	effect.free()


func check_remote_route() -> void:
	var manager = load("res://Scripts/player_manager.gd").new()
	var remote := Node2D.new()
	root.add_child(remote)
	remote.set_meta("network_on_floor", true)
	manager.update_remote_ground_dust(remote, Vector2.ZERO, 0.05, true, false)
	remote.set_meta("network_on_floor", false)
	remote.set_meta("network_velocity_y", -430.0)
	manager.update_remote_ground_dust(remote, Vector2(0, -18), 0.05, true, false)
	var effect = remote.get_node(Dust.NODE_NAME)
	assert(effect.particles.size() == 8)
	manager.update_remote_ground_dust(remote, Vector2(0, -18), 0.05, true, false)
	assert(effect.particles.size() == 8, "Repeated snapshots must not repeat takeoff")
	remote.set_meta("network_velocity_y", 300.0)
	manager.update_remote_ground_dust(remote, Vector2(0, -10), 0.05, true, false)
	remote.set_meta("network_on_floor", true)
	remote.set_meta("network_velocity_y", 0.0)
	manager.update_remote_ground_dust(remote, Vector2.ZERO, 0.05, true, false)
	assert(effect.particles.size() == 20)
	manager.update_remote_ground_dust(remote, Vector2.ZERO, 0.05, true, false)
	assert(effect.particles.size() == 20, "Repeated grounded snapshots must not repeat landing")
	manager.update_remote_ground_dust(remote, Vector2.ZERO, 0.05, true, true)
	assert(effect.particles.is_empty(), "Authoritative snaps clear dust history")
	remote.free()
	manager.free()
