extends Control

# Landfill seasonal event: small, non-blocking HUD panel shown while the player is sitting in a
# Landfill instance's entry pen, waiting for enough other players to join before the race starts.
# Built entirely in code (no .tscn), mirroring Scripts/landfill_ui.gd's construction pattern
# (Panel/Label built via .new(), styled via PixelUIStyle).
#
# Deliberately self-contained: polls NetworkManager.current_world_name directly instead of
# depending on world.gd's own world-change hooks, so world.gd only needs to set this up once,
# eagerly, in _ready() (see setup_landfill_waiting_room_ui()) and then leave it alone -- it shows
# and hides itself purely from NetworkManager state as the player moves between Landfill and
# non-Landfill worlds. Player count comes from NetworkManager's existing world_population_counts /
# world_population_changed (the server already broadcasts world_population_update on every join/
# leave of any world, Landfill instances included -- see server.ts's
# broadcastWorldPopulationUpdate, nothing new was added server-side for this). The "enough
# players" threshold comes from a one-time landfill_status_request per instance entered
# (min_players_to_start is a global constant, not per-instance, see landfill_status_received).
#
# Not a real-time countdown timer: the server locks an instance and starts the race the next time
# its poll tick runs (up to ~5s after the threshold is reached -- see
# server_landfill_event.ts's pollInstancesOnce), not on a precisely scheduled deadline. Rather
# than fabricate a fake countdown number the server can't actually promise, this shows "Enough
# players -- race starting..." once the threshold is met and then simply disappears once the
# player leaves the Landfill world, which is what actually happens the moment the gate opens and
# they move past the entry pen bounds (see getLandfillEntryPenBounds server-side).

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")
const LANDFILL_WORLD_PREFIX := "landfill_"
const STATUS_POLL_INTERVAL_SEC := 0.5
const PANEL_W: float = 380.0
const PANEL_H: float = 56.0

var panel: Panel = null
var label: Label = null

var host: Node = null
var is_signals_connected: bool = false
var tracked_world_name: String = ""
var min_players_to_start: int = 2
var status_requested_for_world: String = ""
var poll_accum: float = 0.0


func setup(_host = null) -> void:
	host = _host
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 120
	_connect_network_signals()
	build_panel()
	visible = false
	set_process(true)
	_refresh_from_current_world()


func _connect_network_signals() -> void:
	if is_signals_connected:
		return
	var network = get_node_or_null("/root/NetworkManager")
	if network == null:
		return

	var population_callback := Callable(self, "_on_world_population_changed")
	if network.has_signal("world_population_changed") and not network.is_connected("world_population_changed", population_callback):
		network.connect("world_population_changed", population_callback)

	var status_callback := Callable(self, "_on_landfill_status_received")
	if network.has_signal("landfill_status_received") and not network.is_connected("landfill_status_received", status_callback):
		network.connect("landfill_status_received", status_callback)

	is_signals_connected = true


func build_panel() -> void:
	for child in get_children():
		child.queue_free()

	panel = Panel.new()
	panel.name = "LandfillWaitingPanel"
	panel.size = Vector2(PANEL_W, PANEL_H)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", PixelUIStyle.style_box(PixelUIStyle.GLASS_PANEL_STRONG, PixelUIStyle.GLASS_BORDER_BRIGHT, 3, 14, 6))
	add_child(panel)

	label = Label.new()
	label.name = "WaitingLabel"
	label.text = "Waiting for players..."
	label.position = Vector2(0, 0)
	label.size = panel.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(label, 18)
	panel.add_child(label)

	_update_position()


func _update_position() -> void:
	if panel == null:
		return
	var screen_size: Vector2 = get_viewport_rect().size
	panel.position = Vector2((screen_size.x - panel.size.x) * 0.5, 18.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_position()


func _process(delta: float) -> void:
	poll_accum += delta
	if poll_accum < STATUS_POLL_INTERVAL_SEC:
		return
	poll_accum = 0.0
	_refresh_from_current_world()


func _is_landfill_world_name(world_name: String) -> bool:
	return world_name.to_lower().begins_with(LANDFILL_WORLD_PREFIX)


func _refresh_from_current_world() -> void:
	var network = get_node_or_null("/root/NetworkManager")
	if network == null:
		visible = false
		return

	var world_name: String = str(network.get("current_world_name")) if "current_world_name" in network else ""
	if not _is_landfill_world_name(world_name):
		visible = false
		tracked_world_name = ""
		return

	tracked_world_name = world_name

	if status_requested_for_world != tracked_world_name:
		status_requested_for_world = tracked_world_name
		if network.has_method("request_landfill_status"):
			network.request_landfill_status()

	var population: int = 0
	if "world_population_counts" in network:
		var counts = network.get("world_population_counts")
		if counts is Dictionary and counts.has(tracked_world_name):
			population = int(counts.get(tracked_world_name, 0))

	visible = true
	_update_label(population)


func _update_label(population: int) -> void:
	if label == null:
		return
	if population >= min_players_to_start:
		label.text = "Enough players - race starting..."
	else:
		label.text = "Waiting for players: %d / %d" % [population, min_players_to_start]


func _on_world_population_changed(world_counts) -> void:
	if tracked_world_name == "" or not (world_counts is Dictionary):
		return
	if not world_counts.has(tracked_world_name):
		return
	_update_label(int(world_counts.get(tracked_world_name, 0)))


func _on_landfill_status_received(data: Dictionary) -> void:
	var incoming: int = int(data.get("min_players_to_start", min_players_to_start))
	if incoming > 0:
		min_players_to_start = incoming
	if tracked_world_name == "":
		return
	var network = get_node_or_null("/root/NetworkManager")
	if network == null or not ("world_population_counts" in network):
		return
	var counts = network.get("world_population_counts")
	if counts is Dictionary and counts.has(tracked_world_name):
		_update_label(int(counts.get(tracked_world_name, 0)))
