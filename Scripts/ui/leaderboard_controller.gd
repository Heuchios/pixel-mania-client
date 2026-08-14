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

var claim_request_id := ""
var claim_in_progress := false
var claim_message := ""


func setup(_host = null) -> void:
	name = "LeaderboardController"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# IGNORE so the controller itself never eats clicks; the scene's own Dimmer/Root use STOP.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Above gameplay HUD and the hotbar (176) / settings (220) / recipe book (240) tiers, and
	# below the item action popup (300) -- see inventory_manager.gd's z_index ladder.
	z_index = 250
	visible = false
	_build_scene()
	_connect_network_signals()


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
	scene_instance.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scene_instance)

	# The scene is @tool and ships sample rows for editor previewing. Turn that off the moment
	# it is live so an empty/loading state never shows fake players.
	if "show_sample_data_when_empty" in scene_instance:
		scene_instance.set("show_sample_data_when_empty", false)

	if scene_instance.has_signal("close_pressed"):
		scene_instance.close_pressed.connect(_on_scene_close_pressed)
	if scene_instance.has_signal("rewards_pressed"):
		scene_instance.rewards_pressed.connect(_on_scene_rewards_pressed)
	if scene_instance.has_signal("tab_selected"):
		scene_instance.tab_selected.connect(_on_scene_tab_selected)

	_push_tabs()


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
	claim_message = ""
	selected_tab = TAB_LANDFILL
	if scene_instance.has_method("select_tab"):
		scene_instance.select_tab(selected_tab)
	_refresh_active_tab()


func close_leaderboard() -> void:
	is_open = false
	visible = false
	if scene_instance != null and is_instance_valid(scene_instance):
		scene_instance.visible = false
	closed.emit()


func is_leaderboard_open() -> bool:
	return is_open


# ============================================================
# TABS
# ============================================================

func _push_tabs() -> void:
	if scene_instance == null or not is_instance_valid(scene_instance):
		return
	if not scene_instance.has_method("set_tabs_from_dictionaries"):
		return

	var tab_dicts: Array = []
	for tab_definition in TAB_DEFINITIONS:
		tab_dicts.append({
			"label": str(tab_definition.get("label", "TAB")),
			# Deliberately NOT disabled: the player can open Weekly/Global and read the
			# coming-soon message. A disabled tab just looks broken.
			"disabled": false,
			"tooltip": "" if bool(tab_definition.get("live", false)) else "Coming soon",
		})
	scene_instance.set_tabs_from_dictionaries(tab_dicts)


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

	_set_scene_text("title_text", _tab_label(selected_tab))

	var badge := "EVENT LEADERBOARD"
	if season_key != "":
		badge = "SEASON " + season_key.to_upper()
	_set_scene_text("badge_text", badge)

	var subtitle := "Compete in the Landfill Race and earn points!"
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
		# The server's landfill payloads carry no event end timestamp (neither
		# landfill_leaderboard nor landfill_status include one), so there is nothing honest to
		# count down to yet. Shown as "--" rather than a made-up value; wire a real countdown
		# here if an ends_at field is ever added server-side.
		scene_instance.set_personal_summary(rank_text, your_kilograms, "--")


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
