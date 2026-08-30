@tool
extends "res://Scripts/ui/lobby_scene_layout_controls.gd"

const PROFILE_PATH := "user://pixelmania_profile.cfg"
const PLAYER_SAVE_FOLDER := "user://players/"
const WORLD_SCENE := "res://Scenes/main.tscn"
const LOGIN_SCENE := "res://Scenes/ui/login/LoginScene.tscn"
const WORLD_LOADING_OVERLAY_SCENE_PATH := "res://Scenes/ui/WorldLoadingOverlay/WorldLoadingOverlay.tscn"
const WORLD_LOADING_OVERLAY_SCENE: PackedScene = preload(WORLD_LOADING_OVERLAY_SCENE_PATH)
const WorldScenePreloader = preload("res://Scripts/world_scene_preloader.gd")
const WORLD_LOADING_CANVAS_LAYER := 4096
const WORLD_JOIN_SCENE_CHANGE_DRAW_FRAMES := 1
const LOBBY_HUB_WORLD := "START"
const PLAYER_MAX_LEVEL := 100
const WORLD_POPULATION_REFRESH_SECONDS := 5.0
const ACTIVE_WORLD_LIST_SIDE_MARGIN := 20.0
const ACTIVE_WORLD_LIST_TOP := 108.0
const ACTIVE_WORLD_LIST_BOTTOM_MARGIN := 24.0
const ACTIVE_WORLD_ROW_HEIGHT := 72.0
const ACTIVE_WORLD_ROW_SEPARATION := 10

# The four buttons down the left of the lobby filter the world list. They shipped in
# LobbyScene.tscn with no [connection] entries and no references in this script, so they
# latched (toggle_mode is on) and did nothing. WORLD OF THE MONTH is deliberately still not
# wired -- nothing decides what that world would be yet.
const WORLD_FILTER_ACTIVE := "active"
const WORLD_FILTER_FAVORITES := "favorites"
const WORLD_FILTER_RECENT := "recent"
const WORLD_FILTER_MINE := "mine"
const WORLD_FILTER_BUTTON_PATHS := {
	WORLD_FILTER_FAVORITES: "LeftButtons/FavoritesButton",
	WORLD_FILTER_RECENT: "LeftButtons/RecentButton",
	WORLD_FILTER_MINE: "LeftButtons/MyWorldsButton",
}
const WORLD_FILTER_TITLES := {
	WORLD_FILTER_ACTIVE: "ACTIVE WORLDS",
	WORLD_FILTER_FAVORITES: "FAVORITE WORLDS",
	WORLD_FILTER_RECENT: "RECENTLY JOINED",
	WORLD_FILTER_MINE: "MY WORLDS",
}
const WORLD_FILTER_EMPTY_TEXT := {
	WORLD_FILTER_ACTIVE: "NO ACTIVE WORLDS RIGHT NOW",
	WORLD_FILTER_FAVORITES: "NO FAVORITES YET - TAP THE HEART ON A WORLD",
	WORLD_FILTER_RECENT: "NO WORLDS JOINED YET",
	WORLD_FILTER_MINE: "YOU DO NOT OWN A LOCKED WORLD YET",
}
const WORLD_FILTER_ROW_BADGES := {
	WORLD_FILTER_FAVORITES: "FAVORITE",
	WORLD_FILTER_RECENT: "RECENTLY JOINED",
	WORLD_FILTER_MINE: "YOUR WORLD",
}
const MAX_FAVORITE_WORLDS := 32
const LOBBY_PARALLAX_LAYERS := [
	{"name": "Layer8", "texture": preload("res://Assets/background/space_theme/star_1.png"), "drift": 0.0, "speed": 0.0, "phase": 0.0, "overscan": 0.0},
	{"name": "Layer7", "texture": preload("res://Assets/background/space_theme/star_2.png"), "drift": 18.0, "speed": 0.32, "phase": 0.0, "overscan": 24.0},
	{"name": "Layer6", "texture": preload("res://Assets/background/space_theme/star_3.png"), "drift": 28.0, "speed": 0.39, "phase": 2.1, "overscan": 34.0},
	{"name": "Layer5", "texture": preload("res://Assets/background/space_theme/star_4.png"), "drift": 40.0, "speed": 0.46, "phase": 4.2, "overscan": 46.0},
]

# Landfill seasonal event -- see Scripts/server_landfill_event.ts (server) and
# landfill_seasonal_event_design.md for the full design. This was originally wired into
# Scripts/lobby_menu.gd, which is NOT the script attached to LobbyScene.tscn (lobby_menu.gd/
# lobby_menu.tscn are an orphaned, unused pair). Ported here so it actually runs in the live
# lobby. Mirrors the world-population-poll pattern already in this file (_start_world_population_timer/
# _request_world_population_refresh) and reuses the already-proven _join_world_name() for the
# actual join, same as the original lobby_menu.gd implementation did.
const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")
const LANDFILL_STATUS_REFRESH_SECONDS := 15.0
# Landfill event card (badge art + "Go Green!" join button), pinned to the TOP-RIGHT corner.
#
# Anchored rather than placed at fixed offsets like the rest of this lobby: every other control
# here hardcodes a position in the design canvas, which only stays correct while the canvas is the
# size those numbers were written against. Anchoring to the right edge keeps the card in the corner
# at any window size or stretch scale, so it cannot drift off-screen or collide with the world list.
const LANDFILL_EVENT_ICON_PATH := "res://Assets/events/landfill/icon.png"
const LANDFILL_CARD_MARGIN := 28.0
const LANDFILL_CARD_W := 200.0
const LANDFILL_ICON_H := 168.0
const LANDFILL_CARD_BUTTON_H := 46.0
const LANDFILL_CARD_H := LANDFILL_ICON_H + 8.0 + LANDFILL_CARD_BUTTON_H

var world_input: LineEdit
var join_button: Button
var input_status_label: Label
var username_label: Label
var profile_level_label: Label
var profile_xp_label: Label
var profile_xp_fill: ColorRect
var profile_gems_label: Label
var profile_total_xp_label: Label
var world_population_cache: Dictionary = {}
var world_population_timer: Timer
var active_world_scroll: ScrollContainer
var active_world_rows: VBoxContainer
var active_world_row_template: Button
var active_world_empty_label: Label
var active_world_list_signature := ""
var active_world_filter := WORLD_FILTER_ACTIVE
var favorite_world_names: Array[String] = []
var owned_world_names: Array[String] = []
var join_scene_change_in_progress := false
var lobby_parallax_layers: Array = []
var lobby_parallax_time := 0.0

var landfill_status_timer: Timer
var landfill_event_active := false
var landfill_season_key := ""
var landfill_join_button: Button
# Container for the event badge + "Go Green!" join button. Toggling this one node's visibility
# governs the whole card, so the icon and its button can never end up in disagreeing states.
var landfill_event_card: Control
var landfill_join_in_progress := false
var landfill_join_request_id := ""


func _ready() -> void:
	super._ready()

	if Engine.is_editor_hint():
		return

	_setup_lobby_parallax_background()
	WorldScenePreloader.start()
	# Same MusicManager autoload login_screen.gd uses -- if we arrived here straight from
	# login, this is a no-op (already playing, keeps going uninterrupted); if the lobby was
	# somehow entered without login having started it, this starts it fresh.
	if MusicManager != null and MusicManager.has_method("start_login_loop"):
		MusicManager.start_login_loop()
	_bind_scene_nodes()
	_load_favorite_world_names()
	_setup_active_world_list()
	_connect_scene_buttons()
	_load_profile()
	_connect_world_population_feed()
	_connect_owned_worlds_feed()
	_start_world_population_timer()
	_request_world_population_refresh()
	call_deferred("_prime_join_world_loading_overlay")
	_add_landfill_buttons()
	_connect_landfill_feed()
	_start_landfill_status_timer()
	_request_landfill_status_refresh()
	# Last, so it wins the status label over anything the setup above wrote: if we got here
	# because a world join failed, this is where the player finds out why.
	_show_pending_world_join_failure_message()


# A failed world entry cannot show its own error -- by the time save_manager knows the join
# failed it has already hidden every ui_layer child, and the scene change frees them in the
# same frame, so a notification there gets zero rendered frames. save_manager stashes the
# reason in the profile config instead (_store_world_join_failure_message_for_lobby) and we
# surface it here, once the lobby is actually back up. Read-once: cleared immediately so the
# message never reappears on a later, unrelated visit to the lobby.
func _show_pending_world_join_failure_message() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PROFILE_PATH) != OK:
		return

	var stored_message := str(cfg.get_value("world_join_failure", "message", "")).strip_edges()
	if stored_message == "":
		return

	cfg.set_value("world_join_failure", "message", "")
	cfg.save(PROFILE_PATH)

	_set_input_status(stored_message.to_upper())


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	WorldScenePreloader.pump()
	_update_lobby_parallax_background(delta)


func _setup_lobby_parallax_background() -> void:
	lobby_parallax_layers.clear()
	lobby_parallax_time = 0.0

	var base_layer := get_node_or_null("MountainBackground") as TextureRect
	if base_layer == null:
		return

	for index in range(LOBBY_PARALLAX_LAYERS.size()):
		var layer_data: Dictionary = LOBBY_PARALLAX_LAYERS[index]
		var layer: TextureRect = base_layer
		if index > 0:
			layer = TextureRect.new()
			layer.name = str(layer_data.get("name", "Layer" + str(8 - index)))
			layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			add_child(layer)
			move_child(layer, base_layer.get_index() + index)

		layer.texture = layer_data.get("texture", null) as Texture2D
		layer.set_anchors_preset(Control.PRESET_TOP_LEFT)
		lobby_parallax_layers.append({
			"node": layer,
			"base_position": Vector2.ZERO,
			"drift": float(layer_data.get("drift", 0.0)),
			"speed": float(layer_data.get("speed", 0.0)),
			"phase": float(layer_data.get("phase", 0.0)),
			"overscan": float(layer_data.get("overscan", 0.0)),
		})

	if not resized.is_connected(_layout_lobby_parallax_background):
		resized.connect(_layout_lobby_parallax_background)

	_layout_lobby_parallax_background()
	_update_lobby_parallax_background(0.0)


func _layout_lobby_parallax_background() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	for layer_entry in lobby_parallax_layers:
		var layer := layer_entry.get("node", null) as TextureRect
		if layer == null or not is_instance_valid(layer):
			continue

		var margin := float(layer_entry.get("overscan", 0.0))
		var base_position := Vector2(-margin, -margin)
		layer.position = base_position
		layer.size = viewport_size + Vector2(margin * 2.0, margin * 2.0)
		layer_entry["base_position"] = base_position


func _update_lobby_parallax_background(delta: float) -> void:
	if lobby_parallax_layers.is_empty():
		return

	lobby_parallax_time += delta
	for layer_entry in lobby_parallax_layers:
		var layer := layer_entry.get("node", null) as TextureRect
		if layer == null or not is_instance_valid(layer):
			continue

		var base_position := layer_entry.get("base_position", Vector2.ZERO) as Vector2
		var drift := float(layer_entry.get("drift", 0.0))
		var speed := float(layer_entry.get("speed", 0.0))
		var phase := float(layer_entry.get("phase", 0.0))
		var horizontal_offset := sin((lobby_parallax_time * speed) + phase) * drift
		layer.position = base_position + Vector2(horizontal_offset, 0.0)


func _bind_scene_nodes() -> void:
	world_input = get_node_or_null("JoinPanel/WorldInput") as LineEdit
	# The world name box ALWAYS starts empty, every time the lobby is entered -- fresh from
	# login, after leaving a world, and after a failed join (which now returns here too).
	# It used to be seeded from profile/last_world in _load_profile(), so the previous world
	# name was still sitting there and had to be cleared by hand before typing a new one.
	# Cleared here rather than there so it holds even if the .tscn ever ships authored text.
	# profile/last_world is still WRITTEN and still used elsewhere -- world.gd's
	# get_pending_join_world_name_early() falls back to it on the auto-rejoin path -- it is
	# just no longer used to pre-fill this box.
	if world_input != null:
		world_input.text = ""
	join_button = get_node_or_null("JoinPanel/JoinButton") as Button
	input_status_label = get_node_or_null("JoinPanel/WorldInputLabel") as Label
	username_label = get_node_or_null("ProfilePanel/ProfileCard/Username") as Label
	profile_level_label = get_node_or_null("ProfilePanel/LevelText") as Label
	profile_xp_label = get_node_or_null("ProfilePanel/XpText") as Label
	profile_xp_fill = get_node_or_null("ProfilePanel/XpFill") as ColorRect
	profile_gems_label = get_node_or_null("ProfilePanel/GemsRow/GemLabel") as Label
	profile_total_xp_label = get_node_or_null("ProfilePanel/XpRow/TotalXpLabel") as Label


func _setup_active_world_list() -> void:
	var worlds_panel := get_node_or_null("WorldsPanel") as Control
	var static_rows := get_node_or_null("WorldsPanel/WorldRows") as Control
	var static_start := get_node_or_null("WorldsPanel/WorldStart") as Control
	var template := get_node_or_null("WorldsPanel/WorldRows/WorldTest") as Button
	if worlds_panel == null:
		return

	if static_start != null:
		active_world_row_template = static_start.duplicate() as Button
	elif template != null:
		active_world_row_template = template.duplicate() as Button
	else:
		active_world_row_template = null
	if active_world_row_template == null:
		return
	if static_start != null:
		static_start.visible = false
		static_start.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if static_rows != null:
		static_rows.visible = false
		static_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE

	active_world_scroll = ScrollContainer.new()
	active_world_scroll.name = "ActiveWorldScroll"
	active_world_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	active_world_scroll.offset_left = ACTIVE_WORLD_LIST_SIDE_MARGIN
	active_world_scroll.offset_top = ACTIVE_WORLD_LIST_TOP
	active_world_scroll.offset_right = -ACTIVE_WORLD_LIST_SIDE_MARGIN
	active_world_scroll.offset_bottom = -ACTIVE_WORLD_LIST_BOTTOM_MARGIN
	active_world_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	active_world_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	active_world_scroll.follow_focus = true
	active_world_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	worlds_panel.add_child(active_world_scroll)

	active_world_rows = VBoxContainer.new()
	active_world_rows.name = "ActiveWorldRows"
	active_world_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_world_rows.add_theme_constant_override("separation", ACTIVE_WORLD_ROW_SEPARATION)
	active_world_scroll.add_child(active_world_rows)

	active_world_empty_label = Label.new()
	active_world_empty_label.name = "EmptyState"
	active_world_empty_label.custom_minimum_size = Vector2(0.0, 96.0)
	active_world_empty_label.text = "NO ACTIVE WORLDS RIGHT NOW"
	active_world_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_world_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	active_world_empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	active_world_empty_label.add_theme_color_override("font_color", Color(0.870588, 0.960784, 1.0, 1.0))
	active_world_empty_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	active_world_empty_label.add_theme_constant_override("shadow_offset_x", 2)
	active_world_empty_label.add_theme_constant_override("shadow_offset_y", 2)
	active_world_empty_label.add_theme_font_size_override("font_size", 16)
	var template_name := _get_world_row_label(active_world_row_template, ["StartName", "Name"])
	if template_name != null:
		active_world_empty_label.add_theme_font_override("font", template_name.get_theme_font("font"))
	active_world_rows.add_child(active_world_empty_label)

	_refresh_world_rows()


func _connect_scene_buttons() -> void:
	if join_button != null:
		_connect_button_once(join_button, Callable(self, "_on_join_pressed"))
	if world_input != null:
		var submitted := Callable(self, "_on_world_text_submitted")
		if not world_input.text_submitted.is_connected(submitted):
			world_input.text_submitted.connect(submitted)

	_connect_button_by_path("TopButtons/ProfileButton", Callable(self, "_on_profile_switch_pressed"))
	_connect_button_by_path("RightButtons/OrbitButton", Callable(self, "_on_start_world_pressed"))

	for filter_key in WORLD_FILTER_BUTTON_PATHS.keys():
		var filter_button := get_node_or_null(str(WORLD_FILTER_BUTTON_PATHS[filter_key])) as Button
		if filter_button == null:
			continue
		_connect_button_once(filter_button, Callable(self, "_on_world_filter_pressed").bind(str(filter_key)))
	_sync_world_filter_buttons()
	_update_worlds_title()


func _connect_button_by_path(path: String, callback: Callable) -> void:
	var button := get_node_or_null(path) as Button
	if button != null:
		_connect_button_once(button, callback)


func _connect_button_once(button: Button, callback: Callable) -> void:
	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)


func _load_profile() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(PROFILE_PATH)
	var session_username := _get_network_session_username()
	var username := session_username

	if err == OK:
		if username == "":
			username = str(cfg.get_value("profile", "username", "")).strip_edges()

	if username == "":
		username = _get_fallback_profile_name()

	if username_label != null and username != "":
		username_label.text = username.strip_edges().to_upper()

	_refresh_profile_progression()


func _get_fallback_profile_name() -> String:
	if username_label != null:
		var current := username_label.text.strip_edges()
		if current != "":
			return current
	return "Player"


func _connect_world_population_feed() -> void:
	var network = get_node_or_null("/root/NetworkManager")
	if network == null:
		return

	if network.has_method("get_world_population_counts"):
		_apply_world_population_counts(network.get_world_population_counts(), true)

	var callback := Callable(self, "_on_world_population_changed")
	if network.has_signal("world_population_changed") and not network.is_connected("world_population_changed", callback):
		network.connect("world_population_changed", callback)


func _start_world_population_timer() -> void:
	if world_population_timer != null:
		return

	world_population_timer = Timer.new()
	world_population_timer.name = "WorldPopulationRefreshTimer"
	world_population_timer.wait_time = WORLD_POPULATION_REFRESH_SECONDS
	world_population_timer.autostart = true
	world_population_timer.timeout.connect(_request_world_population_refresh)
	add_child(world_population_timer)


func _request_world_population_refresh() -> void:
	var network = get_node_or_null("/root/NetworkManager")
	if network == null:
		return
	if network.has_method("get_world_population_counts"):
		_apply_world_population_counts(network.get_world_population_counts(), true)
	if network.has_method("request_world_population"):
		network.request_world_population()


func _on_world_population_changed(world_counts: Dictionary) -> void:
	_apply_world_population_counts(world_counts, true)


func _apply_world_population_counts(world_counts: Dictionary, replace_existing: bool) -> void:
	var next_counts: Dictionary = {} if replace_existing else world_population_cache.duplicate()

	for world_name in world_counts.keys():
		var clean_world := _normalize_world_name(str(world_name))
		if clean_world == "":
			continue

		var count := maxi(0, int(world_counts.get(world_name, 0)))
		next_counts[clean_world] = count

	if next_counts != world_population_cache:
		world_population_cache = next_counts
		_refresh_world_rows()


func _refresh_world_rows() -> void:
	if active_world_rows == null or active_world_row_template == null:
		return

	var entries := _build_world_entries()

	# Favourites are part of the signature because toggling a heart changes how a row draws
	# without changing which rows exist.
	var next_signature := JSON.stringify({
		"filter": active_world_filter,
		"entries": entries,
		"favorites": favorite_world_names,
	})
	if next_signature == active_world_list_signature:
		return
	active_world_list_signature = next_signature

	for child in active_world_rows.get_children():
		if child == active_world_empty_label:
			continue
		active_world_rows.remove_child(child)
		child.queue_free()

	active_world_empty_label.text = str(WORLD_FILTER_EMPTY_TEXT.get(active_world_filter, WORLD_FILTER_EMPTY_TEXT[WORLD_FILTER_ACTIVE]))
	active_world_empty_label.visible = entries.is_empty()
	for entry in entries:
		_add_active_world_row(str(entry.get("world", "")), int(entry.get("count", 0)))


func _build_world_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []

	if active_world_filter == WORLD_FILTER_ACTIVE:
		var start_player_count := maxi(0, int(world_population_cache.get(LOBBY_HUB_WORLD, 0)))
		entries.append({"world": LOBBY_HUB_WORLD, "count": start_player_count})
		for raw_world in world_population_cache.keys():
			var world_name := _normalize_world_name(str(raw_world))
			var count := maxi(0, int(world_population_cache.get(raw_world, 0)))
			if world_name == "" or world_name == LOBBY_HUB_WORLD or count <= 0:
				continue
			entries.append({"world": world_name, "count": count})
		entries.sort_custom(_sort_active_world_entries)
		return entries

	# The other tabs are ordered lists, not popularity rankings: recents are newest-first and
	# favourites keep the order they were starred in, so they are deliberately not sorted.
	for world_name in _get_world_names_for_filter(active_world_filter):
		entries.append({
			"world": world_name,
			"count": maxi(0, int(world_population_cache.get(world_name, 0))),
		})
	return entries


func _get_world_names_for_filter(filter_key: String) -> Array[String]:
	var names: Array[String] = []
	match filter_key:
		WORLD_FILTER_FAVORITES:
			names.assign(favorite_world_names)
		WORLD_FILTER_RECENT:
			names.assign(_load_recent_world_names())
		WORLD_FILTER_MINE:
			names.assign(owned_world_names)
	return names


func _sort_active_world_entries(left: Dictionary, right: Dictionary) -> bool:
	var left_world := str(left.get("world", ""))
	var right_world := str(right.get("world", ""))
	if left_world == LOBBY_HUB_WORLD and right_world != LOBBY_HUB_WORLD:
		return true
	if right_world == LOBBY_HUB_WORLD and left_world != LOBBY_HUB_WORLD:
		return false

	var left_count := int(left.get("count", 0))
	var right_count := int(right.get("count", 0))
	if left_count != right_count:
		return left_count > right_count
	return left_world < right_world


func _add_active_world_row(world_name: String, player_count: int) -> void:
	if active_world_rows == null or active_world_row_template == null:
		return

	var row := active_world_row_template.duplicate() as Button
	if row == null:
		return
	row.name = "World_" + world_name.validate_node_name()
	row.visible = true
	row.custom_minimum_size = Vector2(0.0, ACTIVE_WORLD_ROW_HEIGHT)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_meta("world_name", world_name)
	var is_start_hub := world_name == LOBBY_HUB_WORLD

	var hub_icon := row.get_node_or_null("HubIcon") as Label
	if hub_icon != null:
		hub_icon.text = "H" if is_start_hub else world_name.substr(0, 1).to_upper()

	var name_label := _get_world_row_label(row, ["StartName", "Name"])
	if name_label != null:
		name_label.text = world_name
	var meta_label := _get_world_row_label(row, ["StartMeta", "Meta"])
	if meta_label != null:
		var source_label := "OFFICIAL"
		if not is_start_hub:
			# Outside the live list a world can legitimately have nobody in it, and calling
			# that "LIVE | 0 players" reads as a bug.
			source_label = "LIVE" if player_count > 0 else "OFFLINE"
		meta_label.text = source_label + " | OPEN | " + _get_player_count_text(player_count)
	var badge_label := _get_world_row_label(row, ["OfficialBadge"])
	if badge_label != null:
		if is_start_hub:
			badge_label.text = "OFFICIAL HUB"
		else:
			badge_label.text = str(WORLD_FILTER_ROW_BADGES.get(active_world_filter, "ACTIVE WORLD"))
		badge_label.visible = true

	var favorite_toggle := row.get_node_or_null("FavoriteToggle") as Button
	if favorite_toggle != null:
		# The row itself ignores the mouse so the join button can own its clicks; the heart
		# has to opt back in or presses fall straight through it.
		favorite_toggle.mouse_filter = Control.MOUSE_FILTER_STOP
		favorite_toggle.disabled = false
		favorite_toggle.set_pressed_no_signal(_is_favorite_world(world_name))
		_apply_favorite_toggle_visual(favorite_toggle)
		var favorite_callback := Callable(self, "_on_favorite_toggled").bind(world_name)
		if not favorite_toggle.toggled.is_connected(favorite_callback):
			favorite_toggle.toggled.connect(favorite_callback)
	var player_label := _get_world_row_label(row, ["StartPlayers"])
	if player_label != null:
		player_label.text = _get_player_count_text(player_count).to_upper()
	var row_join_button := _get_world_row_join_button(row)
	if row_join_button != null:
		row_join_button.mouse_filter = Control.MOUSE_FILTER_STOP
		_connect_button_once(row_join_button, Callable(self, "_on_active_world_join_pressed").bind(world_name))

	active_world_rows.add_child(row)


func _get_world_row_label(row: Node, label_names: Array[String]) -> Label:
	if row == null:
		return null
	for label_name in label_names:
		var label := row.get_node_or_null(label_name) as Label
		if label != null:
			return label
	return null


func _get_world_row_join_button(row: Node) -> Button:
	if row == null:
		return null
	var join_button_names := ["StartJoin", "Join"]
	for button_name in join_button_names:
		var button := row.get_node_or_null(button_name) as Button
		if button != null:
			return button
	return null


func _on_active_world_join_pressed(world_name: String) -> void:
	var clean_world := _normalize_world_name(world_name)
	if clean_world == "":
		return
	if world_input != null:
		world_input.text = clean_world
	_join_world_name(clean_world)


func _get_player_count_text(count: int) -> String:
	if count == 1:
		return "1 player"
	return str(count) + " players"


func _on_world_filter_pressed(filter_key: String) -> void:
	# Pressing the tab you are already on drops back to the default live list, so the left
	# column never becomes a trap you cannot leave.
	var next_filter := WORLD_FILTER_ACTIVE if active_world_filter == filter_key else filter_key
	_set_world_filter(next_filter)


func _set_world_filter(filter_key: String) -> void:
	active_world_filter = filter_key
	_sync_world_filter_buttons()
	_update_worlds_title()
	if filter_key == WORLD_FILTER_MINE:
		_request_owned_worlds_refresh()
	# The entry list for a different tab can happen to serialise identically (two empty tabs,
	# say), so clear the signature or the rebuild would be skipped and the old rows would stay.
	active_world_list_signature = ""
	_refresh_world_rows()


func _sync_world_filter_buttons() -> void:
	for filter_key in WORLD_FILTER_BUTTON_PATHS.keys():
		var filter_button := get_node_or_null(str(WORLD_FILTER_BUTTON_PATHS[filter_key])) as Button
		if filter_button == null:
			continue
		# These are toggle buttons, so they latch on click. Driving the group by hand keeps
		# exactly one lit and stops a stale one staying pressed after switching tabs.
		filter_button.set_pressed_no_signal(str(filter_key) == active_world_filter)


func _update_worlds_title() -> void:
	var title := get_node_or_null("WorldsPanel/WorldsHeader/WorldsTitle") as Label
	if title == null:
		return
	title.text = str(WORLD_FILTER_TITLES.get(active_world_filter, WORLD_FILTER_TITLES[WORLD_FILTER_ACTIVE]))


func _load_recent_world_names() -> Array[String]:
	# Written by _save_recent_world_name() on every successful join, newest first.
	var names: Array[String] = []
	var cfg := ConfigFile.new()
	if cfg.load(PROFILE_PATH) != OK:
		return names
	var raw = cfg.get_value("profile", "recent_worlds", [])
	if not (raw is Array):
		return names
	for value in raw:
		var world_name := _normalize_world_name(str(value))
		if world_name != "" and not names.has(world_name):
			names.append(world_name)
	return names


func _load_favorite_world_names() -> void:
	favorite_world_names.clear()
	var cfg := ConfigFile.new()
	if cfg.load(PROFILE_PATH) != OK:
		return
	var raw = cfg.get_value("profile", "favorite_worlds", [])
	if not (raw is Array):
		return
	for value in raw:
		var world_name := _normalize_world_name(str(value))
		if world_name != "" and not favorite_world_names.has(world_name):
			favorite_world_names.append(world_name)


func _save_favorite_world_names() -> void:
	var cfg := ConfigFile.new()
	# Load first: this file also holds the profile, recents and the pending join-failure
	# message, and saving a fresh ConfigFile would wipe all of it.
	cfg.load(PROFILE_PATH)
	cfg.set_value("profile", "favorite_worlds", favorite_world_names.duplicate())
	cfg.save(PROFILE_PATH)


func _is_favorite_world(world_name: String) -> bool:
	return favorite_world_names.has(_normalize_world_name(world_name))


func _on_favorite_toggled(is_favorite: bool, world_name: String) -> void:
	var clean_world := _normalize_world_name(world_name)
	if clean_world == "":
		return

	if is_favorite:
		if not favorite_world_names.has(clean_world):
			favorite_world_names.append(clean_world)
			# Oldest out, not the one just starred.
			while favorite_world_names.size() > MAX_FAVORITE_WORLDS:
				favorite_world_names.remove_at(0)
	else:
		favorite_world_names.erase(clean_world)

	_save_favorite_world_names()

	if active_world_filter == WORLD_FILTER_FAVORITES:
		# Un-starring from inside the favourites tab has to drop the row it was on.
		active_world_list_signature = ""
		_refresh_world_rows()
		return

	# Otherwise just repaint the heart that was clicked; rebuilding would fight the press.
	if active_world_rows == null:
		return
	for row in active_world_rows.get_children():
		if not (row is Button):
			continue
		if str((row as Button).get_meta("world_name", "")) != clean_world:
			continue
		var toggle := row.get_node_or_null("FavoriteToggle") as Button
		if toggle != null:
			toggle.set_pressed_no_signal(is_favorite)
			_apply_favorite_toggle_visual(toggle)


func _apply_favorite_toggle_visual(toggle: Button) -> void:
	if toggle == null:
		return
	# Matches the dimmed alpha LobbyScene.tscn authors on the unfavourited heart.
	toggle.modulate = Color(1.0, 1.0, 1.0, 1.0 if toggle.button_pressed else 0.42)


func _connect_owned_worlds_feed() -> void:
	var network = get_node_or_null("/root/NetworkManager")
	if network == null:
		return

	if network.has_method("get_owned_locked_worlds_cache"):
		_apply_owned_world_entries(network.get_owned_locked_worlds_cache())

	var callback := Callable(self, "_on_owned_locked_worlds_received")
	if network.has_signal("owned_locked_worlds_received") and not network.is_connected("owned_locked_worlds_received", callback):
		network.connect("owned_locked_worlds_received", callback)


func _request_owned_worlds_refresh() -> void:
	var network = get_node_or_null("/root/NetworkManager")
	if network == null:
		return
	if network.has_method("request_owned_locked_worlds"):
		network.request_owned_locked_worlds()


func _on_owned_locked_worlds_received(data) -> void:
	if data is Dictionary:
		_apply_owned_world_entries((data as Dictionary).get("worlds", []))
	elif data is Array:
		_apply_owned_world_entries(data)


func _apply_owned_world_entries(raw_worlds) -> void:
	var names: Array[String] = []
	if raw_worlds is Array:
		for raw_entry in raw_worlds:
			var world_name := ""
			if raw_entry is Dictionary:
				world_name = _normalize_world_name(str((raw_entry as Dictionary).get("world_name", "")))
			else:
				world_name = _normalize_world_name(str(raw_entry))
			if world_name != "" and not names.has(world_name):
				names.append(world_name)

	if names == owned_world_names:
		return
	owned_world_names = names
	if active_world_filter == WORLD_FILTER_MINE:
		active_world_list_signature = ""
		_refresh_world_rows()


func _on_world_text_submitted(_text: String) -> void:
	_on_join_pressed()


func _on_join_pressed() -> void:
	if world_input == null:
		return
	_join_world_name(world_input.text)


func _on_start_world_pressed() -> void:
	_join_world_name(LOBBY_HUB_WORLD)


func _on_world_join_pressed(row_path: String) -> void:
	var row := get_node_or_null(row_path) as Button
	var world_name := _get_world_name_from_row(row)
	if world_name == "":
		return
	if world_input != null:
		world_input.text = world_name
	_join_world_name(world_name)


func _get_world_name_from_row(row: Button) -> String:
	if row == null:
		return ""

	var name_label := row.get_node_or_null("Name") as Label
	if name_label != null:
		return _normalize_world_name(name_label.text)

	return _normalize_world_name(row.text)


func _join_world_name(raw_world_name: String) -> void:
	if join_scene_change_in_progress:
		return

	var world_name := _normalize_world_name(raw_world_name)
	if world_name.is_empty():
		_set_input_status("ENTER WORLD NAME FIRST")
		return

	join_scene_change_in_progress = true
	_set_input_status("JOINING " + world_name)
	if world_input != null:
		world_input.text = world_name

	var profile_name := _get_network_session_username()
	if profile_name == "" and username_label != null:
		profile_name = username_label.text.strip_edges()

	var network = get_node_or_null("/root/NetworkManager")
	if network != null and network.has_method("set_pending_join"):
		network.set_pending_join(world_name, profile_name)
	if network != null and network.has_method("send_join_world_if_needed"):
		# Start server admission immediately while the world scene finishes loading.
		# If authentication is still completing, the pending-join path sends it later.
		network.send_join_world_if_needed(world_name)

	_show_join_world_loading_overlay(world_name)
	await _wait_for_join_world_loading_overlay_to_draw()
	if network != null and network.has_method("record_world_entry_stage"):
		network.record_world_entry_stage("client_lobby_overlay_drawn")

	# This wait is invisible in the old profile but can be unbounded: it blocks until
	# WorldScenePreloader has threaded-loaded main.tscn, the item DB and all 31 critical
	# scripts. On a first join of a session that is real, measurable time; on later joins
	# it should be ~0. Instrumented so the timeline shows which case we are in.
	var world_scene := await _wait_for_world_scene_ready()
	# How far the optional visual-texture warmup got before this join started. A non-zero
	# "remaining" means those textures get loaded cold and synchronously during the world build,
	# which is the first-join-of-session penalty. Printed unconditionally (not via the profile's
	# `extra`, which only surfaces in verbose builds) so it shows up next to WORLD_JOIN_PROFILE.
	var warmup_progress: Dictionary = WorldScenePreloader.get_visual_warmup_progress()
	print("[WORLD_JOIN_PROFILE] visual_warmup " + JSON.stringify(warmup_progress))
	if network != null and network.has_method("record_world_entry_stage"):
		network.record_world_entry_stage("client_world_scene_preloaded", warmup_progress)
	if world_scene == null:
		if network != null and network.has_method("cancel_active_join_request"):
			network.cancel_active_join_request()
		join_scene_change_in_progress = false
		_set_input_status("COULD NOT OPEN WORLD")
		_set_join_world_loading_message("Could not prepare the world. Please try again.")
		await get_tree().create_timer(0.8).timeout
		_hide_join_world_loading_overlay()
		return

	_set_join_world_loading_progress(1.0)
	# Stop the menu loop here -- gameplay shouldn't have the login/lobby music under it.
	if MusicManager != null and MusicManager.has_method("stop_login_loop"):
		MusicManager.stop_login_loop()
	if network != null and network.has_method("record_world_entry_stage"):
		network.record_world_entry_stage("client_scene_change_requested")
	var change_error := get_tree().change_scene_to_packed(world_scene)
	if change_error != OK:
		if network != null and network.has_method("cancel_active_join_request"):
			network.cancel_active_join_request()
		join_scene_change_in_progress = false
		_set_input_status("COULD NOT OPEN WORLD")
		_hide_join_world_loading_overlay()
		# Scene change didn't happen -- we're still in the lobby, so resume the loop.
		if MusicManager != null and MusicManager.has_method("start_login_loop"):
			MusicManager.start_login_loop()


func _set_input_status(text: String) -> void:
	if input_status_label != null:
		input_status_label.text = text


func _save_recent_world_name(world_name: String) -> void:
	var clean_name := _normalize_world_name(world_name)
	if clean_name == "":
		return

	var cfg := ConfigFile.new()
	cfg.load(PROFILE_PATH)
	_update_recent_world_name_in_config(cfg, clean_name)
	cfg.save(PROFILE_PATH)


func _update_recent_world_name_in_config(cfg: ConfigFile, world_name: String) -> void:
	var clean_name := _normalize_world_name(world_name)
	if clean_name == "":
		return

	var old_recent = cfg.get_value("profile", "recent_worlds", [])
	var new_recent: Array = [clean_name]

	if old_recent is Array:
		for value in old_recent:
			var old_name := _normalize_world_name(str(value))
			if old_name == "" or old_name == clean_name:
				continue
			if not new_recent.has(old_name):
				new_recent.append(old_name)
			if new_recent.size() >= 8:
				break

	cfg.set_value("profile", "recent_worlds", new_recent)


func _normalize_world_name(world_name: String) -> String:
	var clean := world_name.strip_edges().to_lower()
	var allowed := "abcdefghijklmnopqrstuvwxyz0123456789_-"
	var result := ""

	for i in range(clean.length()):
		var character := clean.substr(i, 1)
		if allowed.find(character) != -1:
			result += character
		elif character == " ":
			result += "_"

	return result.to_upper()


func _sanitize_player_name_for_path(raw_name: String) -> String:
	var clean := raw_name.strip_edges().to_lower()
	if clean == "":
		clean = "guest"

	var allowed := "abcdefghijklmnopqrstuvwxyz0123456789_-"
	var result := ""
	for i in range(clean.length()):
		var character := clean.substr(i, 1)
		if allowed.find(character) != -1:
			result += character
		elif character == " ":
			result += "_"

	return result if result != "" else "guest"


func _load_profile_progression_data(profile_name: String) -> Dictionary:
	var save_path := PLAYER_SAVE_FOLDER + _sanitize_player_name_for_path(profile_name) + ".json"
	if not FileAccess.file_exists(save_path):
		return {}

	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return {}

	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data is Dictionary:
		var nested = data.get("player_data", null)
		if nested is Dictionary:
			return nested
		return data

	return {}


func _get_xp_needed_for_level(level: int) -> int:
	var safe_level: int = clampi(level, 1, PLAYER_MAX_LEVEL)
	if safe_level >= PLAYER_MAX_LEVEL:
		return 0

	var level_index: int = safe_level - 1
	return 300 + (level_index * 120) + int(floor(pow(float(level_index), 1.6) * 42.0))


func _get_profile_title(level: int) -> String:
	if level >= 100:
		return "PIXEL LEGEND"
	if level >= 80:
		return "WORLDSMITH"
	if level >= 60:
		return "ARCHITECT"
	if level >= 40:
		return "TRAILBLAZER"
	if level >= 25:
		return "CRAFTER"
	if level >= 10:
		return "BUILDER"
	return "EXPLORER"


func _format_lobby_amount(value: int) -> String:
	var text := str(max(0, value))
	var result := ""
	var count := 0

	for i in range(text.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = text.substr(i, 1) + result
		count += 1

	return result


func _refresh_profile_progression() -> void:
	var profile_name := _get_current_profile_name()
	var data := _load_profile_progression_data(profile_name)
	if data.is_empty():
		return

	var level: int = clampi(int(data.get("player_level", data.get("level", 1))), 1, PLAYER_MAX_LEVEL)
	var xp: int = maxi(0, int(data.get("player_xp", data.get("xp", 0))))
	var xp_needed: int = maxi(0, int(data.get("player_xp_needed", data.get("xp_needed", _get_xp_needed_for_level(level)))))
	var total_xp: int = maxi(0, int(data.get("player_total_xp", data.get("total_xp", 0))))
	var title := str(data.get("player_title", _get_profile_title(level))).strip_edges().to_upper()
	if title == "":
		title = _get_profile_title(level)

	if profile_level_label != null:
		profile_level_label.text = "LEVEL " + str(level) + "   |   " + title
	if profile_xp_label != null:
		profile_xp_label.text = "MAX" if xp_needed <= 0 else str(xp) + " / " + str(xp_needed)

	var ratio: float = 1.0 if xp_needed <= 0 else clampf(float(xp) / float(maxi(1, xp_needed)), 0.0, 1.0)
	if profile_xp_fill != null:
		var fill_left: float = profile_xp_fill.position.x
		var xp_back := get_node_or_null("ProfilePanel/XpBack") as Control
		var max_width: float = 205.0
		if xp_back != null:
			max_width = max(0.0, xp_back.size.x - ((fill_left - xp_back.position.x) * 2.0))
		profile_xp_fill.size = Vector2(round(max_width * ratio), profile_xp_fill.size.y)

	var currency = data.get("currency_inventory", {})
	var gems: int = 0
	if currency is Dictionary:
		gems = maxi(0, int(currency.get("gem", 0)))
	if profile_gems_label != null:
		profile_gems_label.text = "GM " + _format_lobby_amount(gems)
	if profile_total_xp_label != null:
		profile_total_xp_label.text = "XP " + _format_lobby_amount(total_xp)


func _get_current_profile_name() -> String:
	var session_username := _get_network_session_username()
	if session_username != "":
		return session_username

	var cfg := ConfigFile.new()
	if cfg.load(PROFILE_PATH) == OK:
		var profile_name := str(cfg.get_value("profile", "username", "")).strip_edges()
		if profile_name != "":
			return profile_name

	if username_label != null:
		return username_label.text.strip_edges()

	return ""


func _show_join_world_loading_overlay(world_name: String) -> void:
	var overlay_scene_instance: Node = _get_or_create_root_loading_overlay()
	if overlay_scene_instance == null:
		return

	var loading_canvas = _find_loading_canvas(overlay_scene_instance)
	if loading_canvas == null:
		return

	if overlay_scene_instance is CanvasItem:
		overlay_scene_instance.visible = true

	if loading_canvas is CanvasLayer:
		loading_canvas.layer = WORLD_LOADING_CANVAS_LAYER
		loading_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
		loading_canvas.visible = true

	var loading_root = _find_loading_root(loading_canvas)
	if loading_root is Control:
		loading_root.visible = true
		loading_root.modulate = Color(1, 1, 1, 1)
		loading_root.mouse_filter = Control.MOUSE_FILTER_STOP

	var clean_world_name := world_name.strip_edges().to_upper()
	if clean_world_name == "":
		clean_world_name = "WORLD"

	var title_label := _find_loading_label(loading_canvas, "Title")
	if title_label != null:
		title_label.text = _format_loading_title(clean_world_name)

	var message_label := _find_loading_label(loading_canvas, "Message")
	if message_label != null:
		message_label.text = "Loading " + clean_world_name + "..."

	var dots_label := _find_loading_label(loading_canvas, "Dots")
	if dots_label != null:
		dots_label.text = "..."

	var parent_node := overlay_scene_instance.get_parent()
	if parent_node != null:
		parent_node.move_child(overlay_scene_instance, parent_node.get_child_count() - 1)


func _set_join_world_loading_message(message: String) -> void:
	var overlay_scene_instance: Node = get_tree().root.get_node_or_null("WorldLoadingOverlay")
	if overlay_scene_instance == null:
		return
	var loading_canvas = _find_loading_canvas(overlay_scene_instance)
	var message_label := _find_loading_label(loading_canvas, "Message")
	if message_label != null:
		message_label.text = message


func _set_join_world_loading_progress(progress_ratio: float) -> void:
	var overlay_scene_instance: Node = get_tree().root.get_node_or_null("WorldLoadingOverlay")
	if overlay_scene_instance == null:
		return
	var loading_canvas = _find_loading_canvas(overlay_scene_instance)
	if not (loading_canvas is Node):
		return

	var normalized_progress := clampf(progress_ratio, 0.0, 1.0)
	var progress_bar := (loading_canvas as Node).find_child("ProgressBar", true, false) as Range
	if progress_bar != null:
		progress_bar.value = normalized_progress * 100.0
	var progress_label := _find_loading_label(loading_canvas, "ProgressPercent")
	if progress_label != null:
		progress_label.text = str(roundi(normalized_progress * 100.0)) + "%"


func _hide_join_world_loading_overlay() -> void:
	var overlay_scene_instance: Node = get_tree().root.get_node_or_null("WorldLoadingOverlay")
	if overlay_scene_instance == null:
		return

	var loading_canvas = _find_loading_canvas(overlay_scene_instance)
	if loading_canvas is CanvasLayer:
		loading_canvas.visible = false

	var loading_root = _find_loading_root(loading_canvas)
	if loading_root is Control:
		loading_root.visible = false


func _wait_for_join_world_loading_overlay_to_draw() -> void:
	var tree := get_tree()
	if tree == null:
		return

	for _i in range(WORLD_JOIN_SCENE_CHANGE_DRAW_FRAMES):
		await tree.process_frame


func _wait_for_world_scene_ready() -> PackedScene:
	var request_error := WorldScenePreloader.start()
	if request_error != OK:
		push_error("[WorldEntry] Could not start threaded world scene load: " + error_string(request_error))
		return null

	while is_inside_tree():
		WorldScenePreloader.pump()
		if WorldScenePreloader.is_ready():
			return WorldScenePreloader.get_loaded_scene()
		var world_status := WorldScenePreloader.get_status()
		var item_database_status := WorldScenePreloader.get_item_database_status()
		if world_status == ResourceLoader.THREAD_LOAD_FAILED or item_database_status == ResourceLoader.THREAD_LOAD_FAILED:
			push_error("[WorldEntry] Threaded world resources failed to load (scene=" + str(world_status) + ", items=" + str(item_database_status) + ")")
			return null

		var progress_ratio := WorldScenePreloader.get_combined_progress()
		_set_join_world_loading_progress(progress_ratio)
		_set_join_world_loading_message("Preparing world... " + str(roundi(progress_ratio * 100.0)) + "%")
		await get_tree().process_frame

	return null


func _prime_join_world_loading_overlay() -> void:
	var overlay_scene_instance := _get_or_create_root_loading_overlay()
	if overlay_scene_instance != null:
		_hide_join_world_loading_overlay()


func _get_or_create_root_loading_overlay() -> Node:
	var root_node := get_tree().root
	if root_node == null:
		return null

	var existing_overlay := root_node.get_node_or_null("WorldLoadingOverlay")
	if existing_overlay != null:
		return existing_overlay

	if WORLD_LOADING_OVERLAY_SCENE == null:
		return null
	var overlay_scene_instance: Node = WORLD_LOADING_OVERLAY_SCENE.instantiate()
	overlay_scene_instance.name = "WorldLoadingOverlay"
	root_node.add_child(overlay_scene_instance)
	return overlay_scene_instance


func _find_loading_canvas(root_node):
	if root_node == null or not is_instance_valid(root_node):
		return null
	if root_node is CanvasLayer:
		return root_node
	if not (root_node is Node):
		return null

	for preferred_name in ["LoadingCanvas", "CanvasLayer", "WorldLoadingOverlay"]:
		var named_canvas = root_node.get_node_or_null(preferred_name)
		if named_canvas is CanvasLayer:
			return named_canvas

	for child in root_node.get_children():
		if child is CanvasLayer:
			return child

	for child in root_node.get_children():
		if child is Node:
			var found_canvas = _find_loading_canvas(child)
			if found_canvas is CanvasLayer:
				return found_canvas

	return null


func _find_loading_root(loading_canvas):
	if loading_canvas == null or not is_instance_valid(loading_canvas):
		return null
	if not (loading_canvas is Node):
		return null

	var root_node = loading_canvas.get_node_or_null("Root")
	if root_node == null:
		root_node = loading_canvas.find_child("Root", true, false)
	return root_node


func _find_loading_label(loading_canvas, label_name: String) -> Label:
	if loading_canvas == null or not is_instance_valid(loading_canvas):
		return null
	if not (loading_canvas is Node):
		return null

	var direct_label = loading_canvas.get_node_or_null("Root/Center/Box/" + label_name)
	if direct_label == null:
		direct_label = loading_canvas.find_child(label_name, true, false)
	if direct_label is Label:
		return direct_label
	return null


func _format_loading_title(world_name: String) -> String:
	var clean_world_name := str(world_name).strip_edges().to_upper()
	if clean_world_name == "" or clean_world_name == "WORLD":
		return "LOADING WORLD"
	return "LOADING WORLD: " + clean_world_name


func _on_profile_switch_pressed() -> void:
	var network = get_node_or_null("/root/NetworkManager")
	if network != null and network.has_method("clear_active_session"):
		network.clear_active_session()

	var cfg := ConfigFile.new()
	cfg.load(PROFILE_PATH)
	cfg.set_value("pending_join", "enabled", false)
	cfg.set_value("pending_join", "world_name", "")
	cfg.set_value("pending_join", "profile_name", "")
	cfg.save(PROFILE_PATH)

	get_tree().change_scene_to_file(LOGIN_SCENE)


func _get_network_session_username() -> String:
	var network = get_node_or_null("/root/NetworkManager")
	if network != null and network.has_method("get_active_session_username"):
		return str(network.get_active_session_username()).strip_edges()
	return ""


# ---------------------------------------------------------------------------
# Landfill seasonal event: lobby-driven status polling, join, and leaderboard.
# ---------------------------------------------------------------------------

func _add_landfill_buttons() -> void:
	# The event is presented as an icon card on the right margin -- the badge art carries the
	# branding the old wide yellow "JOIN THE LANDFILL RACE" bar was doing in words, and the green
	# "Go Green!" button underneath is the single join entry point. Deliberately ONE way in: two
	# controls firing the same request invites a double-join race between them.
	landfill_event_card = Control.new()
	landfill_event_card.name = "LandfillEventCard"
	# PRESET_TOP_RIGHT makes both horizontal anchors the right edge, so the offsets below are
	# measured leftward from that edge and the card stays glued to the corner.
	landfill_event_card.set_anchors_preset(Control.PRESET_TOP_RIGHT, false)
	landfill_event_card.offset_left = -(LANDFILL_CARD_W + LANDFILL_CARD_MARGIN)
	landfill_event_card.offset_right = -LANDFILL_CARD_MARGIN
	landfill_event_card.offset_top = LANDFILL_CARD_MARGIN
	landfill_event_card.offset_bottom = LANDFILL_CARD_MARGIN + LANDFILL_CARD_H
	landfill_event_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Gated on the event window exactly like the old join button was, so players are never shown a
	# join control that would only refuse them.
	landfill_event_card.visible = landfill_event_active
	add_child(landfill_event_card)

	var icon_texture: Texture2D = null
	if ResourceLoader.exists(LANDFILL_EVENT_ICON_PATH):
		icon_texture = load(LANDFILL_EVENT_ICON_PATH) as Texture2D

	if icon_texture != null:
		var icon_rect := TextureRect.new()
		icon_rect.name = "EventIcon"
		icon_rect.texture = icon_texture
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.position = Vector2.ZERO
		icon_rect.size = Vector2(LANDFILL_CARD_W, LANDFILL_ICON_H)
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		landfill_event_card.add_child(icon_rect)
	else:
		# Missing art must not cost the player the ability to join, so fall back to a text badge
		# rather than leaving an invisible gap above the button.
		var fallback := Label.new()
		fallback.name = "EventIconFallback"
		fallback.text = "LANDFILL EVENT"
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback.position = Vector2.ZERO
		fallback.size = Vector2(LANDFILL_CARD_W, LANDFILL_ICON_H)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		PixelUIStyle.apply_label_shadow(fallback, 18, PixelUIStyle.GOLD_SOFT)
		landfill_event_card.add_child(fallback)

	landfill_join_button = Button.new()
	landfill_join_button.name = "LandfillJoinButton"
	landfill_join_button.text = "Go Green!"
	landfill_join_button.position = Vector2(0.0, LANDFILL_ICON_H + 8.0)
	landfill_join_button.size = Vector2(LANDFILL_CARD_W, LANDFILL_CARD_BUTTON_H)
	landfill_join_button.tooltip_text = "Join the Landfill Race"
	# Parented to the card, so toggling the card's visibility governs the button too and the two
	# can never disagree about whether the event is joinable.
	landfill_join_button.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_green_button(landfill_join_button, 20)
	landfill_join_button.pressed.connect(_on_landfill_join_pressed)
	landfill_event_card.add_child(landfill_join_button)


func _connect_landfill_feed() -> void:
	var network = get_node_or_null("/root/NetworkManager")
	if network == null:
		return

	var status_callback := Callable(self, "_on_landfill_status_received")
	if network.has_signal("landfill_status_received") and not network.is_connected("landfill_status_received", status_callback):
		network.connect("landfill_status_received", status_callback)

	var join_callback := Callable(self, "_on_landfill_join_result_received")
	if network.has_signal("landfill_join_result_received") and not network.is_connected("landfill_join_result_received", join_callback):
		network.connect("landfill_join_result_received", join_callback)


func _start_landfill_status_timer() -> void:
	if landfill_status_timer != null:
		return

	landfill_status_timer = Timer.new()
	landfill_status_timer.name = "LandfillStatusRefreshTimer"
	landfill_status_timer.wait_time = LANDFILL_STATUS_REFRESH_SECONDS
	landfill_status_timer.autostart = true
	landfill_status_timer.timeout.connect(_request_landfill_status_refresh)
	add_child(landfill_status_timer)


func _request_landfill_status_refresh() -> void:
	var network = get_node_or_null("/root/NetworkManager")
	if network == null or not network.has_method("request_landfill_status"):
		return
	network.request_landfill_status()


func _on_landfill_status_received(data: Dictionary) -> void:
	landfill_event_active = bool(data.get("event_active", false))
	landfill_season_key = str(data.get("season_key", "")).strip_edges()

	# Toggle the CARD, not the button: the button is a child of the card, so hiding the card hides
	# the badge art with it. Toggling only the button would leave an orphaned icon advertising an
	# event with no way to enter it.
	if landfill_event_card != null and is_instance_valid(landfill_event_card):
		landfill_event_card.visible = landfill_event_active

	if landfill_join_button != null:
		landfill_join_button.tooltip_text = "Join the Landfill Race" + (" (Season " + landfill_season_key + ")" if landfill_season_key != "" else "")


func _on_landfill_join_pressed() -> void:
	if landfill_join_in_progress or join_scene_change_in_progress:
		return

	var network = get_node_or_null("/root/NetworkManager")
	if network == null or not network.has_method("request_landfill_join"):
		_set_input_status("THE LANDFILL RACE IS UNAVAILABLE RIGHT NOW")
		return

	landfill_join_request_id = "landfill_join_" + str(Time.get_ticks_msec())
	landfill_join_in_progress = true
	_set_input_status("FINDING A LANDFILL RACE INSTANCE...")

	if not bool(network.request_landfill_join(landfill_join_request_id)):
		landfill_join_in_progress = false
		_set_input_status("SIGN IN TO JOIN THE LANDFILL RACE")


func _on_landfill_join_result_received(data: Dictionary) -> void:
	if landfill_join_request_id != "":
		var response_request_id := str(data.get("request_id", "")).strip_edges()
		if response_request_id != "" and response_request_id != landfill_join_request_id:
			return

	landfill_join_in_progress = false

	if bool(data.get("ok", false)):
		var world_name := str(data.get("world_name", "")).strip_edges()
		if world_name != "":
			_join_world_name(world_name)
			return
		_set_input_status("COULD NOT JOIN THE LANDFILL RACE")
		return

	var reason := str(data.get("reason", "")).strip_edges()
	if reason == "event_not_active":
		_set_input_status("THE LANDFILL RACE ISN'T OPEN RIGHT NOW")
	else:
		_set_input_status("COULD NOT JOIN THE LANDFILL RACE")
