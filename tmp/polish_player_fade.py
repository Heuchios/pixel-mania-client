from pathlib import Path
p=Path('Scripts/player_world_fade_fx.gd');t=p.read_text();t=t.replace('enter_duration := 0.46','enter_duration := 0.44').replace('exit_duration := 0.36','exit_duration := 0.34').replace('enter_glow_alpha := 0.72','enter_glow_alpha := 0.28').replace('exit_glow_alpha := 0.58','exit_glow_alpha := 0.22')
t=t.replace('var final_alpha := 1.0','var final_alpha := 1.0\nvar finished := false\nconst BASE_ALPHA_META := &"world_fade_base_alpha"')
t=t.replace('final_alpha = get_target_alpha(1.0)','final_alpha = _remember_alpha()')
t=t.replace('_set_glow_alpha(enter_glow_alpha)','_set_glow_alpha(0.0)').replace('_set_glow_alpha(exit_glow_alpha * 0.55)','_set_glow_alpha(0.0)')
t=t.replace('restart_particles()\n\tplay_fade("enter"','restart_particles("enter")\n\tplay_fade("enter"').replace('restart_particles()\n\tplay_fade("exit"','restart_particles("exit")\n\tplay_fade("exit"')
t=t.replace('active_tween = create_tween()','finished = false\n\tactive_tween = create_tween()')
t=t.replace('.set_ease(Tween.EASE_OUT)','.set_ease(Tween.EASE_IN_OUT)')
t=t.replace('active_tween.tween_method(Callable(self, "_set_glow_alpha"), from_glow, to_glow, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)','active_tween.tween_method(func(progress: float): _set_glow_alpha(lerpf(0.0, from_glow, sin(progress * PI)) + to_glow), 0.0, 1.0, duration)')
a=t.index('func restart_particles()');b=t.index('\n\nfunc get_target_alpha',a)
t=t[:a]+'''func restart_particles(mode: String) -> void:
	for child in find_children("*", "GPUParticles2D", true, false):
		child.emitting = false
		child.visible = child.name == ("EnterMotes" if mode == "enter" else "ExitMotes")
		if child.visible:
			child.restart()
			child.emitting = true


func _remember_alpha() -> float:
	if not is_instance_valid(target_visual):
		return 1.0
	if not target_visual.has_meta(BASE_ALPHA_META):
		target_visual.set_meta(BASE_ALPHA_META, get_target_alpha(1.0))
	return float(target_visual.get_meta(BASE_ALPHA_META))


func cancel() -> void:
	if active_tween != null:
		active_tween.kill()
	_set_target_alpha(final_alpha)
	_set_glow_alpha(0.0)
	if is_instance_valid(target_visual):
		target_visual.remove_meta(BASE_ALPHA_META)
	finished = true


func _exit_tree() -> void:
	if not finished:
		cancel()
''' +t[b:]
t=t.replace('func _on_fade_tween_finished(mode: String) -> void:\n','func _on_fade_tween_finished(mode: String) -> void:\n\tfinished = true\n\t_set_glow_alpha(0.0)\n\tif is_instance_valid(target_visual):\n\t\ttarget_visual.remove_meta(BASE_ALPHA_META)\n')
p.write_text(t)
p=Path('Scripts/player_manager.gd');t=p.read_text();a=t.index('func spawn_player_world_fade_fx');b=t.index('func get_player_world_fade_target',a);chunk=t[a:b].replace('existing.queue_free()','if existing.has_method("cancel"):\n\t\t\texisting.cancel()\n\t\tplayer_node.remove_child(existing)\n\t\texisting.queue_free()');p.write_text(t[:a]+chunk+t[b:])
p=Path('Scenes/particles/PlayerWorldFadeFX.tscn');t=p.read_text();marker='[sub_resource type="ParticleProcessMaterial" id="ParticleProcessMaterial_enter_motes"]';t=t.replace(marker,'''[sub_resource type="Gradient" id="Gradient_mote_fade"]
offsets = PackedFloat32Array(0, 0.18, 0.65, 1)
colors = PackedColorArray(1, 1, 1, 0, 1, 1, 1, 0.9, 1, 1, 1, 0.6, 1, 1, 1, 0)

[sub_resource type="GradientTexture1D" id="GradientTexture_mote_fade"]
gradient = SubResource("Gradient_mote_fade")

'''+marker)
t=t.replace('spread = 180.0','spread = 32.0').replace('initial_velocity_min = 18.0','initial_velocity_min = 8.0').replace('initial_velocity_max = 56.0','initial_velocity_max = 20.0').replace('initial_velocity_min = 28.0','initial_velocity_min = 12.0').replace('initial_velocity_max = 78.0','initial_velocity_max = 28.0').replace('gravity = Vector3(0, 18, 0)','gravity = Vector3(0, -4, 0)').replace('scale_min = 0.24','scale_min = 0.12').replace('scale_max = 0.64','scale_max = 0.26').replace('scale_min = 0.20','scale_min = 0.12').replace('scale_max = 0.54','scale_max = 0.24')
t=t.replace('hue_variation_min =', 'color_ramp = SubResource("GradientTexture_mote_fade")\nhue_variation_min =')
t=t.replace('amount = 28','emitting = false\namount = 14').replace('amount = 22','emitting = false\namount = 10').replace('lifetime = 0.78','lifetime = 0.32').replace('lifetime = 0.58','lifetime = 0.26').replace('explosiveness = 0.86','explosiveness = 1.0').replace('scale = Vector2(0.58, 0.66)','scale = Vector2(0.36, 0.48)')
p.write_text(t)
