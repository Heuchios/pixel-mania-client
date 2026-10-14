extends RefCounted

# Asset preparation is only the first part of entering a playable world.
const INITIAL_PROGRESS := 8.0
const PRELOAD_COMPLETE_PROGRESS := 30.0
const PENDING_WORLD_META := &"lobby_loading_world"


static func begin(overlay: Node, canvas: Node, world_name: String) -> void:
	if overlay == null or canvas == null:
		return
	overlay.set_meta(PENDING_WORLD_META, world_name.strip_edges().to_upper())
	refresh_version(canvas)
	write_progress(canvas, INITIAL_PROGRESS)
	var root := canvas.get_node_or_null("Root") as Control
	if root != null:
		root.scale = Vector2.ONE


static func update_preload(overlay: Node, canvas: Node, progress_ratio: float) -> void:
	# A stale lobby callback must not overwrite the world loader after handoff.
	if overlay == null or canvas == null or not overlay.has_meta(PENDING_WORLD_META):
		return
	var bar := canvas.find_child("ProgressBar", true, false) as Range
	var previous := bar.value if bar != null else INITIAL_PROGRESS
	var progress := lerpf(INITIAL_PROGRESS, PRELOAD_COMPLETE_PROGRESS, clampf(progress_ratio, 0.0, 1.0))
	write_progress(canvas, maxf(previous, progress))


static func peek_progress(overlay: Node, canvas: Node) -> float:
	if overlay == null or canvas == null or not overlay.has_meta(PENDING_WORLD_META):
		return INITIAL_PROGRESS
	var bar := canvas.find_child("ProgressBar", true, false) as Range
	return clampf(bar.value, INITIAL_PROGRESS, PRELOAD_COMPLETE_PROGRESS) if bar != null else INITIAL_PROGRESS


static func take_progress(overlay: Node, canvas: Node, world_name: String) -> float:
	if overlay == null or canvas == null:
		return INITIAL_PROGRESS
	var matches := str(overlay.get_meta(PENDING_WORLD_META, "")) == world_name.strip_edges().to_upper()
	var progress := peek_progress(overlay, canvas) if matches else INITIAL_PROGRESS
	if overlay.has_meta(PENDING_WORLD_META):
		overlay.remove_meta(PENDING_WORLD_META)
	return progress


static func write_progress(canvas: Node, progress: float) -> void:
	var bar := canvas.find_child("ProgressBar", true, false) as Range
	if bar != null:
		bar.value = progress
	var label := canvas.find_child("ProgressPercent", true, false) as Label
	if label != null:
		label.text = str(roundi(progress)) + "%"


static func refresh_version(canvas: Node, network_source: Object = null) -> void:
	if not is_instance_valid(canvas):
		return
	var label := canvas.find_child("Version", true, false) as Label
	if label == null:
		return
	var network := network_source
	if network == null and canvas.is_inside_tree():
		network = canvas.get_tree().root.get_node_or_null("NetworkManager")
	var version := ""
	if is_instance_valid(network) and network.has_method("get_client_version"):
		version = str(network.call("get_client_version")).strip_edges()
	# Never display an obsolete template version when no build source exists.
	label.text = "Alpha-" + version if version != "" else ""
	label.visible = version != ""
