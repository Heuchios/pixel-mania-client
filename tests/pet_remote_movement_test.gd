extends SceneTree

const Follower = preload("res://Scripts/pet_follower.gd")
const Items = preload("res://Scripts/item_database.gd")
var failures := 0
var checks := 0

class OldFacingFollower extends Follower:
	func get_target_facing() -> float:
		var direction: float = signf(target.velocity.x) if target is CharacterBody2D else facing
		return direction if direction != 0 else facing


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func spawn_pet(world: Node, actor: Node2D, definition: Dictionary):
	var pet = OldFacingFollower.new() if "--old-facing" in OS.get_cmdline_user_args() else Follower.new()
	pet.target = actor
	pet.item = definition
	world.add_child(pet)
	pet.set_physics_process(false)
	return pet


func same_frame(first: Sprite2D, second: Sprite2D) -> bool:
	var a := first.texture as AtlasTexture
	var b := second.texture as AtlasTexture
	return a != null and b != null and a.atlas == b.atlas and a.region == b.region and a.margin == b.margin


func run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var floor := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(2000, 32)
	shape.shape = rectangle
	floor.position = Vector2(400, 128)
	floor.add_child(shape)
	world.add_child(floor)
	await physics_frame
	var local := CharacterBody2D.new()
	local.position = Vector2(200, 96)
	var visual := Node2D.new()
	visual.name = "PlayerVisual"
	local.add_child(visual)
	world.add_child(local)
	var remote := Node2D.new()
	remote.position = Vector2(500, 96)
	world.add_child(remote)
	var variants := 0
	for id in Items.ITEMS:
		var definition: Dictionary = Items.ITEMS[id]
		if not definition.has("pet_species"):
			continue
		variants += 1
		for initial_facing in [-1, 1]:
			local.velocity = Vector2.ZERO
			local.position = Vector2(200, 96)
			visual.scale.x = initial_facing
			remote.position = Vector2(500, 96)
			remote.set_meta("facing", initial_facing)
			# A stale/missing velocity must not control a remote pet's side.
			remote.set_meta("network_velocity_x", -initial_facing * 100.0)
			var local_pet = spawn_pet(world, local, definition)
			var remote_pet = spawn_pet(world, remote, definition)
			var flying := bool(definition.pet_flying)
			var expected := Vector2(-initial_facing * 38, -20 if flying else 7)
			check((local_pet.global_position - local.global_position).is_equal_approx(expected), "%s local spawn uses owner facing and pet height" % id)
			check((remote_pet.global_position - remote.global_position).is_equal_approx(expected), "%s remote spawn uses received facing and pet height" % id)
			check(remote_pet.sprite.flip_h == (initial_facing < 0), "%s mirrors before its first frame" % id)
			check(remote_pet.sprite.texture != null, "%s has artwork on the first frame" % id)
			# Feed equivalent owner movement into real physics following on both sides.
			for direction in [initial_facing, -initial_facing]:
				local.velocity.x = direction * 90.0
				visual.scale.x = direction
				remote.set_meta("facing", direction)
				for step in range(36):
					local.position.x += direction * 1.5
					remote.position.x += direction * 1.5
					local_pet._physics_process(1.0 / 60.0)
					remote_pet._physics_process(1.0 / 60.0)
				var local_offset: Vector2 = local_pet.global_position - local.global_position
				var remote_offset: Vector2 = remote_pet.global_position - remote.global_position
				check(local_offset.distance_to(remote_offset) < 0.01, "%s local and remote paths agree after moving/turning" % id)
				check(remote_pet.facing == direction and remote_pet.sprite.flip_h == (direction < 0), "%s updates remote movement facing" % id)
				check(same_frame(local_pet.sprite, remote_pet.sprite), "%s local and remote movement frames agree" % id)
			# Turn while stationary; observers receive facing even without velocity.
			local.velocity = Vector2.ZERO
			visual.scale.x *= -1
			remote.set_meta("facing", -int(remote.get_meta("facing")))
			for step in range(90):
				local_pet._physics_process(1.0 / 60.0)
				remote_pet._physics_process(1.0 / 60.0)
			check(remote_pet.facing == signf(visual.scale.x), "%s follows an idle turn" % id)
			check(signf(remote_pet.position.x - remote.position.x) == -remote_pet.facing, "%s settles behind its remote owner" % id)
			check((local_pet.position - local.position).distance_to(remote_pet.position - remote.position) < 0.01, "%s idle follow paths agree" % id)
			# World-entry corrections/teleports must not leave pets at old positions.
			local.position.x += 400
			remote.position.x += 400
			local_pet._physics_process(1.0 / 60.0)
			remote_pet._physics_process(1.0 / 60.0)
			check(remote_pet.position.distance_to(remote.position) < 50, "%s catches up after a teleport" % id)
			check((local_pet.position - local.position).distance_to(remote_pet.position - remote.position) < 0.01, "%s teleport corrections agree" % id)
			local_pet.punch()
			remote_pet.punch()
			local_pet._physics_process(1.0 / 60.0)
			remote_pet._physics_process(1.0 / 60.0)
			check(same_frame(local_pet.sprite, remote_pet.sprite), "%s punch frames agree" % id)
			local_pet.free()
			remote_pet.free()
	check(variants >= 18, "Check all species and levels")
	world.free()
	print("PET_REMOTE_MOVEMENT_PASS: ", checks, " checks, ", failures, " failures; all species/levels, both facings, movement, idle turns, teleports and punch poses")
	quit(1 if failures else 0)
