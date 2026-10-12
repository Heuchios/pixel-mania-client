from pathlib import Path
for f in ['Scenes/main.tscn','Scenes/player/netfox_player.tscn']:
 p=Path(f);p.write_text(p.read_text().replace('[node name="PlayerVisual" type="CanvasGroup"','[node name="PlayerVisual" type="Node2D"'))
p=Path('Scripts/player_world_fade_fx.gd');t=p.read_text();t=t.replace('var finished := false','var finished := false\nvar composite: CanvasGroup\nvar hidden_target_alpha := 1.0')
t=t.replace('final_alpha = _remember_alpha()','final_alpha = _remember_alpha()\n\t_build_composite()')
t=t.replace('if target_visual is CanvasGroup:', 'if is_instance_valid(composite):\n\t\tcomposite.self_modulate = next_modulate\n\telif target_visual is CanvasGroup:')
t=t.replace('var next_modulate: Color = target_visual.self_modulate if target_visual is CanvasGroup else target_visual.modulate','var next_modulate: Color = composite.self_modulate if is_instance_valid(composite) else (target_visual.self_modulate if target_visual is CanvasGroup else target_visual.modulate)')
t=t.replace('return clampf(target_visual.self_modulate.a if target_visual is CanvasGroup else target_visual.modulate.a, 0.0, 1.0)','return composite.self_modulate.a if is_instance_valid(composite) else clampf(target_visual.self_modulate.a if target_visual is CanvasGroup else target_visual.modulate.a, 0.0, 1.0)')
t=t.replace('\t_set_target_alpha(final_alpha)\n\t_set_glow_alpha', '\t_release_composite(final_alpha)\n\t_set_target_alpha(final_alpha)\n\t_set_glow_alpha')
t=t.replace('\tfinished = true\n\t_set_glow_alpha(0.0)','\tfinished = true\n\t_release_composite(final_alpha if mode == "enter" else 0.0)\n\t_set_glow_alpha(0.0)')
t+='''

func _build_composite() -> void:
	if not target_visual is Node2D or target_visual is Sprite2D or target_visual is CanvasGroup:
		return
	if is_instance_valid(composite):
		_release_composite(final_alpha)
	# Flatten a visual-only copy in painter order. CanvasGroup cannot composite
	# descendants with nonzero Z; original outfit hierarchy stays untouched.
	composite = CanvasGroup.new()
	get_parent().add_child(composite)
	composite.transform = target_visual.transform
	composite.z_index = target_visual.z_index
	var layers: Array[Dictionary] = []
	_collect_layers(target_visual, target_visual.z_index, layers)
	layers.sort_custom(func(a, b): return a.z < b.z if a.z != b.z else a.order < b.order)
	for entry in layers:
		var source: Node2D = entry.node
		var copy: Node2D = source.duplicate(0)
		for child in copy.get_children():
			copy.remove_child(child)
			child.free()
		copy.set_script(null)
		copy.process_mode = Node.PROCESS_MODE_DISABLED
		copy.z_index = 0
		copy.z_as_relative = true
		copy.show_behind_parent = false
		composite.add_child(copy)
		copy.transform = target_visual.global_transform.affine_inverse() * source.global_transform
	target_visual.modulate.a = 0.0
	composite.self_modulate.a = final_alpha


func _collect_layers(node: Node, inherited_z: int, layers: Array[Dictionary]) -> void:
	for child in node.get_children():
		if child is CanvasItem and not child.visible:
			continue
		var depth := inherited_z
		if child is Node2D:
			depth = child.z_index + (inherited_z if child.z_as_relative else 0)
			if child is Sprite2D or child is AnimatedSprite2D or child is Polygon2D:
				layers.append({"node":child, "z":depth, "order":layers.size()})
		_collect_layers(child, depth, layers)


func _release_composite(alpha: float) -> void:
	if not is_instance_valid(composite):
		return
	composite.queue_free()
	composite.hide()
	composite = null
	if is_instance_valid(target_visual):
		target_visual.modulate.a = alpha
''';p.write_text(t)
