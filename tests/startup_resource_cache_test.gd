extends SceneTree

const TextureFactory = preload("res://Scripts/atlas_texture_factory.gd")
const SeedSystem = preload("res://Scripts/seed_system.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var music := load("res://Assets/sounds/login.wav") as AudioStreamWAV
	assert(music != null)
	assert(music.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Import must enable the menu loop")
	assert(music.loop_begin == 0 and music.loop_end > 0, "Loop bounds must be baked correctly")
	assert(absf(float(music.loop_end) / music.mix_rate - music.get_length()) < 0.001)
	assert(load("res://Scenes/main.tscn") is PackedScene)

	var seeds := SeedSystem.new()
	for rarity in ["common", "rare", "epic", "legendary"]:
		seeds.item_database[rarity] = {"rarity": rarity}
		var texture: Texture2D = seeds.get_tree_type_badge_slot_texture(rarity)
		assert(texture != null)
		var original_id := texture.get_instance_id()
		var retained: WeakRef = weakref(texture)
		texture = null
		assert(retained.get_ref() != null, "Warmup must retain the texture after the caller releases it")
		for repeat in range(100):
			assert(seeds.get_tree_type_badge_slot_texture(rarity).get_instance_id() == original_id)
	seeds.free()

	var first := TextureFactory.load_texture("res://Assets/seeds/seed_box.png")
	assert(first != null)
	var check_deadline: int = TextureFactory._next_wearable_manifest_check_msec
	for repeat in range(100):
		assert(TextureFactory.load_texture("res://Assets/seeds/seed_box.png") == first)
	assert(TextureFactory._next_wearable_manifest_check_msec == check_deadline,
		"Texture lookups inside the check interval must not poll the manifest again")
	# A later editor check must still work, even when the manifest is unchanged.
	TextureFactory._next_wearable_manifest_check_msec = 0
	assert(TextureFactory.load_texture("res://Assets/seeds/seed_box.png") == first)
	if OS.has_feature("editor"):
		assert(TextureFactory._next_wearable_manifest_check_msec > Time.get_ticks_msec())
	print("STARTUP_RESOURCE_CACHE_OK: baked music loop, scene load, retained rarity textures, bounded manifest checks")
	quit()
