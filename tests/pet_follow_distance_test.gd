extends SceneTree

const Follower = preload("res://Scripts/pet_follower.gd")
const Items = preload("res://Scripts/item_database.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var actor := CharacterBody2D.new()
	root.add_child(actor)
	actor.global_position = Vector2(200, 100)
	actor.set_meta("facing", 1)
	for id in ["frog_pet", "ladybug_pet"]:
		var pet := Follower.new()
		pet.target = actor
		pet.item = Items.ITEMS[id].duplicate(true)
		root.add_child(pet)
		pet.set_physics_process(false)
		var goal := actor.global_position + Vector2(-26, -20 if id == "ladybug_pet" else 7)
		assert(pet.global_position == goal)
		# The boundary is measured from the player, including vertical/diagonal gaps.
		for offset in [Vector2(-193, 0), Vector2(193, 0), Vector2(0, 193), Vector2(136, 136)]:
			pet.global_position = actor.global_position + offset
			pet.velocity = Vector2(100, 520)
			pet.age = 0
			pet._physics_process(0)
			assert(pet.global_position.distance_to(goal) < 1)
			assert(pet.velocity == Vector2.ZERO)
		pet.global_position = actor.global_position + Vector2(-192, 0)
		pet._physics_process(0)
		assert(pet.global_position.distance_to(goal) > 10)
		actor.global_position += Vector2(300, 100)
		pet._physics_process(0)
		assert(pet.global_position.distance_to(pet.get_follow_position()) < 1)
		pet.free()
	actor.free()
	print("PET_FOLLOW_DISTANCE_PASS: closer ground/flying spawn, 6-block player radius, horizontal/vertical/diagonal recovery, boundary, player teleport and cleared velocity")
	quit()
