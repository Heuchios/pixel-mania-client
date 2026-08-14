extends Control

# Shared controller for Scenes/ui/leaderboard/LeaderboardScene.tscn.
#
# One controller, two hosts: the lobby's trophy button and the in-world `leaderboard` block
# both create one of these. It is fully self-contained -- it instances the scene, talks to
# NetworkManager directly, and owns the request/claim lifecycle -- so neither host needs to
# know anything about leaderboard data.
#
# Why it connects to NetworkManager directly rather than going through the world node (the
# handle_*(data) in-world delegation pattern friends_ui.gd uses): this panel is ALSO opened
# from the lobby, before any world node exists, and that delegation pattern silently no-ops
# outside an active world. landfill_ui.gd documents the same reasoning for the same reason;
# this follows it.
#
# LeaderboardScene.tscn is a pure presentation layer (leaderboard_scene.gd). It exposes
# set_entries_from_dictionaries() / set_tabs_from_dictionaries() / set_personal_summary() and
# emits close_pressed / rewards_pressed / tab_selected. It knows nothing about the network.

const LEADERBOARD_SCENE_PATH := "res://Scenes/ui/leaderboard/LeaderboardScene.tscn"

const TAB_LANDFILL := 0
const TAB_WEEKLY := 1
const TAB_GLOBAL := 2

# Landfill is the only leaderboard the server actually serves today
# (landfill_leaderboard_request -> entries/your_rank/your_kilograms). Weekly and Global are
# kept visible on purpose so the shape of the feature is discoverable, but they show a
# coming-soon state instead of an empty table. When server endpoints exist, give each tab a
# request function and drop it into _refresh_active_tab().
const TAB_DEFINITIONS := [
	{"label": "LANDFILL", "live": true},
	{"label": "WEEKLY", "live": false},
	{"label": "GLOBAL", "live": false},
]

signal closed

var scene_instance: Control = null
var is_open := false
var selected_tab: int = TAB_LANDFILL

var entries: Array = []
var season_key := ""
var your_kilograms := 0
var your_rank := 0

var leaderboard_request_id := ""
var leaderboard_loading := false
var leaderboard_error := ""

# Whatever LeaderboardScene.tscn was authored with, captured at build time. The live tab
# restores these rather than hardcoding strings here, so editing the title/badge/subtitle in
# the scene keeps working and the controller never silently overrides the design.
var designed_title := ""
var designed_badge := ""
var designed_subtitle := ""

var claim_request_id := ""
var claim_in_progress := false
var claim_message := ""

# Ticks the "EVENT ENDS IN" countdown while the panel is open. Only runs while is_open, so it
# costs nothing while the panel is hidden.
var countdown_timer: Timer = null


func setup(_host = null) -> void:
	name = "LeaderboardController"
	# IGNORE so the controller itself never eats clicks; the scene's own Dimmer/Root use STOP.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Above gameplay HUD and the hotbar (176) / settings (220) / recipe book (240) tiers, and
	# below the item action popup (300) -- see inventory_manager.gd's z_index ladder.
	z_index = 250
	visible = false
	_build_scene()
	_connect_network_signals()
	_fit_to_viewport()

	# Keep filling the screen when the window is resized. Without this the scene keeps its
	# old size and the centred window drifts off-centre.
	var viewport := get_viewport()
	if viewport != null:
		var fit_callable := Callable(self, "_fit_to_viewport")
		if not viewport.size_changed.is_connected(fit_callable):
			viewport.size_changed.connect(fit_callable)

	if countdown_timer == null:
		countdown_timer = Timer.new()
		countdown_timer.name = "CountdownTimer"
		countdown_timer.wait_time = 1.0
		countdown_timer.one_shot = false
		countdown_timer.autostart = false
		add_child(countdown_timer)
		countdown_timer.timeout.connect(_on_countdown_tick)


# LeaderboardScene centres its window with a CenterContainer, which centres within its OWN
# rect -- so the scene root must actually BE the size of the screen. Under world.ui_layer (a
# CanvasLayer, not a Control) that size is not inherited reliably, and a zero-sized root
# centres the 1032x688 window on (0,0): its lower-right quadrant lands in the top-left corner
# of the screen and the rest is off-screen. Setting anchors AND offsets AND an explicit size
# makes it deterministic instead of depending on how anchors resolve under a CanvasLayer.
#
# Resizing the scene root also fires its own NOTIFICATION_RESIZED, which is what drives
# leaderboard_scene.gd's _update_window_scale() -- so this is also what makes the window
# shrink to fit small viewports.
func _fit_to_viewport() -> void:
	if not is_inside_tree():
		return

	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	position = Vector2.ZERO
	size = viewport_size

	if scene_instance != null and is_instance_valid(scene_instance):
		scene_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		scene_instance.position = Vector2.ZERO
		scene_instance.size = viewport_size


func _build_scene() -> void:
	if scene_instance != null and is_instance_valid(scene_instance):
		return

	var packed: PackedScene = load(LEADERBOARD_SCENE_PATH) as PackedScene
	if packed == null:
		push_error("[Leaderboard] Could not load " + LEADERBOARD_SCENE_PATH)
		return

	var built := packed.instantiate()
	if not (built is Control):
		push_error("[Leaderboard] " + LEADERBOARD_SCENE_PATH + " root is not a Control.")
		if built != null:
			built.queue_free()
		return

	scene_instance = built as Control
	scene_instance.name = "LeaderboardScene"

	# ---- Everything in this block MUST happen before add_child() ----
	# add_child() is what runs the scene's _ready(), and _ready() is where it re-applies the
	# @export styles/content over the nodes. Setting these afterwards is too late.

	# THE reason the in-game panel didn't match the editor. leaderboard_scene.gd separates two
	# passes: apply_exported_content() fills the authored nodes with data (needed -- it is what
	# puts real players in the rows), and apply_exported_styles() repaints every panel, row and
	# label from the script's @export colors. That style pass overwrites styling hand-edited on
	# the child nodes in the editor -- e.g. it forces ChampionBadge/TrophyBack/Cup to a flat
	# orange panel -- which is why the editor (showing saved node edits) and the game (showing
	# the repaint) looked different. The scene's own editor_note says exactly this: turn these
	# off when you want direct node edits to stay untouched. So: styles OFF, content ON.
	if "apply_exported_styles_on_ready" in scene_instance:
		scene_instance.set("apply_exported_styles_on_ready", false)
	if "apply_exported_content_on_ready" in scene_instance:
		scene_instance.set("apply_exported_content_on_ready", true)

	# The scene is @tool and ships sample rows for editor previewing. Turn that off before
	# _ready() so a loading/empty state never flashes fake players.
	if "show_sample_data_when_empty" in scene_instance:
		scene_instance.set("show_sample_data_when_empty", false)

	# Capture the authored text BEFORE anything is overwritten.
	designed_title = str(scene_instance.get("title_text")) if "title_text" in scene_instance else "LANDFILL"
	designed_badge = str(scene_instance.get("badge_text")) if "badge_text" in scene_instance else "EVENT LEADERBOARD"
	designed_subtitle = str(scene_instance.get("subtitle_text")) if "subtitle_text" in scene_instance else ""

	add_child(scene_instance)
	scene_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	if scene_instance.has_signal("close_pressed"):
		scene_instance.close_pressed.connect(_on_scene_close_pressed)
	if scene_instance.has_signal("rewards_pressed"):
		scene_instance.rewards_pressed.connect(_on_scene_rewards_pressed)
	if scene_instance.has_signal("tab_selected"):
		scene_instance.tab_selected.connect(_on_scene_tab_selected)


func _connect_network_signals() -> void:
	var network := get_node_or_null("/root/NetworkManager")
	if network == null:
		return

	var leaderboard_callable := Callable(self, "_on_leaderboard_received")
	if network.has_signal("landfill_leaderboard_received") and not network.is_connected("landfill_leaderboard_received", leaderboard_callable):
		network.connect("landfill_leaderboard_received", leaderboard_callable)

	var claim_callable := Callable(self, "_on_claim_result_received")
	if network.has_signal("landfill_claim_result_received") and not network.is_connected("landfill_claim_result_received", claim_callable):
		network.connect("landfill_claim_result_received", claim_callable)


# ============================================================
# OPEN / CLOSE
# ============================================================

func open_leaderboard(_grid_pos: Vector2i = Vector2i.ZERO) -> void:
	_build_scene()
	if scene_instance == null or not is_instance_valid(scene_instance):
		return

	is_open = true
	visible = true
	scene_instance.visible = true
	# Re-fit on every open: the viewport may have been resized while this panel was hidden, and
	# a hidden Control does not always get a correct rect until it is shown. Deferred as well,
	# so the fit also runs once layout for this frame has settled.
	_fit_to_viewport()
	call_deferred("_fit_to_viewport")
	claim_message = ""
	selected_tab = TAB_LANDFILL
	if scene_instance.has_method("select_tab"):
		scene_instance.select_tab(selected_tab)
	_refresh_active_tab()

	if countdown_timer != null:
		_on_countdown_tick()
		countdown_timer.start()


func close_leaderboard() -> void:
	is_open = false
	visible = false
	if scene_instance != null and is_instance_valid(scene_instance):
		scene_instance.visible = false
	if countdown_timer != null:
		countdown_timer.stop()
	closed.emit()


func is_leaderboard_open() -> bool:
	return is_open


# ============================================================
# TABS
# ============================================================

# The tabs are NOT pushed from here. LeaderboardScene.tscn already authors TabLandfill /
# TabWeekly / TabGlobal with their own labels, icons and styling, and calling
# set_tabs_from_dictionaries() would rebuild them AND re-run apply_exported_styles()
# internally -- undoing the whole point of leaving the authored styling alone. TAB_DEFINITIONS
# below is kept purely as this controller's own live/coming-soon lookup, and its order must
# match the tab order in the scene.


func _on_scene_tab_selected(index: int, _tab_data: Resource) -> void:
	selected_tab = clampi(index, 0, TAB_DEFINITIONS.size() - 1)
	_refresh_active_tab()


func _refresh_active_tab() -> void:
	if _is_tab_live(selected_tab):
		_request_leaderboard_refresh()
	else:
		_render_coming_soon()


func _is_tab_live(index: int) -> bool:
	if index < 0 or index >= TAB_DEFINITIONS.size():
		return false
	return bool(TAB_DEFINITIONS[index].get("live", false))


func _tab_label(index: int) -> String:
	if index < 0 or index >= TAB_DEFINITIONS.size():
		return "LEADERBOARD"
	return str(TAB_DEFINITIONS[index].get("label", "LEADERBOARD"))


# ============================================================
# LANDFILL DATA
# ============================================================

func _request_leaderboard_refresh() -> void:
	var network := get_node_or_null("/root/NetworkManager")
	if network == null or not network.has_method("request_landfill_leaderboard"):
		leaderboard_loading = false
		leaderboard_error = "Leaderboard is unavailable right now."
		_render()
		return

	leaderboard_request_id = "leaderboard_" + str(Time.get_ticks_msec())
	leaderboard_loading = true
	leaderboard_error = ""
	_render()

	if not bool(network.request_landfill_leaderboard(leaderboard_request_id)):
		leaderboard_loading = false
		leaderboard_error = "Sign in to view the leaderboard."
		_render()


func _on_leaderboard_received(data: Dictionary) -> void:
	# Drop responses belonging to a superseded request, same guard landfill_ui.gd uses.
	if leaderboard_request_id != "":
		var response_request_id := str(data.get("request_id", "")).strip_edges()
		if response_request_id != "" and response_request_id != leaderboard_request_id:
			return

	leaderboard_loading = false
	leaderboard_error = ""

	entries.clear()
	var incoming = data.get("entries", [])
	if incoming is Array:
		for raw_entry in incoming:
			if raw_entry is Dictionary:
				entries.append(raw_entry.duplicate(true))

	season_key = str(data.get("season_key", season_key)).strip_edges()
	your_kilograms = int(data.get("your_kilograms", your_kilograms))
	your_rank = int(data.get("your_rank", your_rank))

	if _is_tab_live(selected_tab):
		_render()


# ============================================================
# PRIZE CLAIM
# ============================================================

func _on_scene_rewards_pressed() -> void:
	if claim_in_progress:
		return
	if not _is_tab_live(selected_tab):
		claim_message = "Rewards are only available for the Landfill event."
		_render()
		return

	var network := get_node_or_null("/root/NetworkManager")
	if network == null or not network.has_method("request_landfill_claim_prize"):
		claim_message = "Claiming is unavailable right now."
		_render()
		return

	claim_request_id = "landfill_claim_" + str(Time.get_ticks_msec())
	claim_in_progress = true
	claim_message = "Claiming your prize..."
	_render()

	if not bool(network.request_landfill_claim_prize(claim_request_id)):
		claim_in_progress = false
		claim_message = "Sign in to claim your prize."
		_render()


func _on_claim_result_received(data: Dictionary) -> void:
	if claim_request_id != "":
		var response_request_id := str(data.get("request_id", "")).strip_edges()
		if response_request_id != "" and response_request_id != claim_request_id:
			return

	claim_in_progress = false

	var claim_ok := bool(data.get("ok", false))
	var message := str(data.get("message", "")).strip_edges()
	if claim_ok:
		claim_message = message if message != "" else "Prize claimed!"
		# A successful claim can change standings/eligibility -- pull fresh rows.
		_request_leaderboard_refresh()
		return

	claim_message = message if message != "" else "Could not claim your prize."
	_render()


# ============================================================
# RENDERING
# ============================================================

func _render_coming_soon() -> void:
	if scene_instance == null or not is_instance_valid(scene_instance):
		return

	_set_scene_text("title_text", _tab_label(selected_tab))
	_set_scene_text("badge_text", "COMING SOON")
	_set_scene_text("subtitle_text", _tab_label(selected_tab).capitalize() + " leaderboards aren't live yet -- check back soon!")

	if scene_instance.has_method("set_entries_from_dictionaries"):
		scene_instance.set_entries_from_dictionaries([])
	if scene_instance.has_method("set_personal_summary"):
		scene_instance.set_personal_summary("--", 0, "--")


func _render() -> void:
	if scene_instance == null or not is_instance_valid(scene_instance):
		return

	# Keep the scene's authored header exactly as designed on the live tab -- only the subtitle
	# is borrowed, and only when there is real status to report.
	_set_scene_text("title_text", designed_title)
	_set_scene_text("badge_text", designed_badge)

	var subtitle := designed_subtitle
	if leaderboard_loading:
		subtitle = "Loading leaderboard..."
	elif leaderboard_error != "":
		subtitle = leaderboard_error
	elif claim_message != "":
		subtitle = claim_message
	elif entries.is_empty():
		subtitle = "No scores yet -- be the first to race!"
	_set_scene_text("subtitle_text", subtitle)

	if scene_instance.has_method("set_entries_from_dictionaries"):
		scene_instance.set_entries_from_dictionaries(_build_entry_dicts())

	if scene_instance.has_method("set_personal_summary"):
		var rank_text := str(your_rank) if your_rank > 0 else "--"
		scene_instance.set_personal_summary(rank_text, your_kilograms, _current_countdown_text())


# ============================================================
# COUNTDOWN
# ============================================================
#
# The server never stores an "event ends at" timestamp for the Landfill season -- see
# server_landfill_event.ts: a season is just the current calendar month in UTC
# (getSeasonKeyForDate -> "YYYY-MM", checked fresh on every request), and it rolls over the
# instant the wall clock crosses into a new UTC month. There is nothing to add server-side: the
# season_key already sent on every landfill_leaderboard_received payload IS the answer, so the
# end instant is computed from it here -- the first moment (00:00 UTC) of the following month.

func _on_countdown_tick() -> void:
	if not is_open or scene_instance == null or not is_instance_valid(scene_instance):
		return
	if not _is_tab_live(selected_tab):
		return
	if scene_instance.has_method("set_personal_summary"):
		var rank_text := str(your_rank) if your_rank > 0 else "--"
		scene_instance.set_personal_summary(rank_text, your_kilograms, _current_countdown_text())


func _current_countdown_text() -> String:
	if season_key == "":
		return "--"

	var end_seconds := _season_end_unix_seconds(season_key)
	if end_seconds <= 0:
		return "--"

	var now_seconds := int(Time.get_unix_time_from_system())
	var remaining := end_seconds - now_seconds
	if remaining <= 0:
		return "ENDING SOON"

	return _format_duration(remaining)


# season_key is always "YYYY-MM" (see getSeasonKeyForDate server-side). Returns the Unix
# timestamp, in seconds, of 00:00 UTC on the 1st of the FOLLOWING month -- i.e. the instant the
# season rolls over. Returns 0 on any unexpected shape so callers fall back to "--" instead of
# showing a bogus countdown.
func _season_end_unix_seconds(key: String) -> int:
	if key.length() != 7 or key[4] != "-":
		return 0

	var year_part := key.substr(0, 4)
	var month_part := key.substr(5, 2)
	if not year_part.is_valid_int() or not month_part.is_valid_int():
		return 0

	var year := int(year_part)
	var month := int(month_part)
	if month < 1 or month > 12:
		return 0

	var next_year := year
	var next_month := month + 1
	if next_month > 12:
		next_month = 1
		next_year += 1

	var datetime_dict := {
		"year": next_year,
		"month": next_month,
		"day": 1,
		"hour": 0,
		"minute": 0,
		"second": 0,
	}
	return int(Time.get_unix_time_from_datetime_dict(datetime_dict))


func _format_duration(total_seconds: int) -> String:
	var days := total_seconds / 86400
	var hours := (total_seconds % 86400) / 3600
	var minutes := (total_seconds % 3600) / 60
	var seconds := total_seconds % 60

	if days > 0:
		return "%dD %02dH %02dM" % [days, hours, minutes]
	if hours > 0:
		return "%dH %02dM %02dS" % [hours, minutes, seconds]
	return "%dM %02dS" % [minutes, seconds]


func _build_entry_dicts() -> Array:
	var local_name := _get_local_player_name()
	var entry_dicts: Array = []

	for raw_entry in entries:
		if not (raw_entry is Dictionary):
			continue
		var username := str(raw_entry.get("username", "")).strip_edges()
		if username == "":
			continue
		entry_dicts.append({
			"rank": int(raw_entry.get("rank", entry_dicts.size() + 1)),
			"player_name": username,
			# The server reports Landfill score as kilograms of trash; the UI column is
			# "TOTAL POINTS" and they are 1:1, so no conversion.
			"points": int(raw_entry.get("kilograms", 0)),
			"highlighted": local_name != "" and username.to_upper() == local_name.to_upper(),
		})

	return entry_dicts


func _set_scene_text(property_name: String, value: String) -> void:
	if scene_instance == null or not is_instance_valid(scene_instance):
		return
	if property_name in scene_instance:
		scene_instance.set(property_name, value)


func _get_local_player_name() -> String:
	var network := get_node_or_null("/root/NetworkManager")
	if network == null:
		return ""
	if network.has_method("get_session_username"):
		return str(network.get_session_username()).strip_edges()
	if "session_username" in network:
		return str(network.get("session_username")).strip_edges()
	return ""


func _on_scene_close_pressed() -> void:
	close_leaderboard()
