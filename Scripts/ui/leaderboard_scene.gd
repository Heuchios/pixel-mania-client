@tool
extends Control
class_name PixelLeaderboardScene

signal close_pressed
signal rewards_pressed
signal tab_selected(index: int, tab_data: Resource)

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")
const LeaderboardEntryDataScript = preload("res://Scripts/ui/leaderboard_entry_data.gd")
const LeaderboardTabDataScript = preload("res://Scripts/ui/leaderboard_tab_data.gd")

const DEFAULT_EVENT_ICON_PATH := "res://Assets/events/landfill/icon.png"
const DEFAULT_HEADER_TEXTURE_PATH := "res://Assets/background/landfill/bg_4.png"

@export_category("How To Customize")
@export_multiline var editor_note: String = "This scene is intentionally made from real child nodes. Edit labels, panels, rows, buttons, textures, positions, and sizes directly in the Scene tree. Keep Apply Exported Content/Styles enabled for data-driven previews, or turn them off when you want direct node edits to stay untouched."

@export_category("Content")
@export var title_text: String = "LANDFILL"
@export var badge_text: String = "EVENT LEADERBOARD"
@export var subtitle_text: String = "Compete in the Landfill Race and earn points!"
@export var rank_header_text: String = "RANK"
@export var player_header_text: String = "PLAYER"
@export var points_header_text: String = "TOTAL POINTS"
@export var points_suffix: String = ""
@export var tabs: Array[Resource] = []
@export var leaderboard_entries: Array[Resource] = []
@export var show_sample_data_when_empty: bool = true
@export var apply_exported_content_on_ready: bool = true
@export var apply_exported_styles_on_ready: bool = true

@export_category("Personal Summary")
@export var summary_rank_label: String = "YOUR RANK"
@export var summary_points_label: String = "YOUR POINTS"
@export var summary_timer_label: String = "EVENT ENDS IN:"
@export var summary_rank_value: String = "15"
@export var summary_points_value: int = 1240
@export var summary_timer_value: String = "4D 12H 36M"
@export var rewards_button_text: String = "REWARDS"

@export_category("Behavior")
@export var selected_tab_index: int = 0
@export var close_button_hides_scene: bool = true
@export var show_close_button: bool = true
@export var show_rewards_button: bool = true
@export var show_dimmer: bool = true
@export var show_side_art_panel: bool = true
@export var auto_use_landfill_art: bool = true
@export var auto_fit_to_viewport: bool = true

@export_category("Layout")
@export var window_size: Vector2 = Vector2(1032.0, 688.0)
@export var viewport_margin: Vector2 = Vector2(42.0, 32.0)

@export_category("Textures")
@export var header_background_texture: Texture2D = null
@export var event_icon_texture: Texture2D = null
@export var currency_icon_texture: Texture2D = preload("res://Assets/currency/gem.png")
@export var reward_icon_texture: Texture2D = preload("res://Assets/currency/gem.png")
@export var default_avatar_texture: Texture2D = null

@export_category("Colors")
@export var dimmer_color: Color = Color(0.0, 0.0, 0.0, 0.48)
@export var panel_fill_color: Color = Color(0.055, 0.065, 0.064, 0.96)
@export var panel_border_color: Color = Color(0.58, 0.57, 0.54, 0.95)
@export var inner_fill_color: Color = Color(0.045, 0.074, 0.074, 0.86)
@export var inner_border_color: Color = Color(0.23, 0.30, 0.31, 0.92)
@export var title_color: Color = Color(0.42, 0.86, 0.22, 1.0)
@export var badge_color: Color = Color(1.0, 0.86, 0.10, 1.0)
@export var header_text_color: Color = Color(0.55, 0.88, 0.25, 1.0)
@export var body_text_color: Color = Color(0.94, 0.96, 0.94, 1.0)
@export var muted_text_color: Color = Color(0.74, 0.78, 0.76, 1.0)
@export var row_fill_color: Color = Color(0.035, 0.070, 0.070, 0.92)
@export var row_alt_fill_color: Color = Color(0.050, 0.085, 0.083, 0.92)
@export var row_border_color: Color = Color(0.17, 0.23, 0.24, 0.95)
@export var top_rank_fill_color: Color = Color(0.48, 0.34, 0.06, 0.90)
@export var top_rank_border_color: Color = Color(0.95, 0.64, 0.09, 0.95)
@export var button_green_color: Color = Color(0.30, 0.70, 0.18, 1.0)
@export var button_blue_color: Color = Color(0.13, 0.24, 0.30, 1.0)
@export var close_button_color: Color = Color(0.82, 0.16, 0.10, 1.0)

@export_category("Typography")
@export_range(18, 72, 1) var title_font_size: int = 52
@export_range(12, 40, 1) var badge_font_size: int = 23
@export_range(10, 32, 1) var subtitle_font_size: int = 19
@export_range(10, 30, 1) var header_font_size: int = 15
@export_range(10, 34, 1) var row_font_size: int = 21
@export_range(10, 36, 1) var points_font_size: int = 22
@export_range(10, 34, 1) var summary_font_size: int = 22

@onready var dimmer: ColorRect = get_node_or_null("Dimmer") as ColorRect
@onready var center_container: CenterContainer = get_node_or_null("CenterContainer") as CenterContainer
@onready var leaderboard_window: Control = get_node_or_null("CenterContainer/LeaderboardWindow") as Control
@onready var header_panel: Panel = get_node_or_null("CenterContainer/LeaderboardWindow/HeaderPanel") as Panel
@onready var header_background: TextureRect = get_node_or_null("CenterContainer/LeaderboardWindow/HeaderPanel/HeaderBackground") as TextureRect
@onready var side_texture: TextureRect = get_node_or_null("CenterContainer/LeaderboardWindow/SideColumn/SideArtPanel/SideTexture") as TextureRect
@onready var tabs_root: Control = get_node_or_null("CenterContainer/LeaderboardWindow/SideColumn/Tabs") as Control
@onready var rows_root: Control = get_node_or_null("CenterContainer/LeaderboardWindow/TablePanel/RowsClip/RowsRoot") as Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_window_size()
	_connect_static_buttons()
	if apply_exported_styles_on_ready:
		apply_exported_styles()
	if apply_exported_content_on_ready:
		apply_exported_content()
	_update_visibility_flags()
	_update_window_scale()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_window_scale()


func refresh_preview() -> void:
	_apply_window_size()
	if apply_exported_styles_on_ready:
		apply_exported_styles()
	if apply_exported_content_on_ready:
		apply_exported_content()
	_update_visibility_flags()
	_update_window_scale()


func apply_exported_content() -> void:
	_set_label_text("CenterContainer/LeaderboardWindow/HeaderPanel/TitleLabel", title_text)
	_set_label_text("CenterContainer/LeaderboardWindow/HeaderPanel/BadgeBack/BadgeLabel", badge_text)
	_set_label_text("CenterContainer/LeaderboardWindow/HeaderPanel/SubtitleLabel", subtitle_text)
	_set_label_text("CenterContainer/LeaderboardWindow/TablePanel/HeaderRow/RankHeader", rank_header_text)
	_set_label_text("CenterContainer/LeaderboardWindow/TablePanel/HeaderRow/PlayerHeader", player_header_text)
	_set_label_text("CenterContainer/LeaderboardWindow/TablePanel/HeaderRow/PointsHeader", points_header_text)
	_set_label_text("CenterContainer/LeaderboardWindow/SummaryPanel/YourRankStat/Label", summary_rank_label)
	_set_label_text("CenterContainer/LeaderboardWindow/SummaryPanel/YourRankStat/Value", summary_rank_value)
	_set_label_text("CenterContainer/LeaderboardWindow/SummaryPanel/YourPointsStat/Label", summary_points_label)
	_set_label_text("CenterContainer/LeaderboardWindow/SummaryPanel/YourPointsStat/Value", _format_number(summary_points_value))
	_set_label_text("CenterContainer/LeaderboardWindow/SummaryPanel/EventEndsStat/Label", summary_timer_label)
	_set_label_text("CenterContainer/LeaderboardWindow/SummaryPanel/EventEndsStat/Value", summary_timer_value)

	var rewards_button := get_node_or_null("CenterContainer/LeaderboardWindow/SummaryPanel/RewardsButton") as Button
	if rewards_button != null:
		rewards_button.text = rewards_button_text
		rewards_button.icon = reward_icon_texture

	_apply_texture_if_present(header_background, _resolve_header_texture())
	_apply_texture_if_present(side_texture, _resolve_header_texture())
	_apply_tabs_content()
	_apply_rows_content()


func apply_exported_styles() -> void:
	if dimmer != null:
		dimmer.color = dimmer_color

	_style_panel("CenterContainer/LeaderboardWindow/DropShadow", Color(0.0, 0.0, 0.0, 0.32), Color(0.0, 0.0, 0.0, 0.0), 0, 8, 0)
	_style_panel("CenterContainer/LeaderboardWindow/WindowBack", panel_fill_color, panel_border_color, 5, 8, 10)
	_style_panel("CenterContainer/LeaderboardWindow/HeaderPanel", Color(0.064, 0.116, 0.130, 0.96), inner_border_color, 3, 5, 3)
	_style_panel("CenterContainer/LeaderboardWindow/HeaderPanel/BadgeBack", Color(0.040, 0.046, 0.042, 0.92), Color(0.86, 0.76, 0.18, 0.88), 3, 5, 2)
	_style_panel("CenterContainer/LeaderboardWindow/SideColumn/ChampionBadge", Color(0.055, 0.074, 0.073, 0.96), Color(0.10, 0.12, 0.11, 1.0), 4, 7, 4)
	_style_panel("CenterContainer/LeaderboardWindow/SideColumn/ChampionBadge/TrophyBack", Color(0.020, 0.030, 0.028, 0.96), Color(0.16, 0.19, 0.17, 1.0), 2, 6, 0)
	_style_panel("CenterContainer/LeaderboardWindow/SideColumn/ChampionBadge/TrophyBack/Cup", Color(1.0, 0.71, 0.05, 1.0), Color(0.45, 0.26, 0.00, 1.0), 3, 5, 0)
	_style_panel("CenterContainer/LeaderboardWindow/SideColumn/SideArtPanel", Color(0.045, 0.052, 0.046, 0.86), Color(0.11, 0.12, 0.11, 1.0), 3, 6, 2)
	_style_panel("CenterContainer/LeaderboardWindow/TablePanel", Color(0.030, 0.044, 0.045, 0.95), Color(0.18, 0.21, 0.20, 1.0), 4, 6, 4)
	_style_panel("CenterContainer/LeaderboardWindow/TablePanel/HeaderRow", Color(0.085, 0.110, 0.105, 0.96), Color(0.22, 0.28, 0.27, 0.96), 2, 4, 0)
	_style_panel("CenterContainer/LeaderboardWindow/SummaryPanel", Color(0.045, 0.058, 0.058, 0.96), Color(0.18, 0.21, 0.20, 1.0), 4, 6, 4)

	_style_label("CenterContainer/LeaderboardWindow/HeaderPanel/TitleLabel", title_font_size, title_color, HORIZONTAL_ALIGNMENT_CENTER)
	_style_label("CenterContainer/LeaderboardWindow/HeaderPanel/BadgeBack/BadgeLabel", badge_font_size, badge_color, HORIZONTAL_ALIGNMENT_CENTER)
	_style_label("CenterContainer/LeaderboardWindow/HeaderPanel/SubtitleLabel", subtitle_font_size, body_text_color, HORIZONTAL_ALIGNMENT_CENTER)
	_style_label("CenterContainer/LeaderboardWindow/TablePanel/HeaderRow/RankHeader", header_font_size, header_text_color, HORIZONTAL_ALIGNMENT_CENTER)
	_style_label("CenterContainer/LeaderboardWindow/TablePanel/HeaderRow/PlayerHeader", header_font_size, header_text_color, HORIZONTAL_ALIGNMENT_CENTER)
	_style_label("CenterContainer/LeaderboardWindow/TablePanel/HeaderRow/PointsHeader", header_font_size, header_text_color, HORIZONTAL_ALIGNMENT_RIGHT)

	for stat_path in [
		"CenterContainer/LeaderboardWindow/SummaryPanel/YourRankStat",
		"CenterContainer/LeaderboardWindow/SummaryPanel/YourPointsStat",
		"CenterContainer/LeaderboardWindow/SummaryPanel/EventEndsStat",
	]:
		_style_label(stat_path + "/Label", header_font_size, header_text_color, HORIZONTAL_ALIGNMENT_CENTER)
		_style_label(stat_path + "/Value", summary_font_size, body_text_color, HORIZONTAL_ALIGNMENT_CENTER)

	var close_button := get_node_or_null("CenterContainer/LeaderboardWindow/CloseButton") as Button
	if close_button != null:
		_apply_flat_button_style(close_button, close_button_color, Color(0.22, 0.03, 0.02, 1.0), 23)

	var rewards_button := get_node_or_null("CenterContainer/LeaderboardWindow/SummaryPanel/RewardsButton") as Button
	if rewards_button != null:
		_apply_flat_button_style(rewards_button, button_green_color, Color(0.04, 0.24, 0.04, 1.0), 18)

	_apply_tabs_style()
	_apply_rows_style()


func set_entries_from_dictionaries(entry_dicts: Array) -> void:
	var parsed_entries: Array[Resource] = []
	for raw_entry in entry_dicts:
		if raw_entry is Dictionary:
			parsed_entries.append(_entry_from_dictionary(raw_entry))
		elif raw_entry is Resource:
			parsed_entries.append(raw_entry)

	leaderboard_entries = parsed_entries
	show_sample_data_when_empty = false
	apply_exported_content()


func set_tabs_from_dictionaries(tab_dicts: Array) -> void:
	var parsed_tabs: Array[Resource] = []
	for raw_tab in tab_dicts:
		if raw_tab is Dictionary:
			parsed_tabs.append(_tab_from_dictionary(raw_tab))
		elif raw_tab is Resource:
			parsed_tabs.append(raw_tab)

	tabs = parsed_tabs
	apply_exported_content()
	apply_exported_styles()


func set_personal_summary(rank_text: String, points_value: int, timer_text: String) -> void:
	summary_rank_value = rank_text
	summary_points_value = points_value
	summary_timer_value = timer_text
	apply_exported_content()


func select_tab(index: int) -> void:
	var effective_tabs := _get_effective_tabs()
	if effective_tabs.is_empty():
		selected_tab_index = 0
	else:
		selected_tab_index = clampi(index, 0, effective_tabs.size() - 1)
	_apply_tabs_content()
	_apply_tabs_style()


func _apply_window_size() -> void:
	if leaderboard_window == null:
		return
	leaderboard_window.custom_minimum_size = window_size
	leaderboard_window.size = window_size


func _update_window_scale() -> void:
	if leaderboard_window == null or not auto_fit_to_viewport or not is_inside_tree():
		return

	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var available := Vector2(
		max(1.0, viewport_size.x - viewport_margin.x * 2.0),
		max(1.0, viewport_size.y - viewport_margin.y * 2.0)
	)
	var scale_value: float = min(1.0, min(available.x / window_size.x, available.y / window_size.y))
	leaderboard_window.scale = Vector2(scale_value, scale_value)
	leaderboard_window.pivot_offset = window_size * 0.5


func _update_visibility_flags() -> void:
	if dimmer != null:
		dimmer.visible = show_dimmer
	var close_button := get_node_or_null("CenterContainer/LeaderboardWindow/CloseButton") as CanvasItem
	if close_button != null:
		close_button.visible = show_close_button
	var rewards_button := get_node_or_null("CenterContainer/LeaderboardWindow/SummaryPanel/RewardsButton") as CanvasItem
	if rewards_button != null:
		rewards_button.visible = show_rewards_button
	var side_art := get_node_or_null("CenterContainer/LeaderboardWindow/SideColumn/SideArtPanel") as CanvasItem
	if side_art != null:
		side_art.visible = show_side_art_panel


func _connect_static_buttons() -> void:
	var close_button := get_node_or_null("CenterContainer/LeaderboardWindow/CloseButton") as Button
	if close_button != null:
		var close_callable := Callable(self, "_on_close_pressed")
		if not close_button.pressed.is_connected(close_callable):
			close_button.pressed.connect(close_callable)

	var rewards_button := get_node_or_null("CenterContainer/LeaderboardWindow/SummaryPanel/RewardsButton") as Button
	if rewards_button != null:
		var rewards_callable := Callable(self, "_on_rewards_pressed")
		if not rewards_button.pressed.is_connected(rewards_callable):
			rewards_button.pressed.connect(rewards_callable)

	var tab_buttons := _get_tab_buttons()
	for i in range(tab_buttons.size()):
		var tab_button := tab_buttons[i]
		if tab_button == null:
			continue
		if not tab_button.has_meta("_pixelmania_leaderboard_tab_connected"):
			tab_button.pressed.connect(_on_tab_button_pressed.bind(i))
			tab_button.set_meta("_pixelmania_leaderboard_tab_connected", true)


func _apply_tabs_content() -> void:
	var tab_buttons := _get_tab_buttons()
	var effective_tabs := _get_effective_tabs()
	selected_tab_index = clampi(selected_tab_index, 0, max(0, effective_tabs.size() - 1))

	for i in range(tab_buttons.size()):
		var tab_button := tab_buttons[i]
		if tab_button == null:
			continue
		var has_tab := i < effective_tabs.size()
		tab_button.visible = has_tab
		if not has_tab:
			continue
		var tab_data: Resource = effective_tabs[i]
		tab_button.text = _tab_label(tab_data)
		tab_button.icon = _tab_icon(tab_data, i)
		tab_button.tooltip_text = _tab_tooltip(tab_data)
		tab_button.disabled = _tab_disabled(tab_data)
		tab_button.button_pressed = i == selected_tab_index


func _apply_tabs_style() -> void:
	var tab_buttons := _get_tab_buttons()
	var effective_tabs := _get_effective_tabs()
	for i in range(tab_buttons.size()):
		var tab_button := tab_buttons[i]
		if tab_button == null:
			continue
		var accent := button_green_color
		if i < effective_tabs.size():
			accent = _tab_accent(effective_tabs[i])
		if i == selected_tab_index:
			_apply_flat_button_style(tab_button, accent, Color(0.07, 0.22, 0.07, 1.0), 17)
		else:
			_apply_flat_button_style(tab_button, button_blue_color, Color(0.04, 0.08, 0.10, 1.0), 17)


func _apply_rows_content() -> void:
	var row_nodes := _get_row_nodes()
	var effective_entries := _get_effective_entries()

	for i in range(row_nodes.size()):
		var row := row_nodes[i]
		if row == null:
			continue
		var has_entry := i < effective_entries.size()
		row.visible = has_entry
		if not has_entry:
			continue
		_apply_entry_to_row(row, effective_entries[i], i)


func _apply_rows_style() -> void:
	var row_nodes := _get_row_nodes()
	var effective_entries := _get_effective_entries()
	for i in range(row_nodes.size()):
		var row := row_nodes[i]
		if row == null or i >= effective_entries.size():
			continue
		var entry := effective_entries[i]
		var highlighted := bool(_resource_value(entry, "highlighted", false))
		var fill := row_fill_color if i % 2 == 0 else row_alt_fill_color
		var border := row_border_color
		var fill_override := _color_from_value(_resource_value(entry, "row_fill_override", Color(0.0, 0.0, 0.0, 0.0)), Color(0.0, 0.0, 0.0, 0.0))
		var border_override := _color_from_value(_resource_value(entry, "row_border_override", Color(0.0, 0.0, 0.0, 0.0)), Color(0.0, 0.0, 0.0, 0.0))
		if highlighted:
			fill = top_rank_fill_color
			border = top_rank_border_color
		if fill_override.a > 0.0:
			fill = fill_override
		if border_override.a > 0.0:
			border = border_override
		row.add_theme_stylebox_override("panel", _style(fill, border, 2, 4, 1))
		_style_row_labels(row, entry)


func _apply_entry_to_row(row: Panel, entry: Resource, visual_index: int) -> void:
	var rank: int = int(_resource_value(entry, "rank", visual_index + 1))
	var player_name := str(_resource_value(entry, "player_name", "Player"))
	var points: int = int(_resource_value(entry, "points", 0))
	var avatar_texture := _texture_from_value(_resource_value(entry, "avatar_texture", null))
	var reward_texture := _texture_from_value(_resource_value(entry, "reward_texture", null))
	if avatar_texture == null:
		avatar_texture = default_avatar_texture
	if reward_texture == null:
		reward_texture = currency_icon_texture

	_set_child_label_text(row, "RankNumber", str(rank))
	_set_child_label_text(row, "PlayerName", player_name)
	_set_child_label_text(row, "Points", _format_number(points) + points_suffix)
	_set_child_label_text(row, "AvatarBack/Initials", _initials_for(player_name))
	_set_child_label_text(row, "RewardBack/RewardLabel", str(_resource_value(entry, "reward_label", "")))

	var left_laurel := row.get_node_or_null("LeftLaurel") as CanvasItem
	var right_laurel := row.get_node_or_null("RightLaurel") as CanvasItem
	if left_laurel != null:
		left_laurel.visible = rank <= 3
	if right_laurel != null:
		right_laurel.visible = rank <= 3

	var avatar_icon := row.get_node_or_null("AvatarBack/Avatar") as TextureRect
	if avatar_icon != null:
		avatar_icon.texture = avatar_texture
		avatar_icon.visible = avatar_texture != null

	var avatar_back := row.get_node_or_null("AvatarBack") as Panel
	if avatar_back != null:
		var avatar_color := _color_from_value(_resource_value(entry, "avatar_color", Color(0.45, 0.62, 0.84, 1.0)), Color(0.45, 0.62, 0.84, 1.0))
		avatar_back.add_theme_stylebox_override("panel", _style(_with_alpha(avatar_color, 0.86), Color(0.04, 0.05, 0.05, 1.0), 2, 5, 0))

	var reward_icon := row.get_node_or_null("RewardBack/RewardIcon") as TextureRect
	if reward_icon != null:
		reward_icon.texture = reward_texture
		reward_icon.visible = reward_texture != null


func _style_row_labels(row: Panel, entry: Resource) -> void:
	var rank := int(_child_label_text(row, "RankNumber", "0"))
	var rank_color := _rank_color(rank)
	var name_color := _color_from_value(_resource_value(entry, "name_color_override", body_text_color), body_text_color)
	var points_color := _color_from_value(_resource_value(entry, "points_color_override", body_text_color), body_text_color)
	if bool(_resource_value(entry, "highlighted", false)):
		points_color = badge_color

	_style_child_label(row, "RankNumber", points_font_size + (3 if rank <= 3 else 0), rank_color, HORIZONTAL_ALIGNMENT_CENTER)
	_style_child_label(row, "LeftLaurel", 25, rank_color, HORIZONTAL_ALIGNMENT_CENTER)
	_style_child_label(row, "RightLaurel", 25, rank_color, HORIZONTAL_ALIGNMENT_CENTER)
	_style_child_label(row, "PlayerName", row_font_size, name_color, HORIZONTAL_ALIGNMENT_LEFT)
	_style_child_label(row, "Points", points_font_size, points_color, HORIZONTAL_ALIGNMENT_RIGHT)
	_style_child_label(row, "AvatarBack/Initials", 16, body_text_color, HORIZONTAL_ALIGNMENT_CENTER)
	_style_child_label(row, "RewardBack/RewardLabel", 15, badge_color, HORIZONTAL_ALIGNMENT_CENTER)

	var reward_back := row.get_node_or_null("RewardBack") as Panel
	if reward_back != null:
		reward_back.add_theme_stylebox_override("panel", _style(Color(0.070, 0.080, 0.080, 0.78), row_border_color, 2, 4, 0))


func _get_tab_buttons() -> Array[Button]:
	var result: Array[Button] = []
	if tabs_root == null:
		return result
	for child in tabs_root.get_children():
		if child is Button:
			result.append(child as Button)
	return result


func _get_row_nodes() -> Array[Panel]:
	var result: Array[Panel] = []
	if rows_root == null:
		return result
	for child in rows_root.get_children():
		if child is Panel:
			result.append(child as Panel)
	return result


func _get_effective_tabs() -> Array[Resource]:
	if not tabs.is_empty():
		return tabs
	if not show_sample_data_when_empty:
		return []

	var sample_tabs: Array[Resource] = []
	sample_tabs.append(_make_sample_tab("LANDFILL", Color(0.36, 0.78, 0.23, 1.0), _resolve_event_icon_texture()))
	sample_tabs.append(_make_sample_tab("WEEKLY", Color(0.22, 0.58, 0.82, 1.0), null))
	sample_tabs.append(_make_sample_tab("GLOBAL", Color(0.34, 0.70, 0.92, 1.0), null))
	return sample_tabs


func _get_effective_entries() -> Array[Resource]:
	if not leaderboard_entries.is_empty():
		return leaderboard_entries
	if not show_sample_data_when_empty:
		return []

	var names := [
		"PixelHero",
		"TrashMaster",
		"JunkCollector",
		"LandfillLegend",
		"RubbishKing",
		"EcoWarrior",
		"RecyclePro",
		"DustBuster",
	]
	var scores := [12450, 9820, 7630, 6410, 5210, 4380, 3920, 3150]
	var colors := [
		Color(0.96, 0.54, 0.18, 1.0),
		Color(0.24, 0.68, 0.18, 1.0),
		Color(0.18, 0.50, 0.86, 1.0),
		Color(0.90, 0.58, 0.30, 1.0),
		Color(0.78, 0.82, 0.84, 1.0),
		Color(0.54, 0.25, 0.84, 1.0),
		Color(0.74, 0.34, 0.18, 1.0),
		Color(0.20, 0.76, 0.34, 1.0),
	]
	var entries: Array[Resource] = []
	for i in range(names.size()):
		var entry: Resource = LeaderboardEntryDataScript.new()
		entry.set("rank", i + 1)
		entry.set("player_name", names[i])
		entry.set("points", scores[i])
		entry.set("avatar_color", colors[i])
		entry.set("highlighted", i == 0)
		entries.append(entry)
	return entries


func _make_sample_tab(label_text: String, accent: Color, icon: Texture2D) -> Resource:
	var tab: Resource = LeaderboardTabDataScript.new()
	tab.set("label", label_text)
	tab.set("accent_color", accent)
	tab.set("icon_texture", icon)
	return tab


func _entry_from_dictionary(data: Dictionary) -> Resource:
	var entry: Resource = LeaderboardEntryDataScript.new()
	entry.set("rank", int(data.get("rank", 1)))
	entry.set("player_name", str(data.get("player_name", data.get("player", data.get("username", "Player")))))
	entry.set("points", int(data.get("points", data.get("total_points", data.get("score", 0)))))
	entry.set("avatar_texture", _texture_from_value(data.get("avatar_texture", data.get("avatar_path", null))))
	entry.set("avatar_color", _color_from_value(data.get("avatar_color", entry.get("avatar_color")), entry.get("avatar_color")))
	entry.set("reward_texture", _texture_from_value(data.get("reward_texture", data.get("reward_path", null))))
	entry.set("reward_label", str(data.get("reward_label", "")))
	entry.set("highlighted", bool(data.get("highlighted", false)))
	if data.has("row_fill"):
		entry.set("row_fill_override", _color_from_value(data.get("row_fill"), entry.get("row_fill_override")))
	if data.has("row_border"):
		entry.set("row_border_override", _color_from_value(data.get("row_border"), entry.get("row_border_override")))
	if data.has("name_color"):
		entry.set("name_color_override", _color_from_value(data.get("name_color"), entry.get("name_color_override")))
	if data.has("points_color"):
		entry.set("points_color_override", _color_from_value(data.get("points_color"), entry.get("points_color_override")))
	entry.set("metadata", data.duplicate(true))
	return entry


func _tab_from_dictionary(data: Dictionary) -> Resource:
	var tab: Resource = LeaderboardTabDataScript.new()
	tab.set("label", str(data.get("label", data.get("name", "TAB"))))
	tab.set("icon_texture", _texture_from_value(data.get("icon_texture", data.get("icon_path", null))))
	tab.set("accent_color", _color_from_value(data.get("accent_color", data.get("accent", tab.get("accent_color"))), tab.get("accent_color")))
	tab.set("tooltip", str(data.get("tooltip", "")))
	tab.set("disabled", bool(data.get("disabled", false)))
	tab.set("metadata", data.duplicate(true))
	return tab


func _tab_label(tab_data: Resource) -> String:
	return str(_resource_value(tab_data, "label", "TAB"))


func _tab_icon(tab_data: Resource, index: int) -> Texture2D:
	var texture := _texture_from_value(_resource_value(tab_data, "icon_texture", null))
	if texture != null:
		return texture
	if index == 0:
		return _resolve_event_icon_texture()
	return null


func _tab_accent(tab_data: Resource) -> Color:
	return _color_from_value(_resource_value(tab_data, "accent_color", button_green_color), button_green_color)


func _tab_tooltip(tab_data: Resource) -> String:
	return str(_resource_value(tab_data, "tooltip", ""))


func _tab_disabled(tab_data: Resource) -> bool:
	return bool(_resource_value(tab_data, "disabled", false))


func _resolve_event_icon_texture() -> Texture2D:
	if event_icon_texture != null:
		return event_icon_texture
	if auto_use_landfill_art and ResourceLoader.exists(DEFAULT_EVENT_ICON_PATH):
		return load(DEFAULT_EVENT_ICON_PATH) as Texture2D
	return null


func _resolve_header_texture() -> Texture2D:
	if header_background_texture != null:
		return header_background_texture
	if auto_use_landfill_art and ResourceLoader.exists(DEFAULT_HEADER_TEXTURE_PATH):
		return load(DEFAULT_HEADER_TEXTURE_PATH) as Texture2D
	return null


func _resource_value(resource: Resource, property_name: String, fallback):
	if resource == null:
		return fallback
	var value = resource.get(property_name)
	return fallback if value == null else value


func _texture_from_value(value) -> Texture2D:
	if value is Texture2D:
		return value
	if value is String:
		var path := str(value)
		if path != "" and ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null


func _color_from_value(value, fallback: Color) -> Color:
	if value is Color:
		return value
	if value is Array and value.size() >= 3:
		var alpha := 1.0
		if value.size() >= 4:
			alpha = float(value[3])
		return Color(float(value[0]), float(value[1]), float(value[2]), alpha)
	if value is String:
		var text := str(value)
		if text.begins_with("#"):
			return Color.html(text)
	return fallback


func _set_label_text(path: NodePath, text: String) -> void:
	var label := get_node_or_null(path) as Label
	if label != null:
		label.text = text


func _set_child_label_text(parent: Node, path: NodePath, text: String) -> void:
	var label := parent.get_node_or_null(path) as Label
	if label != null:
		label.text = text


func _child_label_text(parent: Node, path: NodePath, fallback: String) -> String:
	var label := parent.get_node_or_null(path) as Label
	if label == null:
		return fallback
	return label.text


func _style_label(path: NodePath, font_size: int, color: Color, align: HorizontalAlignment) -> void:
	var label := get_node_or_null(path) as Label
	if label == null:
		return
	label.horizontal_alignment = align
	PixelUIStyle.apply_label_shadow(label, font_size, color)


func _style_child_label(parent: Node, path: NodePath, font_size: int, color: Color, align: HorizontalAlignment) -> void:
	var label := parent.get_node_or_null(path) as Label
	if label == null:
		return
	label.horizontal_alignment = align
	PixelUIStyle.apply_label_shadow(label, font_size, color)


func _style_panel(path: NodePath, fill: Color, border: Color, border_width: int = 3, radius: int = 6, shadow_size: int = 4) -> void:
	var panel := get_node_or_null(path) as Panel
	if panel != null:
		panel.add_theme_stylebox_override("panel", _style(fill, border, border_width, radius, shadow_size))


func _style(fill: Color, border: Color, border_width: int = 3, radius: int = 6, shadow_size: int = 4) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(0.0, max(0.0, float(shadow_size) * 0.5))
	return style


func _apply_flat_button_style(button: Button, fill: Color, border: Color, font_size: int) -> void:
	PixelUIStyle.apply_button_text(button, font_size, body_text_color)
	button.add_theme_stylebox_override("normal", _style(fill, border, 3, 6, 4))
	button.add_theme_stylebox_override("hover", _style(_brighten(fill, 0.12), _brighten(border, 0.12), 3, 6, 5))
	button.add_theme_stylebox_override("pressed", _style(_darken(fill, 0.16), _darken(border, 0.08), 3, 6, 2))
	button.add_theme_stylebox_override("disabled", _style(_with_alpha(fill, 0.34), _with_alpha(border, 0.36), 3, 6, 1))
	button.focus_mode = Control.FOCUS_NONE
	button.expand_icon = true


func _apply_texture_if_present(texture_rect: TextureRect, texture: Texture2D) -> void:
	if texture_rect == null:
		return
	texture_rect.texture = texture
	texture_rect.visible = texture != null


func _brighten(color: Color, amount: float) -> Color:
	return Color(
		clamp(color.r + amount, 0.0, 1.0),
		clamp(color.g + amount, 0.0, 1.0),
		clamp(color.b + amount, 0.0, 1.0),
		color.a
	)


func _darken(color: Color, amount: float) -> Color:
	return Color(
		clamp(color.r - amount, 0.0, 1.0),
		clamp(color.g - amount, 0.0, 1.0),
		clamp(color.b - amount, 0.0, 1.0),
		color.a
	)


func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)


func _rank_color(rank: int) -> Color:
	match rank:
		1:
			return Color(1.0, 0.82, 0.18, 1.0)
		2:
			return Color(0.82, 0.88, 0.92, 1.0)
		3:
			return Color(0.95, 0.54, 0.19, 1.0)
		_:
			return body_text_color


func _format_number(value: int) -> String:
	var negative := value < 0
	var digits := str(abs(value))
	var result := ""
	var group_count := 0
	for i in range(digits.length() - 1, -1, -1):
		if group_count == 3:
			result = "," + result
			group_count = 0
		result = digits.substr(i, 1) + result
		group_count += 1
	return ("-" if negative else "") + result


func _initials_for(player_name: String) -> String:
	var cleaned := player_name.strip_edges()
	if cleaned == "":
		return "?"
	var pieces := cleaned.split(" ", false)
	if pieces.size() >= 2:
		return (pieces[0].substr(0, 1) + pieces[1].substr(0, 1)).to_upper()
	return cleaned.substr(0, min(2, cleaned.length())).to_upper()


func _on_tab_button_pressed(index: int) -> void:
	var effective_tabs := _get_effective_tabs()
	if index < 0 or index >= effective_tabs.size():
		return
	selected_tab_index = index
	tab_selected.emit(index, effective_tabs[index])
	_apply_tabs_content()
	_apply_tabs_style()


func _on_rewards_pressed() -> void:
	rewards_pressed.emit()


func _on_close_pressed() -> void:
	close_pressed.emit()
	if close_button_hides_scene:
		visible = false
