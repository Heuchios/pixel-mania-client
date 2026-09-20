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

# Real event window, from the same landfill_status_received feed lobby_scene.gd's "Go Green!"
# card already uses -- see handle_landfill_status_result in network_manager.gd and
# getEventTiming() in server_calendar_events.ts. Replaces the old assumption that an active
# season always runs to end-of-month, which silently went wrong the moment the cron window was
# customized or the event was switched off. landfill_status_known stays false (countdown reads
# "--") until the first reply lands, so nothing is displayed as a guess.
var landfill_status_known := false
var landfill_event_active := false
var landfill_starts_at_ms := 0
var landfill_ends_at_ms := 0
var landfill_status_request_id := ""

# Whatever LeaderboardScene.tscn was authored with, captured at build time. The live tab
# restores these rather than hardcoding strings here, so editing the title/badge/subtitle in
# the scene keeps working and the controller never silently overrides the design.
var designed_title := ""
var designed_badge := ""
var designed_subtitle := ""
var designed_summary_timer_label := ""

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
	# Direct size assignment on a full-rect-anchored Control fights the anchor system (the
	# engine warns "size will be overridden after _ready()" and suggests set_deferred()).
	# Deferred is safe here: this already runs both immediately and via call_deferred from
	# open_leaderboard(), so the final size still lands before the panel is visibly seen.
	set_deferred("size", viewport_size)

	if scene_instance != null and is_instance_valid(scene_instance):
		scene_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		scene_instance.position = Vector2.ZERO
		scene_instance.set_deferred("size", viewport_size)


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

	# Use the same data-driven styling as the scene preview, including tab states
	# and typography. Content still comes exclusively from the server.
	if "apply_exported_styles_on_ready" in scene_instance:
		scene_instance.set("apply_exported_styles_on_ready", true)
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
	designed_summary_timer_label = str(scene_instance.get("summary_timer_label")) if "summary_timer_label" in scene_instance else "EVENT ENDS IN:"

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

	# Same status feed lobby_scene.gd's LandfillEventCard already listens to -- reused here rather
	# than teaching the leaderboard endpoint about scheduling too (single source of truth for
	# "is the event on, and when's the next boundary").
	var status_callable := Callable(self, "_on_landfill_status_received")
	if network.has_signal("landfill_status_received") and not network.is_connected("landfill_status_received", status_callable):
		network.connect("landfill_status_received", status_callable)


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
		_request_landfill_status_refresh()
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
# LANDFILL EVENT WINDOW (real start/end, not the old end-of-month guess)
# ============================================================

func _request_landfill_status_refresh() -> void:
	var network := get_node_or_null("/root/NetworkManager")
	if network == null or not network.has_method("request_landfill_status"):
		return

	landfill_status_request_id = "leaderboard_status_" + str(Time.get_ticks_msec())
	network.request_landfill_status(landfill_status_request_id)


func _on_landfill_status_received(data: Dictionary) -> void:
	if landfill_status_request_id != "":
		var response_request_id := str(data.get("request_id", "")).strip_edges()
		# request_landfill_status() is also polled from elsewhere (e.g. the lobby's event card) on
		# its own timer with its own/no request_id, so an empty response id is accepted same as the
		# other _received handlers in this file -- only a MISMATCHED non-empty id is a stale reply.
		if response_request_id != "" and response_request_id != landfill_status_request_id:
			return

	landfill_status_known = true
	landfill_event_active = bool(data.get("event_active", false))
	landfill_starts_at_ms = int(data.get("starts_at_ms", 0))
	landfill_ends_at_ms = int(data.get("ends_at_ms", 0))

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

	_set_scene_text("summary_timer_label", _countdown_label_text())
	if scene_instance.has_method("set_personal_summary"):
		var rank_text := str(your_rank) if your_rank > 0 else "--"
		scene_instance.set_personal_summary(rank_text, your_kilograms, _current_countdown_text())


# ============================================================
# COUNTDOWN
# ============================================================
#
# Used to assume an active season always ran to end-of-month (server sends season_key as
# "YYYY-MM" and rolls it over on the UTC month boundary) -- wrong the moment the cron window is
# customized or the event is switched off entirely, which is exactly the state that made the
# panel show "8D 07H 15M" while the lobby's join card stayed hidden: the countdown was reading
# the calendar, not the actual schedule. getEventTiming() in server_calendar_events.ts now sends
# the real next boundary (see _on_landfill_status_received above), so this reads that instead.

func _on_countdown_tick() -> void:
	if not is_open or scene_instance == null or not is_instance_valid(scene_instance):
		return
	if not _is_tab_live(selected_tab):
		return
	if scene_instance.has_method("set_personal_summary"):
		var rank_text := str(your_rank) if your_rank > 0 else "--"
		scene_instance.set_personal_summary(rank_text, your_kilograms, _current_countdown_text())


# "EVENT ENDS IN:" while live, "EVENT STARTS IN:" while waiting on the next window, and the
# scene's own authored default ("EVENT ENDS IN:") before the first status reply has landed --
# matches landfill_status_known below staying false until then, so nothing is ever asserted as a
# guess.
func _countdown_label_text() -> String:
	if not landfill_status_known:
		return designed_summary_timer_label
	return "EVENT ENDS IN:" if landfill_event_active else "EVENT STARTS IN:"


func _current_countdown_text() -> String:
	if not landfill_status_known:
		return "--"

	var target_ms := landfill_ends_at_ms if landfill_event_active else landfill_starts_at_ms
	if target_ms <= 0:
		return "--"

	var now_ms := int(Time.get_unix_time_from_system() * 1000.0)
	var remaining_ms := target_ms - now_ms
	if remaining_ms <= 0:
		return "ENDING SOON" if landfill_event_active else "STARTING SOON"

	@warning_ignore("integer_division")
	return _format_duration(remaining_ms / 1000)


func _format_duration(total_seconds: int) -> String:
	@warning_ignore("integer_division")
	var days := total_seconds / 86400
	@warning_ignore("integer_division")
	var hours := (total_seconds % 86400) / 3600
	@warning_ignore("integer_division")
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
