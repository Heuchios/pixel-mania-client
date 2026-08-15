extends SceneTree

const FIRE_PROJECTILE_SCENE := preload("res://Scenes/particles/FireProjectileFX.tscn")
const FIRE_TEXTURE_PATH := "res://Assets/effects/fire.png"
const BLAST_TEXTURE_PATH := "res://Assets/effects/blast.png"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var effect := FIRE_PROJECTILE_SCENE.instantiate()
	root.add_child(effect)
	await process_frame

	if not effect.has_method("start"):
		fail_test("FireProjectileFX is missing start().")
		return
	if not effect.has_method("stop"):
		fail_test("FireProjectileFX is missing stop().")
		return
	if not effect.has_method("play_once"):
		fail_test("FireProjectileFX is missing play_once().")
		return
	if not effect.has_method("fire_once"):
		fail_test("FireProjectileFX is missing fire_once().")
		return
	if not effect.has_method("launch_to"):
		fail_test("FireProjectileFX is missing launch_to().")
		return
	if not effect.has_method("trigger_impact_burst"):
		fail_test("FireProjectileFX is missing trigger_impact_burst().")
		return

	var projectile := effect.get_node_or_null("Projectile") as Node2D
	if projectile == null:
		fail_test("Editable Projectile node is missing.")
		return
	if float(effect.get("projectile_scale")) > 1.2:
		fail_test("Default projectile scale should stay compact for in-game use.")
		return
	if projectile.scale.x > 1.2 or projectile.scale.y > 1.2:
		fail_test("Editable Projectile node starts too large.")
		return

	var fire_head := effect.get_node_or_null("Projectile/FireHead") as Sprite2D
	if fire_head == null:
		fail_test("Editable FireHead sprite is missing.")
		return
	if fire_head.texture == null or fire_head.texture.resource_path != FIRE_TEXTURE_PATH:
		fail_test("FireHead does not use the fire.png texture.")
		return

	if effect.get_node_or_null("Projectile/FireHeadGlow") == null:
		fail_test("Editable FireHeadGlow sprite is missing.")
		return
	var preview_path := effect.get_node_or_null("PreviewPath") as Line2D
	if preview_path == null:
		fail_test("Editable PreviewPath line is missing.")
		return
	if preview_path.visible:
		fail_test("PreviewPath should be hidden during runtime/headless scene use.")
		return
	if effect.get_node_or_null("ImpactBurst") == null:
		fail_test("Editable ImpactBurst node is missing.")
		return
	var impact_burst := effect.get_node("ImpactBurst") as Node2D
	if float(effect.get("impact_scale_multiplier")) > 0.65:
		fail_test("Impact scale multiplier should stay compact for in-game use.")
		return
	if impact_burst.scale.x > 0.7 or impact_burst.scale.y > 0.7:
		fail_test("ImpactBurst starts too large.")
		return

	var fire_emitter_paths := [
		"Projectile/FlameTrail",
		"Projectile/EmberTrail",
		"Projectile/SmokeTrail",
	]
	for emitter_path in fire_emitter_paths:
		var emitter := effect.get_node_or_null(emitter_path) as GPUParticles2D
		if emitter == null:
			fail_test("Editable particle emitter is missing: " + emitter_path)
			return
		if emitter.texture == null or emitter.texture.resource_path != FIRE_TEXTURE_PATH:
			fail_test("Emitter does not use fire.png: " + emitter_path)
			return
		if emitter.process_material == null:
			fail_test("Emitter is missing a customizable process material: " + emitter_path)
			return

	var blast_emitter_paths := [
		"ImpactBurst/ImpactFlash",
		"ImpactBurst/ImpactEmbers",
	]
	for emitter_path in blast_emitter_paths:
		var emitter := effect.get_node_or_null(emitter_path) as GPUParticles2D
		if emitter == null:
			fail_test("Editable impact emitter is missing: " + emitter_path)
			return
		if emitter.texture == null or emitter.texture.resource_path != BLAST_TEXTURE_PATH:
			fail_test("Impact emitter does not use blast.png: " + emitter_path)
			return
		if emitter.process_material == null:
			fail_test("Impact emitter is missing a customizable process material: " + emitter_path)
			return
		if emitter.visibility_rect.size.x > 90.0 or emitter.visibility_rect.size.y > 90.0:
			fail_test("Impact emitter visibility area is too large: " + emitter_path)
			return

	effect.set_projectile_scale(1.7)
	await process_frame
	if not projectile.scale.is_equal_approx(Vector2(1.7, 1.7)):
		fail_test("set_projectile_scale() did not update the editable projectile node.")
		return
	if impact_burst.scale.x >= projectile.scale.x or impact_burst.scale.y >= projectile.scale.y:
		fail_test("ImpactBurst should stay smaller than the projectile scale.")
		return

	effect.set_direction(Vector2.UP)
	await process_frame
	if not is_equal_approx(effect.rotation, Vector2.UP.angle()):
		fail_test("set_direction() did not rotate the effect root.")
		return

	effect.launch_to(Vector2(32.0, 48.0), Vector2(132.0, 48.0), 500.0)
	if not effect.global_position.is_equal_approx(Vector2(32.0, 48.0)):
		fail_test("launch_to() did not place the effect at the requested start.")
		return
	if not is_equal_approx(effect.rotation, 0.0):
		fail_test("launch_to() did not face the requested target.")
		return

	effect.start()
	await process_frame
	var flame_trail := effect.get_node("Projectile/FlameTrail") as GPUParticles2D
	if not flame_trail.emitting:
		fail_test("start() did not enable trail emission.")
		return

	effect.trigger_impact_burst()
	await process_frame
	var impact_flash := effect.get_node("ImpactBurst/ImpactFlash") as GPUParticles2D
	if not impact_flash.emitting:
		fail_test("trigger_impact_burst() did not enable the impact flash.")
		return

	effect.stop()
	await process_frame
	if flame_trail.emitting:
		fail_test("stop() did not disable trail emission.")
		return

	effect.free()
	print("[fire-projectile-fx] success")
	quit(0)


func fail_test(message: String) -> void:
	push_error("[fire-projectile-fx] " + message)
	quit(1)
