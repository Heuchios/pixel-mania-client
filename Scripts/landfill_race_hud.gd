extends Control

# Landfill seasonal event: the top-left competitor panel shown for the whole race lifecycle
# (waiting -> countdown -> racing -> results).
#
# Built entirely in code (no .tscn) and styled through PixelUIStyle, matching
# Scripts/landfill_waiting_room_ui.gd and Scripts/landfill_ui.gd. Self-contained in the same way:
# world.gd sets it up once, eagerly, in _ready() and then never touches it again -- it shows and
# hides itself purely from NetworkManager state as the player moves between Landfill and
# non-Landfill worlds. See setup_landfill_race_hud() in world.gd.
#
# THE PANEL IS A PURE RENDERER. Every value it shows -- phase, competitor list, ordering,
# placement, kilograms -- arrives already decided in a landfill_race_state packet from the server.
# It never computes a ranking, never decides that a race started or ended, and never reports a
# player's progress upward. Progress is derived server-side from validated block breaks (see
# awardKilogramsForBlockBreak in server_landfill_event.ts); there is deliberately no client->server
# message in this feature that carries progress, placement or race phase, because any such message
# would be a thing a modified client could lie about.
#
# The one thing computed locally is the displayed clock, and only because polling the server every
# frame for a number it already told us would be wasteful. The server sends absolute deadlines
# (countdown_ends_at_ms, race_ends_at_ms) plus its own server_time_ms; we take the offset between
# that and our local clock ONCE per packet and render the remaining time against it. So every
# client counts down to the same server instant rather than each counting independently from
# whenever its packet happened to land, and a dropped packet costs smoothness, never correctness --
# the server alone decides when the race actually ends.

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")

const LANDFILL_WORLD_PREFIX := "landfill_"
const POLL_INTERVAL_SEC := 0.5
# How long the results stay on screen before players are returned to the lobby. Kept comfortably
# under the server's own LANDFILL_RESULTS_DISPLAY_SECONDS (default 12) so the client leaves under
# its own steam BEFORE the server retires the session and destroys the world underneath it --
# being teleported out of a world that is being deleted is exactly how you get a stuck loading
# screen.
const RESULTS_DISPLAY_SECONDS := 8.0
const PANEL_W: float = 300.0
const HEADER_H: float = 34.0
const ROW_H: float = 24.0
const PANEL_MARGIN: float = 18.0
const MAX_VISIBLE_ROWS := 8

var panel: Panel = null
var title_label: Label = null
var timer_label: Label = null
var status_label: Label = null
var rows_root: VBoxContainer = null

var host: Node = null
var is_signals_connected: bool = false
var tracked_world_name: String = ""
var poll_accum: float = 0.0

# Latest server snapshot.
var race_state: String = ""
var competitors: Array = []
var min_players_to_start: int = 2
var connected_players: int = 0
var countdown_ends_at_ms: int = 0
var race_ends_at_ms: int = 0
# server_time_ms minus our local clock at the moment the packet arrived. Added to our clock to
# estimate "what time is it on the server right now", so the deadlines above stay meaningful.
var server_clock_offset_ms: int = 0
var has_state: bool = false
# Local deadline for the post-race return to lobby. 0 = not scheduled. Checked from _process
# rather than an awaited timer so it cannot fire against a freed node, and so leaving the world
# early simply cancels it.
var return_to_lobby_at_ms: int = 0
var return_to_lobby_started: bool = false


func setup(_host = null) -> void:
	host = _host
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Sits above the waiting-room panel (120) and well below every modal (145+), so it never
	# covers a dialog the player opened. See the z_index registry in the other UI scripts.
	z_index = 130
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
	var state_callback := Callable(self, "_on_landfill_race_state_received")
	if network.has_signal("landfill_race_state_received") and not network.is_connected("landfill_race_state_received", state_callback):
		network.connect("landfill_race_state_received", state_callback)
	var results_callback := Callable(self, "_on_landfill_race_results_received")
	if network.has_signal("landfill_race_results_received") and not network.is_connected("landfill_race_results_received", results_callback):
		network.connect("landfill_race_results_received", results_callback)
	is_signals_connected = true


func build_panel() -> void:
	for child in get_children():
		child.queue_free()

	panel = Panel.new()
	panel.name = "RacePanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size = Vector2(PANEL_W, HEADER_H + ROW_H * 3.0 + 16.0)
	panel.add_theme_stylebox_override(
		"panel",
		PixelUIStyle.style_box(PixelUIStyle.GLASS_PANEL_STRONG, PixelUIStyle.GLASS_BORDER_BRIGHT, 3, 14, 6)
	)
	add_child(panel)

	title_label = Label.new()
	title_label.name = "Title"
	title_label.text = "LANDFILL RACE"
	title_label.position = Vector2(12.0, 6.0)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(title_label, 16, PixelUIStyle.GOLD_SOFT)
	panel.add_child(title_label)

	timer_label = Label.new()
	timer_label.name = "Timer"
	timer_label.text = ""
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(timer_label, 16)
	panel.add_child(timer_label)

	status_label = Label.new()
	status_label.name = "Status"
	status_label.text = ""
	status_label.position = Vector2(12.0, HEADER_H - 4.0)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(status_label, 13)
	panel.add_child(status_label)

	rows_root = VBoxContainer.new()
	rows_root.name = "Rows"
	rows_root.position = Vector2(12.0, HEADER_H + 14.0)
	rows_root.custom_minimum_size = Vector2(PANEL_W - 24.0, 0.0)
	rows_root.add_theme_constant_override("separation", 2)
	rows_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(rows_root)

	_update_position()


func _make_row(text_left: String, text_right: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(PANEL_W - 24.0, ROW_H)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var name_label := Label.new()
	name_label.text = text_left
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.clip_text = true
	PixelUIStyle.apply_label_shadow(name_label, 14)
	row.add_child(name_label)

	var value_label := Label.new()
	value_label.text = text_right
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size = Vector2(74.0, ROW_H)
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(value_label, 14, PixelUIStyle.ACCENT_CYAN)
	row.add_child(value_label)

	return row


func _update_position() -> void:
	if panel == null or not is_instance_valid(panel):
		return
	# Top-left, matching the game's existing corner convention (see InventoryLabel in main.tscn).
	panel.position = Vector2(PANEL_MARGIN, PANEL_MARGIN)
	if timer_label != null and is_instance_valid(timer_label):
		timer_label.position = Vector2(PANEL_W - 96.0, 6.0)
		timer_label.custom_minimum_size = Vector2(84.0, 20.0)
		timer_label.size = Vector2(84.0, 20.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_position()


func _process(delta: float) -> void:
	poll_accum += delta
	if poll_accum >= POLL_INTERVAL_SEC:
		poll_accum = 0.0
		_refresh_from_current_world()
	if visible:
		# Only the two text labels are re-rendered per frame; the competitor rows are rebuilt
		# solely when a packet actually changes them (see _rebuild_rows), so this is not a
		# per-frame HUD rebuild.
		_update_timer_text()
		_update_status_text()
	_check_return_to_lobby()


# Once the results have been on screen long enough, take the player back to the lobby. Driven from
# the client because only the client knows when its own results display has been seen; the server
# independently retires the session shortly after, so the two do not need to agree precisely.
func _check_return_to_lobby() -> void:
	if return_to_lobby_at_ms <= 0 or return_to_lobby_started:
		return
	if Time.get_ticks_msec() < return_to_lobby_at_ms:
		return
	return_to_lobby_started = true
	return_to_lobby_at_ms = 0
	if host != null and is_instance_valid(host) and host.has_method("return_to_lobby_from_landfill_race"):
		host.return_to_lobby_from_landfill_race()


func _is_landfill_world_name(world_name: String) -> bool:
	return world_name.to_lower().begins_with(LANDFILL_WORLD_PREFIX)


func _refresh_from_current_world() -> void:
	var network = get_node_or_null("/root/NetworkManager")
	if network == null:
		visible = false
		return

	var world_name: String = str(network.get("current_world_name")) if "current_world_name" in network else ""
	if not _is_landfill_world_name(world_name):
		# Left the event. Drop the snapshot so re-entering a DIFFERENT race can never briefly show
		# the previous race's competitors before its first packet arrives.
		if tracked_world_name != "":
			_clear_state()
		visible = false
		tracked_world_name = ""
		return

	if world_name != tracked_world_name:
		_clear_state()
		tracked_world_name = world_name
		# Ask for the current phase immediately rather than waiting for the next broadcast tick,
		# so the panel is populated the moment the world finishes loading.
		if network.has_method("request_landfill_race_state"):
			network.request_landfill_race_state()

	visible = has_state


func _clear_state() -> void:
	race_state = ""
	competitors = []
	countdown_ends_at_ms = 0
	race_ends_at_ms = 0
	connected_players = 0
	has_state = false
	# Leaving the world cancels any pending auto-return, so a player who walks out early is never
	# yanked back to the lobby from wherever they went next.
	return_to_lobby_at_ms = 0
	return_to_lobby_started = false
	if rows_root != null and is_instance_valid(rows_root):
		for child in rows_root.get_children():
			child.queue_free()


func _server_now_ms() -> int:
	return Time.get_ticks_msec() + server_clock_offset_ms


func _format_clock(remaining_ms: int) -> String:
	@warning_ignore("integer_division")
	var total_seconds: int = int(max(0, remaining_ms)) / 1000
	@warning_ignore("integer_division")
	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]


# Top-right of the panel header. The race clock only -- the countdown reads better as a sentence
# in the status line than as a bare number floating next to the title.
func _update_timer_text() -> void:
	if timer_label == null or not is_instance_valid(timer_label):
		return
	if race_state == "racing" and race_ends_at_ms > 0:
		timer_label.text = _format_clock(race_ends_at_ms - _server_now_ms())
	else:
		timer_label.text = ""


func _countdown_seconds_left() -> int:
	if countdown_ends_at_ms <= 0:
		return 0
	var remaining: int = int(max(0, countdown_ends_at_ms - _server_now_ms()))
	# Ceil so the last number shown is "1" rather than a flash of "0" before GO.
	return int(ceil(float(remaining) / 1000.0))


func _update_status_text() -> void:
	if status_label == null or not is_instance_valid(status_label):
		return
	status_label.text = _status_text_for_state()


func _status_text_for_state() -> String:
	match race_state:
		"waiting_for_players":
			return "Waiting for players... %d / %d" % [connected_players, min_players_to_start]
		"countdown":
			var seconds_left := _countdown_seconds_left()
			return "GO!" if seconds_left <= 0 else "Starting in %d..." % seconds_left
		"racing":
			return ""
		"finishing", "finished":
			return "RACE COMPLETE"
		_:
			return ""


func _rebuild_rows() -> void:
	if rows_root == null or not is_instance_valid(rows_root):
		return
	for child in rows_root.get_children():
		child.queue_free()

	var shown := 0
	for entry in competitors:
		if shown >= MAX_VISIBLE_ROWS:
			break
		if not (entry is Dictionary):
			continue
		var display_name: String = str(entry.get("display_name", entry.get("username", "")))
		var kilograms: int = int(entry.get("kilograms", 0))
		var placement: int = int(entry.get("placement", shown + 1))
		var is_player_connected: bool = bool(entry.get("connected", true))

		var left_text: String = ""
		var right_text: String = ""
		if race_state == "waiting_for_players":
			# No ranking before the race: showing "1." while everyone is on zero implies a standing
			# that does not exist yet.
			left_text = display_name
			right_text = "READY"
		else:
			left_text = "%d. %s" % [placement, display_name]
			right_text = "%d kg" % kilograms
		if not is_player_connected:
			right_text = "DNF"

		rows_root.add_child(_make_row(left_text, right_text))
		shown += 1

	var row_count: float = float(max(1, shown))
	if panel != null and is_instance_valid(panel):
		panel.size = Vector2(PANEL_W, HEADER_H + 18.0 + ROW_H * row_count + 10.0)
	_update_position()


func _on_landfill_race_state_received(data: Dictionary) -> void:
	var world: String = str(data.get("world", ""))
	# Ignore anything for a world we are not standing in. Without this a packet still in flight
	# from a previous race could repopulate the panel after the player has already moved on.
	if tracked_world_name != "" and world != "" and world.to_lower() != tracked_world_name.to_lower():
		return

	var server_time_ms: int = int(data.get("server_time_ms", 0))
	if server_time_ms > 0:
		server_clock_offset_ms = server_time_ms - Time.get_ticks_msec()

	var previous_state := race_state
	var previous_competitors := competitors

	race_state = str(data.get("state", ""))
	competitors = data.get("competitors", []) if data.get("competitors", []) is Array else []
	min_players_to_start = int(data.get("min_players_to_start", min_players_to_start))
	connected_players = int(data.get("connected_players", 0))
	countdown_ends_at_ms = int(data.get("countdown_ends_at_ms", 0))
	race_ends_at_ms = int(data.get("race_ends_at_ms", 0))
	has_state = true

	if status_label != null and is_instance_valid(status_label):
		status_label.text = _status_text_for_state()

	# Rebuild rows only when the roster actually changed, not on every packet.
	if previous_state != race_state or _competitors_changed(previous_competitors, competitors):
		_rebuild_rows()

	visible = true
	_update_timer_text()


func _competitors_changed(previous: Array, current: Array) -> bool:
	if previous.size() != current.size():
		return true
	for i in range(current.size()):
		var a = previous[i]
		var b = current[i]
		if not (a is Dictionary) or not (b is Dictionary):
			return true
		if str(a.get("username", "")) != str(b.get("username", "")):
			return true
		if int(a.get("kilograms", 0)) != int(b.get("kilograms", 0)):
			return true
		if bool(a.get("connected", true)) != bool(b.get("connected", true)):
			return true
	return false


func _on_landfill_race_results_received(data: Dictionary) -> void:
	var world: String = str(data.get("world", ""))
	if tracked_world_name != "" and world != "" and world.to_lower() != tracked_world_name.to_lower():
		return
	var results = data.get("results", [])
	if not (results is Array):
		return

	race_state = "finished"
	competitors = results
	has_state = true
	_update_status_text()
	_rebuild_rows()

	# Schedule the return to lobby. Guarded so a duplicate results packet cannot restart the
	# countdown or double-trigger the scene change.
	if not return_to_lobby_started and return_to_lobby_at_ms <= 0:
		return_to_lobby_at_ms = Time.get_ticks_msec() + int(RESULTS_DISPLAY_SECONDS * 1000.0)

	# Surface the awarded Kilograms for THIS player through the normal notification channel rather
	# than inventing a second results surface. host is world.gd.
	var network = get_node_or_null("/root/NetworkManager")
	var my_username: String = ""
	if network != null and network.has_method("get_active_session_username"):
		my_username = str(network.get_active_session_username()).to_lower()
	if my_username == "":
		return
	for entry in results:
		if not (entry is Dictionary):
			continue
		if str(entry.get("username", "")).to_lower() != my_username:
			continue
		var placement: int = int(entry.get("placement", 0))
		var awarded: int = int(entry.get("awarded_kilograms", 0))
		var message := "Race complete - placed #%d, +%d kg" % [placement, awarded]
		if host != null and is_instance_valid(host) and host.has_method("show_notification"):
			host.show_notification(message)
		break
