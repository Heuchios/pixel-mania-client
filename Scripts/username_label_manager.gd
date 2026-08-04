extends Node

# PixelMania Username Label Manager v2
#
# Renders the username above the player using a Label inside the UI CanvasLayer.
# Automatically hides behind blocking UI panels so it never bleeds through popups.

const LABEL_WIDTH = 300.0
const LABEL_HEIGHT = 34.0
const GROWTH_LABEL_WIDTH = 360.0
const GROWTH_LABEL_HEIGHT = 46.0
const LABEL_MARGIN_ABOVE_HEAD_WORLD_PX = 18.0
const FALLBACK_OFFSET_ABOVE_PLAYER_WORLD_PX = 66.0
const USERNAME_FONT_PATH = "res://Assets/font/font.ttf"
const USERNAME_FONT_SIZE_META := &"pixelmania_font_size"
const FONT_SIZE = 28
const OUTLINE_SIZE = 10
const GROWTH_FONT_SIZE = 17
const GROWTH_OUTLINE_SIZE = 5
const GROWTH_LABEL_GAP = 1.0
const LOCAL_USERNAME_Z_INDEX = 73
const LOCAL_GROWTH_LABEL_Z_INDEX = 74
const TREE_TEXT_FADE_IN_SPEED = 8.0
const TREE_TEXT_FADE_OUT_SPEED = 6.0
const RAINBOW_SPEED = 0.22
const WORLD_LOCK_OWNER_COLOR = Color(1.0, 0.623529, 0.109804, 1.0)
const SUPER_WORLD_LOCK_OWNER_COLOR = Color(1.0, 0.08, 0.82, 1.0)
const WORLD_LOCK_ACCESS_COLOR = Color(1.0, 0.768627, 0.419608, 1.0)
const DEFAULT_USERNAME_COLOR = Color(1.0, 1.0, 1.0, 1.0)
const DEFAULT_USERNAME_OUTLINE_COLOR = Color(0.0, 0.0, 0.0, 0.92)
const DEFAULT_USERNAME_SHADOW_COLOR = Color(0.0, 0.0, 0.0, 0.55)
const PURPLE_GLOW_USERNAME_KEY = "white"
const PURPLE_GLOW_USERNAME_COLOR = Color(0.92, 0.48, 1.0, 1.0)
const PURPLE_GLOW_USERNAME_COLOR_BRIGHT = Color(1.0, 0.72, 1.0, 1.0)
const PURPLE_GLOW_OUTLINE_COLOR = Color(0.52, 0.04, 1.0, 0.96)
const PURPLE_GLOW_OUTLINE_COLOR_BRIGHT = Color(0.86, 0.24, 1.0, 1.0)
const PURPLE_GLOW_SHADOW_COLOR = Color(0.48, 0.0, 1.0, 0.82)
const PURPLE_GLOW_SHADOW_COLOR_BRIGHT = Color(0.78, 0.18, 1.0, 0.96)
const PURPLE_GLOW_PULSE_SPEED = 3.0
const GROWTH_TIMER_COLOR = Color(1.0, 0.92, 0.38, 1.0)
const GROWTH_READY_COLOR = Color(0.44, 1.0, 0.42, 1.0)

var world = null
var label: Label = null
var growth_label: Label = null
var rainbow_time := 0.0
var growth_label_alpha := 0.0
var username_font: Font = null


func get_network_manager():
	if not is_inside_tree():
		return null

	return get_tree().root.get_node_or_null("NetworkManager")


func get_username_font() -> Font:
	if username_font == null and ResourceLoader.exists(USERNAME_FONT_PATH):
		var loaded_font: Resource = load(USERNAME_FONT_PATH)
		if loaded_font is Font:
			username_font = loaded_font
	return username_font


func apply_username_font_to_label(target_label: Label) -> void:
	if target_label == null:
		return

	var font := get_username_font()
	if font == null:
		return

	target_label.add_theme_font_override("font", font)
	if target_label.label_settings != null:
		target_label.label_settings.font = font


func setup(world_ref):
	world = world_ref
	_create_label()
	update_text()


func get_overhead_layer():
	if world == null:
		return null
	if world.has_method("get_ui_overhead_layer"):
		return world.get_ui_overhead_layer()
	if "ui_layer" in world:
		return world.ui_layer
	return null


func _create_label():
	var layer = get_overhead_layer()
	if world == null or layer == null:
		return

	var old = layer.get_node_or_null("PlayerUsernameLabel")
	if old != null:
		old.queue_free()
	if "ui_layer" in world and world.ui_layer != layer:
		var old_root = world.ui_layer.get_node_or_null("PlayerUsernameLabel")
		if old_root != null:
			old_root.queue_free()

	var old_growth = layer.get_node_or_null("PlayerSeedGrowthLabel")
	if old_growth != null:
		old_growth.queue_free()
	if "ui_layer" in world and world.ui_layer != layer:
		var old_growth_root = world.ui_layer.get_node_or_null("PlayerSeedGrowthLabel")
		if old_growth_root != null:
			old_growth_root.queue_free()

	if world.player != null:
		var legacy_label = world.player.get_node_or_null("UsernameLabel")
		if legacy_label != null:
			legacy_label.visible = false
			if legacy_label is Label:
				legacy_label.text = ""

	label = Label.new()
	label.name = "PlayerUsernameLabel"
	label.size = Vector2(LABEL_WIDTH, LABEL_HEIGHT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = LOCAL_USERNAME_Z_INDEX
	label.set_meta(USERNAME_FONT_SIZE_META, FONT_SIZE)

	label.add_theme_font_size_override("font_size", FONT_SIZE)
	apply_username_font_to_label(label)
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	label.add_theme_color_override("font_outline_color", DEFAULT_USERNAME_OUTLINE_COLOR)
	label.add_theme_color_override("font_shadow_color", DEFAULT_USERNAME_SHADOW_COLOR)
	label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)

	label.visible = false
	layer.add_child(label)

	growth_label = Label.new()
	growth_label.name = "PlayerSeedGrowthLabel"
	growth_label.size = Vector2(GROWTH_LABEL_WIDTH, GROWTH_LABEL_HEIGHT)
	growth_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	growth_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	growth_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	growth_label.z_index = LOCAL_GROWTH_LABEL_Z_INDEX

	growth_label.add_theme_font_size_override("font_size", GROWTH_FONT_SIZE)
	apply_username_font_to_label(growth_label)
	growth_label.add_theme_color_override("font_color", GROWTH_TIMER_COLOR)
	growth_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	growth_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.65))
	growth_label.add_theme_constant_override("outline_size", GROWTH_OUTLINE_SIZE)
	growth_label.add_theme_constant_override("shadow_offset_x", 1)
	growth_label.add_theme_constant_override("shadow_offset_y", 1)

	growth_label.modulate.a = 0.0
	growth_label.visible = false
	layer.add_child(growth_label)


func _process(delta):
	update_text()
	_update_label_style(delta)
	update_position(delta)


func update_text():
	if label == null or world == null:
		return

	var username = _get_canonical_username()

	label.text = _format_username_display_name(username)
	if _is_dead_spirit_active():
		_hide_labels()
		return
	label.visible = label.text.strip_edges() != "" and world.in_world


func _get_canonical_username() -> String:
	var network = get_network_manager()
	if network != null and network.has_method("get_active_session_username"):
		var session_username = str(network.get_active_session_username()).strip_edges()
		if session_username != "":
			return session_username

	if world.has_method("get_current_profile_name"):
		return str(world.get_current_profile_name()).strip_edges()

	return ""


func _format_username_display_name(raw_username: String) -> String:
	var clean_name = raw_username.strip_edges()
	if clean_name == "":
		return ""

	if clean_name.to_lower() == "uso":
		return "USO"

	if clean_name.length() > 24:
		clean_name = clean_name.substr(0, 24)

	if clean_name == clean_name.to_upper():
		return clean_name

	if clean_name.length() == 1:
		return clean_name.to_upper()

	return clean_name.substr(0, 1).to_upper() + clean_name.substr(1)


func _hide_labels():
	if label != null and is_instance_valid(label):
		label.visible = false
	if growth_label != null and is_instance_valid(growth_label):
		growth_label_alpha = 0.0
		growth_label.modulate.a = 0.0
		growth_label.visible = false


func _is_dead_spirit_active() -> bool:
	if world == null or world.player == null:
		return false

	var override_expression := str(world.player.get_meta("face_expression_override", "")).strip_edges().to_lower()
	return override_expression == "dead_spirit"


func _any_ui_open() -> bool:
	if world == null:
		return false
	if world.has_method("is_movement_blocking_ui_open") and world.is_movement_blocking_ui_open(): return true
	if world.has_method("is_crafting_open")     and world.is_crafting_open():     return true
	if world.has_method("is_furnace_open")      and world.is_furnace_open():      return true
	if world.has_method("is_sign_open")         and world.is_sign_open():         return true
	if world.has_method("is_shop_open")         and world.is_shop_open():         return true
	if world.has_method("is_notification_panel_open") and world.is_notification_panel_open(): return true
	if world.has_method("is_player_menu_open")  and world.is_player_menu_open():  return true
	if world.has_method("is_game_menu_open")    and world.is_game_menu_open():    return true
	if world.has_method("is_friends_panel_open") and world.is_friends_panel_open(): return true
	if world.has_method("is_world_menu_open")   and world.is_world_menu_open():   return true
	if world.has_method("is_world_lock_ui_open") and world.is_world_lock_ui_open(): return true
	if world.has_method("is_trade_open")        and world.is_trade_open():        return true
	if world.has_method("is_vending_open")      and world.is_vending_open():      return true
	if world.has_method("is_safe_open")         and world.is_safe_open():         return true
	if world.has_method("is_fish_monger_open") and world.is_fish_monger_open(): return true
	if world.has_method("is_developer_panel_open") and world.is_developer_panel_open(): return true
	return false


func _is_admin_role() -> bool:
	var network = get_network_manager()
	if network == null:
		return false
	if not network.has_method("get_active_session_role"):
		return false

	var role = str(network.get_active_session_role()).strip_edges().to_lower()
	return role == "admin" or role == "developer"


func _is_purple_glow_username(raw_username: String) -> bool:
	return raw_username.strip_edges().to_lower() == PURPLE_GLOW_USERNAME_KEY


func _apply_default_username_glow():
	if label == null or not is_instance_valid(label):
		return

	label.add_theme_color_override("font_outline_color", DEFAULT_USERNAME_OUTLINE_COLOR)
	label.add_theme_color_override("font_shadow_color", DEFAULT_USERNAME_SHADOW_COLOR)
	label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)


func _apply_purple_username_glow():
	if label == null or not is_instance_valid(label):
		return

	var pulse = (sin(float(Time.get_ticks_msec()) / 1000.0 * PURPLE_GLOW_PULSE_SPEED) + 1.0) * 0.5
	label.add_theme_color_override("font_color", PURPLE_GLOW_USERNAME_COLOR.lerp(PURPLE_GLOW_USERNAME_COLOR_BRIGHT, pulse))
	label.add_theme_color_override("font_outline_color", PURPLE_GLOW_OUTLINE_COLOR.lerp(PURPLE_GLOW_OUTLINE_COLOR_BRIGHT, pulse))
	label.add_theme_color_override("font_shadow_color", PURPLE_GLOW_SHADOW_COLOR.lerp(PURPLE_GLOW_SHADOW_COLOR_BRIGHT, pulse))
	label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)


func _update_role_style(_delta: float):
	if label == null or not is_instance_valid(label):
		return

	if _is_admin_role():
		rainbow_time = fmod((float(Time.get_ticks_msec()) / 1000.0) * RAINBOW_SPEED, 1.0)
		label.add_theme_color_override("font_color", Color.from_hsv(rainbow_time, 0.88, 1.0))
	else:
		rainbow_time = 0.0
		label.add_theme_color_override("font_color", DEFAULT_USERNAME_COLOR)


func _update_label_style(delta: float):
	if label == null or not is_instance_valid(label) or world == null:
		return

	if _is_purple_glow_username(_get_canonical_username()):
		rainbow_time = 0.0
		_apply_purple_username_glow()
		return

	_apply_default_username_glow()
	_update_role_style(delta)
	if _is_admin_role():
		return
	_apply_world_lock_username_color()


func _apply_world_lock_username_color():
	if label == null or not is_instance_valid(label) or world == null:
		return

	var access_state = "none"
	if world.has_method("get_local_player_world_lock_access_state"):
		access_state = str(world.get_local_player_world_lock_access_state()).strip_edges().to_lower()

	var access_role = "none"
	if world.has_method("get_local_player_world_lock_access_role"):
		access_role = str(world.get_local_player_world_lock_access_role()).strip_edges().to_lower()

	if access_role == "owner" or access_state == "owner":
		label.add_theme_color_override("font_color", get_world_lock_owner_color())
		return

	if access_role == "admin" or access_role == "builder" or access_role == "visitor":
		label.add_theme_color_override("font_color", WORLD_LOCK_ACCESS_COLOR)
		return

	if access_state == "owner":
		label.add_theme_color_override("font_color", get_world_lock_owner_color())
	elif access_state == "access":
		label.add_theme_color_override("font_color", WORLD_LOCK_ACCESS_COLOR)
	else:
		label.add_theme_color_override("font_color", DEFAULT_USERNAME_COLOR)


func get_world_lock_owner_color() -> Color:
	if world != null and world.has_method("is_super_world_lock_active") and bool(world.is_super_world_lock_active()):
		return SUPER_WORLD_LOCK_OWNER_COLOR

	return WORLD_LOCK_OWNER_COLOR


func _get_label_anchor_screen_position() -> Vector2:
	var canvas_transform = get_viewport().get_canvas_transform()
	var fallback_world_position = world.player.global_position + Vector2(0.0, -FALLBACK_OFFSET_ABOVE_PLAYER_WORLD_PX)

	var body_sprite = world.player.get_node_or_null("Sprite2D")
	if body_sprite != null and body_sprite is Sprite2D and body_sprite.texture != null:
		var texture_height = float(body_sprite.texture.get_height()) * abs(body_sprite.global_scale.y)
		var top_y = body_sprite.global_position.y
		if body_sprite.centered:
			top_y -= texture_height * 0.5
		top_y -= LABEL_MARGIN_ABOVE_HEAD_WORLD_PX
		return canvas_transform * Vector2(body_sprite.global_position.x, top_y)

	return canvas_transform * fallback_world_position


func update_position(delta: float = 0.0):
	if label == null or not is_instance_valid(label):
		if growth_label != null and is_instance_valid(growth_label):
			growth_label.visible = false
		return

	if world == null or world.player == null:
		_hide_labels()
		return

	if not world.in_world:
		_hide_labels()
		return

	if _is_dead_spirit_active():
		_hide_labels()
		return

	var username = label.text.strip_edges()
	if username == "":
		_hide_labels()
		return

	var anchor_pos = _get_label_anchor_screen_position()
	var username_pos = Vector2(
		anchor_pos.x - LABEL_WIDTH / 2.0,
		anchor_pos.y - LABEL_HEIGHT
	)

	label.size = Vector2(LABEL_WIDTH, LABEL_HEIGHT)
	label.z_index = LOCAL_USERNAME_Z_INDEX
	label.position = username_pos

	if _any_ui_open():
		_hide_labels()
		return

	label.visible = true
	update_growth_label(anchor_pos, username_pos, delta)


func update_growth_label(anchor_pos: Vector2, username_pos: Vector2, delta: float = 0.0):
	if growth_label == null or not is_instance_valid(growth_label):
		return

	var hover_info: Dictionary = get_seed_hover_info()
	var growth_text: String = str(hover_info.get("status_text", "")).strip_edges()
	var tree_name: String = str(hover_info.get("tree_name", "")).strip_edges()
	var has_tree_text: bool = tree_name != "" or growth_text != ""

	if not has_tree_text:
		_fade_growth_label(false, delta)
		return

	var display_lines := PackedStringArray()
	if tree_name != "":
		display_lines.append(tree_name)
	if growth_text != "":
		display_lines.append(growth_text)

	growth_label.text = "\n".join(display_lines)
	growth_label.size = Vector2(GROWTH_LABEL_WIDTH, GROWTH_LABEL_HEIGHT)
	growth_label.z_index = LOCAL_GROWTH_LABEL_Z_INDEX
	growth_label.position = Vector2(
		anchor_pos.x - GROWTH_LABEL_WIDTH / 2.0,
		username_pos.y - GROWTH_LABEL_HEIGHT + GROWTH_LABEL_GAP
	)
	if bool(hover_info.get("mature", false)) or growth_text == "Ready to harvest":
		growth_label.add_theme_color_override("font_color", GROWTH_READY_COLOR)
	else:
		growth_label.add_theme_color_override("font_color", GROWTH_TIMER_COLOR)

	_fade_growth_label(true, delta)


func _fade_growth_label(should_show: bool, delta: float = 0.0):
	if growth_label == null or not is_instance_valid(growth_label):
		return

	var target_alpha := 1.0 if should_show else 0.0
	var fade_speed := TREE_TEXT_FADE_IN_SPEED if should_show else TREE_TEXT_FADE_OUT_SPEED
	if delta <= 0.0:
		growth_label_alpha = target_alpha
	else:
		growth_label_alpha = move_toward(growth_label_alpha, target_alpha, fade_speed * delta)

	growth_label.modulate.a = growth_label_alpha
	growth_label.visible = should_show or growth_label_alpha > 0.01
	if not growth_label.visible:
		growth_label.text = ""


func get_seed_hover_info() -> Dictionary:
	if world == null or world.player == null or world.seed_system == null:
		return {}

	var player_grid_pos = world.get_player_grid_position() if world.has_method("get_player_grid_position") else Vector2i.ZERO
	if world.seed_system.has_method("get_seed_hover_info_for_player"):
		var hover_info = world.seed_system.get_seed_hover_info_for_player(
			player_grid_pos,
			world.player.global_position
		)
		if hover_info is Dictionary:
			return hover_info

	if world.seed_system.has_method("get_seed_growth_status_text_for_player"):
		var status_text := str(world.seed_system.get_seed_growth_status_text_for_player(
			player_grid_pos,
			world.player.global_position
		)).strip_edges()
		if status_text != "":
			return {
				"tree_name": "",
				"status_text": status_text,
				"mature": status_text == "Ready to harvest"
			}

	return {}


func clear():
	_hide_labels()
	if label != null and is_instance_valid(label):
		label.text = ""
	if growth_label != null and is_instance_valid(growth_label):
		growth_label.text = ""
