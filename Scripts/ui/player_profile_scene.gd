extends "res://Scripts/player_menu_ui.gd"

const PROFILE_BASE_SIZE := Vector2(1060.0, 620.0)
const PROFILE_SCREEN_MARGIN := Vector2(32.0, 32.0)
const MIN_PROFILE_SCALE := 0.42
const MAX_PROFILE_BIO_LENGTH := 160
const SECONDS_PER_DAY := 86400
const PORTRAIT_PREVIEW_SCALE := 5.0

var layout_root: Control = null
var account_id_value_label: Label = null
var player_age_value_label: Label = null
var title_value_label: Label = null
var worlds_value_label: Label = null
var friends_value_label: Label = null
var total_xp_value_label: Label = null
var bio_label: Label = null
var xp_fill: NinePatchRect = null
var portrait_texture: TextureRect = null
var portrait_placeholder_label: Label = null
var portrait_viewport: SubViewport = null
var portrait_preview_root: Node2D = null
var portrait_preview_visual: Node2D = null
var portrait_source_instance_id := 0
var showcase_badge_label: Label = null
var showcase_item_label: Label = null
var showcase_world_label: Label = null
var edit_bio_button_skin: NinePatchRect = null
var edit_bio_button: Button = null
var bio_editor_skin: NinePatchRect = null
var bio_text_edit: TextEdit = null
var bio_save_button: Button = null
var bio_cancel_button: Button = null
var bio_character_count_label: Label = null
var local_profile_data: Dictionary = {}
var local_profile_request_id := ""
var bio_save_request_id := ""
var local_profile_lookup_status := ""
var editing_bio := false
var bio_save_pending := false
var normalizing_bio_text := false


func build_menu():
	layout_root = get_node_or_null("CenterContainer") as Control
	overlay = get_node_or_null("Dimmer")
	panel = get_node_or_null("CenterContainer/ProfileWindow")
	player_name_label = get_node_or_null("%DisplayNameLabel")
	level_label = get_node_or_null("%LevelValueLabel")
	xp_label = get_node_or_null("%XpValueLabel")
	playtime_label = get_node_or_null("%LastSeenValueLabel")
	world_label = get_node_or_null("%WorldsValueLabel")
	account_label = get_node_or_null("%ProfileHandleLabel")
	status_badge_label = get_node_or_null("%OnlineStatusLabel")
	action_panel = get_node_or_null("CenterContainer/ProfileWindow/FooterPanel")
	worlds_button = get_node_or_null("%VisitWorldButton")
	titles_button = null
	trade_button = get_node_or_null("%MessageButton")
	friend_button = get_node_or_null("%PrimaryActionButton")
	close_action_button = null
	account_id_value_label = get_node_or_null("%AccountIdValueLabel") as Label
	player_age_value_label = get_node_or_null("%PlayerAgeValueLabel") as Label
	title_value_label = get_node_or_null("%TitleValueLabel") as Label
	worlds_value_label = get_node_or_null("%WorldsValueLabel") as Label
	friends_value_label = get_node_or_null("%FriendsValueLabel") as Label
	total_xp_value_label = get_node_or_null("%AchievementsValueLabel") as Label
	bio_label = get_node_or_null("%BioLabel") as Label
	xp_fill = get_node_or_null("%XpFill") as NinePatchRect
	portrait_texture = get_node_or_null("%PortraitTexture") as TextureRect
	portrait_viewport = get_node_or_null("%PortraitViewport") as SubViewport
	portrait_preview_root = get_node_or_null("%PortraitPreviewRoot") as Node2D
	portrait_placeholder_label = get_node_or_null("CenterContainer/ProfileWindow/PortraitPanel/PortraitFrame/PortraitPlaceholderLabel") as Label
	showcase_badge_label = get_node_or_null("CenterContainer/ProfileWindow/ShowcasePanel/BadgeSlot/Label") as Label
	showcase_item_label = get_node_or_null("CenterContainer/ProfileWindow/ShowcasePanel/FavoriteItemSlot/Label") as Label
	showcase_world_label = get_node_or_null("%FavoriteWorldNameLabel") as Label
	edit_bio_button_skin = get_node_or_null("%EditBioButtonSkin") as NinePatchRect
	edit_bio_button = get_node_or_null("%EditBioButton") as Button
	bio_editor_skin = get_node_or_null("%BioEditorSkin") as NinePatchRect
	bio_text_edit = get_node_or_null("%BioTextEdit") as TextEdit
	bio_save_button = get_node_or_null("%BioSaveButton") as Button
	bio_cancel_button = get_node_or_null("%BioCancelButton") as Button
	bio_character_count_label = get_node_or_null("%BioCharacterCountLabel") as Label

	_set_caption("CenterContainer/ProfileWindow/StatsPanel/WorldsCell/Caption", "CURRENT WORLD")
	_set_caption("CenterContainer/ProfileWindow/StatsPanel/AchievementsCell/Caption", "TOTAL XP")
	_configure_xp_fill()
	_configure_portrait_preview()
	_connect_profile_buttons()

	if panel != null:
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		var panel_input := Callable(self, "_on_panel_gui_input")
		if not panel.gui_input.is_connected(panel_input):
			panel.gui_input.connect(panel_input)

	create_locked_worlds_panel()
	update_position()
	update_menu_info()


func _connect_profile_buttons() -> void:
	var close_button := get_node_or_null("%CloseButton") as Button
	if close_button != null:
		var close_callback := Callable(self, "close_menu")
		if not close_button.pressed.is_connected(close_callback):
			close_button.pressed.connect(close_callback)

	if trade_button != null:
		var trade_callback := Callable(self, "_on_profile_trade_pressed")
		if not trade_button.pressed.is_connected(trade_callback):
			trade_button.pressed.connect(trade_callback)
	if worlds_button != null:
		var world_callback := Callable(self, "_on_profile_world_pressed")
		if not worlds_button.pressed.is_connected(world_callback):
			worlds_button.pressed.connect(world_callback)
	if friend_button != null:
		var friend_callback := Callable(self, "_on_friend_pressed")
		if not friend_button.pressed.is_connected(friend_callback):
			friend_button.pressed.connect(friend_callback)
	if edit_bio_button != null:
		var edit_bio_callback := Callable(self, "_on_edit_bio_pressed")
		if not edit_bio_button.pressed.is_connected(edit_bio_callback):
			edit_bio_button.pressed.connect(edit_bio_callback)
	if bio_save_button != null:
		var save_bio_callback := Callable(self, "_on_bio_save_pressed")
		if not bio_save_button.pressed.is_connected(save_bio_callback):
			bio_save_button.pressed.connect(save_bio_callback)
	if bio_cancel_button != null:
		var cancel_bio_callback := Callable(self, "_on_bio_cancel_pressed")
		if not bio_cancel_button.pressed.is_connected(cancel_bio_callback):
			bio_cancel_button.pressed.connect(cancel_bio_callback)
	if bio_text_edit != null:
		var bio_text_callback := Callable(self, "_on_bio_text_changed")
		if not bio_text_edit.text_changed.is_connected(bio_text_callback):
			bio_text_edit.text_changed.connect(bio_text_callback)
func _configure_xp_fill() -> void:
	if xp_fill == null:
		return
	xp_fill.anchor_left = 0.0
	xp_fill.anchor_top = 0.0
	xp_fill.anchor_bottom = 1.0
	xp_fill.offset_left = 0.0
	xp_fill.offset_top = 0.0
	xp_fill.offset_right = 0.0
	xp_fill.offset_bottom = 0.0
	xp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _configure_portrait_preview() -> void:
	if portrait_viewport == null or portrait_texture == null:
		return
	portrait_viewport.transparent_bg = true
	portrait_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	portrait_texture.texture = portrait_viewport.get_texture()


func _set_caption(path: NodePath, text: String) -> void:
	var label := get_node_or_null(path) as Label
	if label != null:
		label.text = text


func update_position():
	var screen_size := get_viewport_rect().size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return

	if layout_root != null:
		var available := Vector2(
			maxf(1.0, screen_size.x - PROFILE_SCREEN_MARGIN.x),
			maxf(1.0, screen_size.y - PROFILE_SCREEN_MARGIN.y)
		)
		var profile_scale := clampf(
			minf(available.x / PROFILE_BASE_SIZE.x, available.y / PROFILE_BASE_SIZE.y),
			MIN_PROFILE_SCALE,
			1.0
		)
		layout_root.pivot_offset = layout_root.size * 0.5
		layout_root.scale = Vector2.ONE * profile_scale

	if locked_worlds_panel != null:
		locked_worlds_panel.position = Vector2(
			(screen_size.x - locked_worlds_panel.size.x) * 0.5,
			(screen_size.y - locked_worlds_panel.size.y) * 0.5
		)


func update_menu_info():
	if world == null:
		return

	update_position()
	update_action_buttons()

	var profile_data: Dictionary = get_active_profile_data()
	var equipment_data: Dictionary = get_active_equipment_data(profile_data)
	var profile_name := get_display_profile_name().strip_edges()
	if profile_name == "":
		profile_name = "Player"
	var is_remote := profile_mode == "remote"
	var has_progression := not is_remote or profile_data.has("player_data_version") or profile_data.has("player_level") or profile_data.has("level")
	var level := int(profile_data.get("player_level", profile_data.get("level", 1)))
	var xp_value := int(profile_data.get("player_xp", profile_data.get("xp", 0)))
	var xp_needed := int(profile_data.get("player_xp_needed", profile_data.get("xp_needed", 300)))
	var total_xp := int(profile_data.get("player_total_xp", profile_data.get("total_xp", 0)))
	var player_title := str(profile_data.get("player_title", "Explorer")).strip_edges()

	if not is_remote:
		level = int(world.get("player_level"))
		xp_value = int(world.get("player_xp"))
		xp_needed = int(world.get("player_xp_needed"))
		total_xp = int(world.get("player_total_xp"))
		player_title = str(world.get("player_title")).strip_edges()
	if player_title == "":
		player_title = "Explorer"

	var current_world := _get_profile_world_name()
	var profile_status := _get_profile_status_text()
	var last_seen := _get_profile_last_seen_text()

	if player_name_label != null:
		player_name_label.text = profile_name.to_upper()
	if account_label != null:
		account_label.text = "@" + profile_name.to_upper()
	if status_badge_label != null:
		status_badge_label.text = profile_status
		status_badge_label.add_theme_color_override("font_color", _get_profile_status_color())
	if title_value_label != null:
		title_value_label.text = player_title.to_upper()
	if level_label != null:
		level_label.text = str(level) if has_progression else "--"
	if worlds_value_label != null:
		worlds_value_label.text = current_world.to_upper() if current_world != "" else "--"
	if friends_value_label != null:
		friends_value_label.text = _get_profile_friends_text()
	if total_xp_value_label != null:
		total_xp_value_label.text = _format_compact_number(total_xp) if has_progression else "--"
	if xp_label != null:
		xp_label.text = _format_xp_text(xp_value, xp_needed) if has_progression else "-- / --"
	if xp_fill != null:
		xp_fill.anchor_right = _get_xp_ratio(xp_value, xp_needed) if has_progression else 0.0
	if account_id_value_label != null:
		account_id_value_label.text = _get_profile_id_text()
	if player_age_value_label != null:
		player_age_value_label.text = _get_profile_age_text(profile_data)
	if playtime_label != null:
		playtime_label.text = last_seen
	if bio_label != null:
		bio_label.text = _get_profile_bio_text(profile_data, profile_name)
	_update_bio_editor_visibility()
	_update_portrait_preview()

	if portrait_placeholder_label != null:
		portrait_placeholder_label.visible = portrait_preview_visual == null or not is_instance_valid(portrait_preview_visual)
		portrait_placeholder_label.text = profile_name.substr(0, 1).to_upper()
	if showcase_badge_label != null:
		showcase_badge_label.text = player_title.to_upper()
		showcase_badge_label.clip_text = true
	if showcase_item_label != null:
		showcase_item_label.text = format_profile_item_name(str(equipment_data.get("hand", ""))).to_upper()
		showcase_item_label.clip_text = true
	if showcase_world_label != null:
		showcase_world_label.text = current_world.to_upper() if current_world != "" else "NO WORLD"
		showcase_world_label.clip_text = true


func _get_profile_world_name() -> String:
	if profile_mode == "remote":
		return str(remote_profile_data.get("world", remote_profile_data.get("current_world", ""))).strip_edges()
	if world != null and world.has_method("get_current_world_display_name"):
		return str(world.get_current_world_display_name()).strip_edges()
	return str(world.get("current_world_name")).strip_edges() if world != null else ""


func _get_profile_status_text() -> String:
	if profile_mode != "remote":
		return "ONLINE"
	match remote_profile_lookup_status:
		"loading":
			return "CHECKING"
		"missing":
			return "NOT FOUND"
	return "ONLINE" if is_remote_profile_online() else "OFFLINE"


func _get_profile_status_color() -> Color:
	var status := _get_profile_status_text()
	match status:
		"ONLINE":
			return Color(0.44, 0.94, 0.66, 1.0)
		"CHECKING":
			return Color(0.95, 0.81, 0.28, 1.0)
		"NOT FOUND":
			return Color(1.0, 0.43, 0.43, 1.0)
		_:
			return Color(0.58, 0.68, 0.78, 1.0)


func _get_profile_last_seen_text() -> String:
	if profile_mode != "remote":
		return "NOW"
	if remote_profile_lookup_status == "loading":
		return "CHECKING"
	if remote_profile_lookup_status == "missing":
		return "NOT FOUND"
	if is_remote_profile_online():
		return "NOW"
	var last_seen := str(remote_profile_data.get("last_seen_at", "")).strip_edges()
	return format_profile_date(last_seen) if last_seen != "" else "OFFLINE"


func _get_profile_friends_text() -> String:
	if profile_mode == "remote":
		match get_remote_friend_status():
			"friends":
				return "FRIENDS"
			"incoming":
				return "REQUEST"
			"outgoing":
				return "PENDING"
			"self":
				return "YOU"
			_:
				return "NOT ADDED"

	var friends_ui_node = world.get("friends_ui") if world != null else null
	if friends_ui_node != null:
		var entries = friends_ui_node.get("friends")
		if entries is Array:
			return str(entries.size())
	return "--"


func _get_profile_id_text() -> String:
	var raw_id := ""
	if profile_mode == "remote":
		raw_id = str(remote_profile_data.get("player_id", "")).strip_edges()
	else:
		var network := get_node_or_null("/root/NetworkManager")
		if network != null and network.has_method("get_active_profile_id"):
			raw_id = str(network.get_active_profile_id()).strip_edges()
		if raw_id == "" and network != null and network.has_method("get_active_game_player_id"):
			raw_id = str(network.get_active_game_player_id()).strip_edges()
	return _shorten_id(raw_id)


func _shorten_id(raw_id: String) -> String:
	var clean_id := raw_id.strip_edges()
	if clean_id == "":
		return "--"
	if clean_id.length() <= 14:
		return clean_id
	return clean_id.substr(0, 6) + "..." + clean_id.substr(clean_id.length() - 4, 4)


func _get_profile_age_text(profile_data: Dictionary) -> String:
	var age_days := _get_account_age_days(profile_data)
	if age_days < 0:
		return "--"
	return str(age_days) + (" DAY" if age_days == 1 else " DAYS")


func _get_account_age_days(profile_data: Dictionary) -> int:
	var created_at := _get_profile_created_at(profile_data)
	if created_at.length() < 10:
		return -1
	var created_date := created_at.left(10)
	var date_parts := created_date.split("-")
	if date_parts.size() != 3:
		return -1
	var created_year := int(date_parts[0])
	var created_month := int(date_parts[1])
	var created_day := int(date_parts[2])
	if created_year < 1970 or created_month < 1 or created_month > 12 or created_day < 1 or created_day > 31:
		return -1

	var created_midnight := int(Time.get_unix_time_from_datetime_dict({
		"year": created_year,
		"month": created_month,
		"day": created_day,
		"hour": 0,
		"minute": 0,
		"second": 0
	}))
	var today := Time.get_datetime_dict_from_system(true)
	var today_midnight := int(Time.get_unix_time_from_datetime_dict({
		"year": int(today.get("year", 1970)),
		"month": int(today.get("month", 1)),
		"day": int(today.get("day", 1)),
		"hour": 0,
		"minute": 0,
		"second": 0
	}))
	if created_midnight <= 0 or created_midnight > today_midnight:
		return 0 if created_midnight > today_midnight else -1
	return int((today_midnight - created_midnight) / SECONDS_PER_DAY)


func _get_profile_created_at(profile_data: Dictionary) -> String:
	var candidates: Array = [profile_data.get("created_at", "")]
	if profile_mode == "remote":
		candidates.append(remote_profile_data.get("created_at", ""))
		candidates.append(remote_profile_data.get("account", {}))
	else:
		candidates.append(local_profile_data.get("created_at", ""))
		candidates.append(local_profile_data.get("account", {}))
	for candidate in candidates:
		if candidate is Dictionary:
			var nested_created_at := str(candidate.get("created_at", "")).strip_edges()
			if nested_created_at != "":
				return nested_created_at
		else:
			var direct_created_at := str(candidate).strip_edges()
			if direct_created_at != "":
				return direct_created_at
	return ""


func _update_portrait_preview() -> void:
	if portrait_viewport == null or portrait_preview_root == null or portrait_texture == null:
		return
	var source_visual := _get_portrait_source_visual()
	if source_visual == null or not is_instance_valid(source_visual):
		_clear_portrait_preview()
		return

	var source_instance_id := source_visual.get_instance_id()
	if portrait_preview_visual == null or not is_instance_valid(portrait_preview_visual) or portrait_source_instance_id != source_instance_id:
		_rebuild_portrait_preview(source_visual)
		return

	_sync_portrait_visual(source_visual, portrait_preview_visual, false)
	_apply_portrait_preview_transform(source_visual)


func _get_portrait_source_visual() -> Node2D:
	if world == null:
		return null
	if profile_mode != "remote":
		var local_player: Variant = world.get("player")
		if local_player is Node:
			return local_player.get_node_or_null("PlayerVisual") as Node2D
		return null

	var target_id := str(remote_profile_data.get("player_id", "")).strip_edges()
	var target_name := str(remote_profile_data.get("username", remote_profile_data.get("name", ""))).strip_edges().to_lower()
	var player_manager_value: Variant = world.get("player_manager")
	if player_manager_value is Node:
		var remote_players_value: Variant = player_manager_value.get("remote_players")
		if remote_players_value is Dictionary:
			var remote_players: Dictionary = remote_players_value
			if target_id != "" and remote_players.has(target_id):
				var direct_player: Variant = remote_players.get(target_id)
				if direct_player is Node:
					return direct_player.get_node_or_null("PlayerVisual") as Node2D
			for remote_player_value in remote_players.values():
				if not (remote_player_value is Node) or not is_instance_valid(remote_player_value):
					continue
				var remote_player := remote_player_value as Node
				var remote_name := str(remote_player.get_meta("remote_name", "")).strip_edges().to_lower()
				if target_name != "" and remote_name == target_name:
					return remote_player.get_node_or_null("PlayerVisual") as Node2D

	var remote_root: Node = world.get_node_or_null("RemotePlayers")
	if remote_root != null:
		for remote_player in remote_root.get_children():
			var remote_id := str(remote_player.get_meta("remote_id", "")).strip_edges()
			var remote_name := str(remote_player.get_meta("remote_name", "")).strip_edges().to_lower()
			if (target_id != "" and remote_id == target_id) or (target_name != "" and remote_name == target_name):
				return remote_player.get_node_or_null("PlayerVisual") as Node2D
	return null


func _rebuild_portrait_preview(source_visual: Node2D) -> void:
	_clear_portrait_preview()
	var duplicated_visual := source_visual.duplicate()
	if not (duplicated_visual is Node2D):
		if duplicated_visual != null:
			duplicated_visual.free()
		return
	portrait_preview_visual = duplicated_visual as Node2D
	portrait_preview_visual.name = "PreviewPlayerVisual"
	portrait_preview_root.add_child(portrait_preview_visual)
	portrait_source_instance_id = source_visual.get_instance_id()
	_sync_portrait_visual(source_visual, portrait_preview_visual, false)
	_apply_portrait_preview_transform(source_visual)
	portrait_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	portrait_texture.texture = portrait_viewport.get_texture()


func _apply_portrait_preview_transform(source_visual: Node2D) -> void:
	if portrait_preview_visual == null or not is_instance_valid(portrait_preview_visual):
		return
	var facing_sign := -1.0 if source_visual.scale.x < 0.0 else 1.0
	portrait_preview_visual.position = Vector2.ZERO
	portrait_preview_visual.rotation = 0.0
	portrait_preview_visual.skew = 0.0
	portrait_preview_visual.scale = Vector2(PORTRAIT_PREVIEW_SCALE * facing_sign, PORTRAIT_PREVIEW_SCALE)


func _sync_portrait_visual(source_node: Node, preview_node: Node, sync_transform: bool = true) -> void:
	if source_node is CanvasItem and preview_node is CanvasItem:
		var source_canvas := source_node as CanvasItem
		var preview_canvas := preview_node as CanvasItem
		preview_canvas.visible = source_canvas.visible
		preview_canvas.modulate = source_canvas.modulate
		preview_canvas.self_modulate = source_canvas.self_modulate
		preview_canvas.z_index = source_canvas.z_index
		preview_canvas.z_as_relative = source_canvas.z_as_relative
	if sync_transform and source_node is Node2D and preview_node is Node2D:
		var source_2d := source_node as Node2D
		var preview_2d := preview_node as Node2D
		preview_2d.position = source_2d.position
		preview_2d.rotation = source_2d.rotation
		preview_2d.scale = source_2d.scale
		preview_2d.skew = source_2d.skew
	if source_node is AnimatedSprite2D and preview_node is AnimatedSprite2D:
		var source_animated := source_node as AnimatedSprite2D
		var preview_animated := preview_node as AnimatedSprite2D
		preview_animated.sprite_frames = source_animated.sprite_frames
		preview_animated.animation = source_animated.animation
		preview_animated.frame = source_animated.frame
		preview_animated.frame_progress = source_animated.frame_progress
		preview_animated.flip_h = source_animated.flip_h
		preview_animated.flip_v = source_animated.flip_v
		preview_animated.offset = source_animated.offset
	if source_node is Sprite2D and preview_node is Sprite2D:
		var source_sprite := source_node as Sprite2D
		var preview_sprite := preview_node as Sprite2D
		preview_sprite.texture = source_sprite.texture
		preview_sprite.frame = source_sprite.frame
		preview_sprite.flip_h = source_sprite.flip_h
		preview_sprite.flip_v = source_sprite.flip_v
		preview_sprite.offset = source_sprite.offset

	for source_child in source_node.get_children():
		var preview_child := preview_node.get_node_or_null(NodePath(str(source_child.name)))
		if preview_child != null:
			_sync_portrait_visual(source_child, preview_child, true)


func _clear_portrait_preview() -> void:
	if portrait_preview_visual != null and is_instance_valid(portrait_preview_visual):
		if portrait_preview_visual.get_parent() != null:
			portrait_preview_visual.get_parent().remove_child(portrait_preview_visual)
		portrait_preview_visual.queue_free()
	portrait_preview_visual = null
	portrait_source_instance_id = 0


func _get_profile_bio_text(profile_data: Dictionary, profile_name: String) -> String:
	if profile_mode == "remote":
		if remote_profile_lookup_status == "loading":
			return "Loading " + profile_name + "'s public profile..."
		if remote_profile_lookup_status == "missing":
			return "No public profile was found for " + profile_name + "."
	var profile_bio := _get_profile_bio(profile_data)
	if profile_bio != "":
		return profile_bio
	if profile_mode == "remote":
		return "No bio has been added."
	if local_profile_lookup_status == "loading":
		return "Loading profile..."
	return "No bio yet. Select EDIT to add one."


func _get_profile_bio(profile_data: Dictionary) -> String:
	var profile_bio := str(profile_data.get("profile_bio", "")).strip_edges()
	if profile_mode == "remote":
		profile_bio = str(remote_profile_data.get("profile_bio", "")).strip_edges()
		if profile_data.has("profile_bio"):
			profile_bio = str(profile_data["profile_bio"]).strip_edges()
	else:
		profile_bio = str(_get_local_profile_value("profile_bio", profile_bio)).strip_edges()
	return profile_bio.left(MAX_PROFILE_BIO_LENGTH)


func _get_local_profile_value(key: String, fallback: Variant) -> Variant:
	if local_profile_data.has(key):
		return local_profile_data[key]
	var nested: Variant = local_profile_data.get("player_data", {})
	if nested is Dictionary and nested.has(key):
		return nested[key]
	return fallback


func _update_bio_editor_visibility() -> void:
	if profile_mode == "remote":
		editing_bio = false
	var can_edit := profile_mode != "remote"
	if edit_bio_button_skin != null:
		edit_bio_button_skin.visible = can_edit and not editing_bio
	if edit_bio_button != null:
		edit_bio_button.visible = can_edit and not editing_bio
		edit_bio_button.disabled = bio_save_pending
	if bio_label != null:
		bio_label.visible = not editing_bio
	if bio_editor_skin != null:
		bio_editor_skin.visible = can_edit and editing_bio
	if bio_save_button != null:
		bio_save_button.disabled = bio_save_pending
	if bio_cancel_button != null:
		bio_cancel_button.disabled = bio_save_pending


func _on_edit_bio_pressed() -> void:
	if profile_mode == "remote" or bio_save_pending:
		return
	var profile_data := get_active_profile_data()
	if bio_text_edit != null:
		bio_text_edit.text = _get_profile_bio(profile_data)
	editing_bio = true
	_update_bio_character_count()
	_update_bio_editor_visibility()
	if bio_text_edit != null:
		bio_text_edit.grab_focus()


func _on_bio_cancel_pressed() -> void:
	if bio_save_pending:
		return
	editing_bio = false
	_update_bio_editor_visibility()


func _on_bio_save_pressed() -> void:
	if profile_mode == "remote" or bio_save_pending:
		return
	var network := get_node_or_null("/root/NetworkManager")
	if network == null or not network.has_method("send_player_profile_update"):
		notify("Profile saving is not available right now.")
		return
	var profile_bio := bio_text_edit.text if bio_text_edit != null else ""
	var request_id := str(network.send_player_profile_update(profile_bio, {
		"operation": "save"
	}))
	if request_id == "":
		notify("Could not send your profile update. Try again.")
		return
	bio_save_request_id = request_id
	bio_save_pending = true
	_update_bio_editor_visibility()
	call_deferred("_wait_for_bio_save", request_id)


func _on_bio_text_changed() -> void:
	if bio_text_edit == null or normalizing_bio_text:
		return
	if bio_text_edit.text.length() > MAX_PROFILE_BIO_LENGTH:
		normalizing_bio_text = true
		bio_text_edit.text = bio_text_edit.text.left(MAX_PROFILE_BIO_LENGTH)
		normalizing_bio_text = false
	_update_bio_character_count()


func _update_bio_character_count() -> void:
	if bio_character_count_label == null:
		return
	var length := bio_text_edit.text.length() if bio_text_edit != null else 0
	bio_character_count_label.text = str(length) + " / " + str(MAX_PROFILE_BIO_LENGTH)


func open_menu():
	editing_bio = false
	bio_save_pending = false
	bio_save_request_id = ""
	local_profile_data.clear()
	local_profile_lookup_status = "loading"
	if portrait_viewport != null:
		portrait_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	super.open_menu()
	_request_local_profile_details()


func open_remote_profile(player_data: Dictionary):
	editing_bio = false
	bio_save_pending = false
	bio_save_request_id = ""
	if portrait_viewport != null:
		portrait_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	super.open_remote_profile(player_data)


func close_menu():
	editing_bio = false
	_clear_portrait_preview()
	if portrait_viewport != null:
		portrait_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	super.close_menu()


func _request_local_profile_details() -> void:
	var network := get_node_or_null("/root/NetworkManager")
	if network == null or not network.has_method("send_player_state_request_with_context"):
		local_profile_lookup_status = "unavailable"
		update_menu_info()
		return
	var username := get_display_profile_name().strip_edges()
	var request_id := str(network.send_player_state_request_with_context(username, {
		"purpose": "local_player_profile",
		"username": username,
		"requested_username": username,
		"operation": "lookup"
	}))
	if request_id == "":
		local_profile_lookup_status = "unavailable"
		update_menu_info()
		return
	local_profile_request_id = request_id
	call_deferred("_wait_for_local_profile_lookup", request_id)


func handle_player_state_lookup_result(request_id: String, data: Dictionary, request_context: Dictionary = {}):
	var purpose := str(request_context.get("purpose", "")).strip_edges().to_lower()
	if purpose != "local_player_profile":
		super.handle_player_state_lookup_result(request_id, data, request_context)
		return

	var operation := str(request_context.get("operation", "")).strip_edges().to_lower()
	var nested_context: Variant = request_context.get("context", {})
	if operation == "" and nested_context is Dictionary:
		operation = str(nested_context.get("operation", "")).strip_edges().to_lower()
	if operation == "save" and bio_save_request_id != "" and request_id != "" and request_id != bio_save_request_id:
		return
	if operation != "save" and local_profile_request_id != "" and request_id != "" and request_id != local_profile_request_id:
		return

	if not bool(data.get("ok", str(data.get("type", "")).to_lower() != "action_rejected")):
		if operation == "save":
			bio_save_pending = false
			bio_save_request_id = ""
			notify(str(data.get("message", "Could not save your profile.")))
		else:
			local_profile_lookup_status = "unavailable"
			local_profile_request_id = ""
		_update_bio_editor_visibility()
		return

	local_profile_data = data.duplicate(true)
	local_profile_lookup_status = "loaded"
	local_profile_request_id = ""
	if operation == "save":
		bio_save_pending = false
		bio_save_request_id = ""
		editing_bio = false
		notify(str(data.get("message", "Profile saved.")))
	update_menu_info()


func _wait_for_local_profile_lookup(request_id: String) -> void:
	await get_tree().create_timer(REMOTE_PROFILE_LOOKUP_TIMEOUT).timeout
	if local_profile_request_id != request_id or local_profile_lookup_status != "loading":
		return
	local_profile_request_id = ""
	local_profile_lookup_status = "unavailable"
	update_menu_info()


func _wait_for_bio_save(request_id: String) -> void:
	await get_tree().create_timer(REMOTE_PROFILE_LOOKUP_TIMEOUT).timeout
	if bio_save_request_id != request_id or not bio_save_pending:
		return
	bio_save_request_id = ""
	bio_save_pending = false
	_update_bio_editor_visibility()
	notify("Profile save timed out. Try again.")


func _format_xp_text(xp_value: int, xp_needed: int) -> String:
	if xp_needed <= 0:
		return "MAX"
	return str(maxi(0, xp_value)) + " / " + str(maxi(1, xp_needed))


func _get_xp_ratio(xp_value: int, xp_needed: int) -> float:
	if xp_needed <= 0:
		return 1.0
	return clampf(float(maxi(0, xp_value)) / float(maxi(1, xp_needed)), 0.0, 1.0)


func _format_compact_number(value: int) -> String:
	var amount := maxi(0, value)
	if amount >= 1000000:
		return "%.1fM" % (float(amount) / 1000000.0)
	if amount >= 1000:
		return "%.1fK" % (float(amount) / 1000.0)
	return str(amount)


func update_action_buttons():
	var visible_buttons: Array[Button] = []
	if profile_mode != "remote":
		_set_action_button(trade_button, false, false, "TRADE")
		_set_action_button(friend_button, false, false, "ADD FRIEND")
		_set_action_button(worlds_button, true, false, "MY WORLDS")
		visible_buttons.append(worlds_button)
		_layout_action_buttons(visible_buttons)
		return

	var remote_online := is_remote_profile_online()
	var has_pending_trade: bool = bool(world != null and world.has_method("has_pending_trade_from_player") and world.has_pending_trade_from_player(remote_profile_data))
	var friend_status := get_remote_friend_status()
	var profile_exists := remote_profile_lookup_status != "missing"
	var remote_username := str(remote_profile_data.get("username", remote_profile_data.get("name", ""))).strip_edges()
	var target_world := _get_profile_world_name()
	var local_world := str(world.get("current_world_name")).strip_edges() if world != null else ""
	var already_here := target_world != "" and local_world != "" and target_world.to_upper() == local_world.to_upper()

	_set_action_button(trade_button, remote_online, false, "ACCEPT TRADE" if has_pending_trade else "TRADE")
	_set_action_button(worlds_button, remote_online and target_world != "", already_here, "CURRENT WORLD" if already_here else "VISIT WORLD")
	_set_action_button(friend_button, profile_exists and remote_username != "" and friend_status != "self", friend_status == "outgoing" or friend_status == "friends", _friend_button_text(friend_status))

	for button in [trade_button, worlds_button, friend_button]:
		if button != null and button.get_parent() != null and button.get_parent().visible:
			visible_buttons.append(button)
	_layout_action_buttons(visible_buttons)


func _friend_button_text(friend_status: String) -> String:
	match friend_status:
		"friends":
			return "FRIENDS"
		"outgoing":
			return "PENDING"
		"incoming":
			return "ACCEPT FRIEND"
		_:
			return "ADD FRIEND"


func _set_action_button(button: Button, should_show: bool, should_disable: bool, button_text: String) -> void:
	if button == null:
		return
	var skin := button.get_parent() as NinePatchRect
	if skin != null:
		skin.visible = should_show
		skin.modulate = Color(0.62, 0.68, 0.76, 0.78) if should_disable else Color.WHITE
	button.visible = should_show
	button.disabled = should_disable
	button.text = button_text


func _layout_action_buttons(buttons: Array[Button]) -> void:
	if action_panel == null or buttons.is_empty():
		return
	var gap := 10.0
	var widths: Array[float] = []
	var total_width := 0.0
	for button in buttons:
		var width := 208.0 if button == friend_button else 196.0
		widths.append(width)
		total_width += width
	total_width += gap * float(maxi(0, buttons.size() - 1))
	var x: float = action_panel.size.x - 16.0 - total_width
	for index in range(buttons.size()):
		var skin := buttons[index].get_parent() as NinePatchRect
		if skin == null:
			continue
		skin.position = Vector2(x, 6.0)
		skin.size = Vector2(widths[index], 38.0)
		x += widths[index] + gap


func _on_profile_trade_pressed() -> void:
	_on_trade_pressed()


func _on_profile_world_pressed() -> void:
	if profile_mode != "remote":
		open_locked_worlds_panel()
		return

	var target_world := _get_profile_world_name()
	if target_world == "":
		notify("That player is not currently in a world.")
		return
	var current_world := str(world.get("current_world_name")).strip_edges() if world != null else ""
	if current_world != "" and current_world.to_upper() == target_world.to_upper():
		notify("You are already in " + target_world.to_upper() + ".")
		return
	if world != null and world.has_method("enter_world_by_name"):
		close_menu()
		world.enter_world_by_name(target_world)
		return
	notify("World travel is not available right now.")
