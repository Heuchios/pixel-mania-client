extends SceneTree

const WIZARD_PROJECTILE_SCENE := preload("res://Scenes/particles/WizardProjectileFX.tscn")
const WIZARD_FIRE_TEXTURE_PATH := "res://Assets/effects/wizard_fire.png"
const WIZARD_BLAST_TEXTURE_PATH := "res://Assets/effects/wizard_blast.png"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var effect := WIZARD_PROJECTILE_SCENE.instantiate()
	root.add_child(effect)
	await process_frame

	if effect == null:
		fail_test("Could not instantiate WizardProjectileFX.")
		return
	if not effect.has_method("launch_to"):
		fail_test("WizardProjectileFX is missing launch_to().")
		return
	if not effect.has_method("trigger_impact_burst"):
		fail_test("WizardProjectileFX is missing trigger_impact_burst().")
		return

	var projectile := effect.get_node_or_null("Projectile") as Node2D
	if projectile == null:
		fail_test("Editable Projectile node is missing.")
		return
	if float(effect.get("projectile_scale")) > 1.2:
		fail_test("Default wizard projectile scale should stay compact for in-game use.")
		return
	if projectile.scale.x > 1.2 or projectile.scale.y > 1.2:
		fail_test("Editable wizard Projectile node starts too large.")
		return

	var fire_head := effect.get_node_or_null("Projectile/FireHead") as Sprite2D
	if fire_head == null:
		fail_test("Editable wizard FireHead sprite is missing.")
		return
	if fire_head.texture == null or fire_head.texture.resource_path != WIZARD_FIRE_TEXTURE_PATH:
		fail_test("Wizard FireHead does not use wizard_fire.png.")
		return

	var fire_head_glow := effect.get_node_or_null("Projectile/FireHeadGlow") as Sprite2D
	if fire_head_glow == null:
		fail_test("Editable wizard FireHeadGlow sprite is missing.")
		return
	var glow_modulate := fire_head_glow.modulate
	if glow_modulate.b <= glow_modulate.g or glow_modulate.r <= glow_modulate.g:
		fail_test("Wizard FireHeadGlow should be visibly purple.")
		return

	var impact_burst := effect.get_node_or_null("ImpactBurst") as Node2D
	if impact_burst == null:
		fail_test("Editable ImpactBurst node is missing.")
		return
	if float(effect.get("impact_scale_multiplier")) > 0.65:
		fail_test("Wizard impact scale multiplier should stay compact for in-game use.")
		return
	if impact_burst.scale.x > 0.7 or impact_burst.scale.y > 0.7:
		fail_test("Wizard ImpactBurst starts too large.")
		return

	var projectile_emitter_paths := [
		"Projectile/FlameTrail",
		"Projectile/EmberTrail",
		"Projectile/SmokeTrail",
	]
	for emitter_path in projectile_emitter_paths:
		var emitter := effect.get_node_or_null(emitter_path) as GPUParticles2D
		if emitter == null:
			fail_test("Editable wizard particle emitter is missing: " + emitter_path)
			return
		if emitter.texture == null or emitter.texture.resource_path != WIZARD_FIRE_TEXTURE_PATH:
			fail_test("Wizard emitter does not use wizard_fire.png: " + emitter_path)
			return
		if emitter.process_material == null:
			fail_test("Wizard emitter is missing a customizable process material: " + emitter_path)
			return

	var impact_emitter_paths := [
		"ImpactBurst/ImpactFlash",
		"ImpactBurst/ImpactEmbers",
	]
	for emitter_path in impact_emitter_paths:
		var emitter := effect.get_node_or_null(emitter_path) as GPUParticles2D
		if emitter == null:
			fail_test("Editable wizard impact emitter is missing: " + emitter_path)
			return
		if emitter.texture == null or emitter.texture.resource_path != WIZARD_BLAST_TEXTURE_PATH:
			fail_test("Wizard impact emitter does not use wizard_blast.png: " + emitter_path)
			return
		if emitter.process_material == null:
			fail_test("Wizard impact emitter is missing a customizable process material: " + emitter_path)
			return
		if emitter.visibility_rect.size.x > 90.0 or emitter.visibility_rect.size.y > 90.0:
			fail_test("Wizard impact emitter visibility area is too large: " + emitter_path)
			return

	effect.launch_to(Vector2(32.0, 48.0), Vector2(132.0, 48.0), 500.0)
	if not effect.global_position.is_equal_approx(Vector2(32.0, 48.0)):
		fail_test("launch_to() did not place the wizard effect at the requested start.")
		return
	if not is_equal_approx(effect.rotation, 0.0):
		fail_test("launch_to() did not face the requested target.")
		return

	effect.trigger_impact_burst()
	await process_frame
	var impact_flash := effect.get_node("ImpactBurst/ImpactFlash") as GPUParticles2D
	if not impact_flash.emitting:
		fail_test("trigger_impact_burst() did not enable the wizard impact flash.")
		return

	effect.free()
	print("[wizard-projectile-fx] success")
	quit(0)


func fail_test(message: String) -> void:
	push_error("[wizard-projectile-fx] " + message)
	quit(1)
