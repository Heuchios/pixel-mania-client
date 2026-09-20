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
@export var title_text: String = "LANDFILL":
	set(value):
		if title_text == value:
			return
		title_text = value
		_queue_refresh()
@export var badge_text: String = "EVENT LEADERBOARD":
	set(value):
		if badge_text == value:
			return
		badge_text = value
		_queue_refresh()
@export var subtitle_text: String = "Compete in the Landfill Race and earn points!":
	set(value):
		if subtitle_text == value:
			return
		subtitle_text = value
		_queue_refresh()
@export var rank_header_text: String = "RANK":
	set(value):
		if rank_header_text == value:
			return
		rank_header_text = value
		_queue_refresh()
@export var player_header_text: String = "PLAYER":
	set(value):
		if player_header_text == value:
			return
		player_header_text = value
		_queue_refresh()
@export var points_header_text: String = "TOTAL POINTS":
	set(value):
		if points_header_text == value:
			return
		points_header_text = value
		_queue_refresh()
@export var points_suffix: String = "":
	set(value):
		if points_suffix == value:
			return
		points_suffix = value
		_queue_refresh()
@export var tabs: Array[Resource] = []:
	set(value):
		if tabs == value:
			return
		tabs = value
		_queue_refresh()
@export var leaderboard_entries: Array[Resource] = []:
	set(value):
		if leaderboard_entries == value:
			return
		leaderboard_entries = value
		_queue_refresh()
@export var show_sample_data_when_empty: bool = true:
	set(value):
		if show_sample_data_when_empty == value:
			return
		show_sample_data_when_empty = value
		_queue_refresh()
@export var apply_exported_content_on_ready: bool = true:
	set(value):
		if apply_exported_content_on_ready == value:
			return
		apply_exported_content_on_ready = value
		_queue_refresh()
@export var apply_exported_styles_on_ready: bool = true:
	set(value):
		if apply_exported_styles_on_ready == value:
			return
		apply_exported_styles_on_ready = value
		_queue_refresh()

@export_category("Personal Summary")
@export var summary_rank_label: String = "YOUR RANK":
	set(value):
		if summary_rank_label == value:
			return
		summary_rank_label = value
		_queue_refresh()
@export var summary_points_label: String = "YOUR POINTS":
	set(value):
		if summary_points_label == value:
			return
		summary_points_label = value
		_queue_refresh()
@export var summary_timer_label: String = "EVENT ENDS IN:":
	set(value):
		if summary_timer_label == value:
			return
		summary_timer_label = value
		_queue_refresh()
@export var summary_rank_value: String = "15":
	set(value):
		if summary_rank_value == value:
			return
		summary_rank_value = value
		_queue_refresh()
@export var summary_points_value: int = 1240:
	set(value):
		if summary_points_value == value:
			return
		summary_points_value = value
		_queue_refresh()
@export var summary_timer_value: String = "4D 12H 36M":
	set(value):
		if summary_timer_value == value:
			return
		summary_timer_value = value
		_queue_refresh()
@export var rewards_button_text: String = "REWARDS":
	set(value):
		if rewards_button_text == value:
			return
		rewards_button_text = value
		_queue_refresh()

@export_category("Behavior")
@export var selected_tab_index: int = 0:
	set(value):
		if selected_tab_index == value:
			return
		selected_tab_index = value
		_queue_refresh()
@export var close_button_hides_scene: bool = true
@export var show_close_button: bool = true:
	set(value):
		if show_close_button == value:
			return
		show_close_button = value
		_queue_refresh()
@export var show_rewards_button: bool = true:
	set(value):
		if show_rewards_button == value:
			return
		show_rewards_button = value
		_queue_refresh()
@export var show_dimmer: bool = true:
	set(value):
		if show_dimmer == value:
			return
		show_dimmer = value
		_queue_refresh()
@export var show_side_art_panel: bool = true:
	set(value):
		if show_side_art_panel == value:
			return
		show_side_art_panel = value
		_queue_refresh()
@export var auto_use_landfill_art: bool = true:
	set(value):
		if auto_use_landfill_art == value:
			return
		auto_use_landfill_art = value
		_queue_refresh()
@export var auto_fit_to_viewport: bool = true:
	set(value):
		if auto_fit_to_viewport == value:
			return
		auto_fit_to_viewport = value
		_queue_refresh()

@export_category("Layout")
@export var window_size: Vector2 = Vector2(1032.0, 688.0):
	set(value):
		if window_size == value:
			return
		window_size = value
		_queue_refresh()
@export var viewport_margin: Vector2 = Vector2(42.0, 32.0):
	set(value):
		if viewport_margin == value:
			return
		viewport_margin = value
		_queue_refresh()

@export_category("Textures")
@export var header_background_texture: Texture2D = null:
	set(value):
		if header_background_texture == value:
			return
		header_background_texture = value
		_queue_refresh()
@export var event_icon_texture: Texture2D = null:
	set(value):
		if event_icon_texture == value:
			return
		event_icon_texture = value
		_queue_refresh()
@export var currency_icon_texture: Texture2D = preload("res://Assets/currency/gem.png"):
	set(value):
		if currency_icon_texture == value:
			return
		currency_icon_texture = value
		_queue_refresh()
@export var reward_icon_texture: Texture2D = preload("res://Assets/currency/gem.png"):
	set(value):
		if reward_icon_texture == value:
			return
		reward_icon_texture = value
		_queue_refresh()
@export var default_avatar_texture: Texture2D = null:
	set(value):
		if default_avatar_texture == value:
			return
		default_avatar_texture = value
		_queue_refresh()

@export_category("Colors")
@export var dimmer_color: Color = Color(0.0, 0.0, 0.0, 0.48):
	set(value):
		if dimmer_color == value:
			return
		dimmer_color = value
		_queue_refresh()
@export var panel_fill_color: Color = Color(0.055, 0.065, 0.064, 0.96):
	set(value):
		if panel_fill_color == value:
			return
		panel_fill_color = value
		_queue_refresh()
@export var panel_border_color: Color = Color(0.58, 0.57, 0.54, 0.95):
	set(value):
		if panel_border_color == value:
			return
		panel_border_color = value
		_queue_refresh()
@export var inner_fill_color: Color = Color(0.045, 0.074, 0.074, 0.86):
	set(value):
		if inner_fill_color == value:
			return
		inner_fill_color = value
		_queue_refresh()
@export var inner_border_color: Color = Color(0.23, 0.30, 0.31, 0.92):
	set(value):
		if inner_border_color == value:
			return
		inner_border_color = value
		_queue_refresh()
@export var title_color: Color = Color(0.42, 0.86, 0.22, 1.0):
	set(value):
		if title_color == value:
			return
		title_color = value
		_queue_refresh()
@export var badge_color: Color = Color(1.0, 0.86, 0.10, 1.0):
	set(value):
		if badge_color == value:
			return
		badge_color = value
		_queue_refresh()
@export var header_text_color: Color = Color(0.55, 0.88, 0.25, 1.0):
	set(value):
		if header_text_color == value:
			return
		header_text_color = value
		_queue_refresh()
@export var body_text_color: Color = Color(0.94, 0.96, 0.94, 1.0):
	set(value):
		if body_text_color == value:
			return
		body_text_color = value
		_queue_refresh()
@export var muted_text_color: Color = Color(0.74, 0.78, 0.76, 1.0):
	set(value):
		if muted_text_color == value:
			return
		muted_text_color = value
		_queue_refresh()
@export var row_fill_color: Color = Color(0.035, 0.070, 0.070, 0.92):
	set(value):
		if row_fill_color == value:
			return
		row_fill_color = value
		_queue_refresh()
@export var row_alt_fill_color: Color = Color(0.050, 0.085, 0.083, 0.92):
	set(value):
		if row_alt_fill_color == value:
			return
		row_alt_fill_color = value
		_queue_refresh()
@export var row_border_color: Color = Color(0.17, 0.23, 0.24, 0.95):
	set(value):
		if row_border_color == value:
			return
		row_border_color = value
		_queue_refresh()
@export var top_rank_fill_color: Color = Color(0.48, 0.34, 0.06, 0.90):
	set(value):
		if top_rank_fill_color == value:
			return
		top_rank_fill_color = value
		_queue_refresh()
@export var top_rank_border_color: Color = Color(0.95, 0.64, 0.09, 0.95):
	set(value):
		if top_rank_border_color == value:
			return
		top_rank_border_color = value
		_queue_refresh()
@export var button_green_color: Color = Color(0.30, 0.70, 0.18, 1.0):
	set(value):
		if button_green_color == value:
			return
		button_green_color = value
		_queue_refresh()
@export var button_blue_color: Color = Color(0.13, 0.24, 0.30, 1.0):
	set(value):
		if button_blue_color == value:
			return
		button_blue_color = value
		_queue_refresh()
@export var close_button_color: Color = Color(0.82, 0.16, 0.10, 1.0):
	set(value):
		if close_button_color == value:
			return
		close_button_color = value
		_queue_refresh()

@export_category("Scrollbar")
# The row list's vertical scrollbar (RowsClip) has no hand-editable node of its own in this
# scene -- Godot generates it internally on the ScrollContainer -- so unlike the panels/buttons
# above, there is nothing here for a hand styling pass to protect. Styled unconditionally in
# _ready()/refresh_preview() (not gated behind apply_exported_styles_on_ready) so it actually
# shows up in the running game and not just the editor preview. The setters below are what make
# these (and every other color/text/font field above) actually update live as you drag/pick in
# the Inspector -- see _queue_refresh()/refresh_preview() further down. Without a setter here, a
# changed export value just sits there until something else happens to redraw the scene.
@export var scrollbar_track_color: Color = Color(0.035, 0.055, 0.055, 0.85):
	set(value):
		if scrollbar_track_color == value:
			return
		scrollbar_track_color = value
		_queue_refresh()
@export var scrollbar_grabber_color: Color = Color(0.36, 0.78, 0.23, 0.90):
	set(value):
		if scrollbar_grabber_color == value:
			return
		scrollbar_grabber_color = value
		_queue_refresh()
@export var scrollbar_grabber_hover_color: Color = Color(0.52, 0.92, 0.34, 0.95):
	set(value):
		if scrollbar_grabber_hover_color == value:
			return
		scrollbar_grabber_hover_color = value
		_queue_refresh()
@export var scrollbar_grabber_pressed_color: Color = Color(0.24, 0.58, 0.14, 1.0):
	set(value):
		if scrollbar_grabber_pressed_color == value:
			return
		scrollbar_grabber_pressed_color = value
		_queue_refresh()
@export_range(4, 20, 1) var scrollbar_thickness: int = 10:
	set(value):
		if scrollbar_thickness == value:
			return
		scrollbar_thickness = value
		_queue_refresh()

@export_category("Typography")
@export_range(18, 72, 1) var title_font_size: int = 32:
	set(value):
		if title_font_size == value:
			return
		title_font_size = value
		_queue_refresh()
@export_range(12, 40, 1) var badge_font_size: int = 18:
	set(value):
		if badge_font_size == value:
			return
		badge_font_size = value
		_queue_refresh()
@export_range(10, 32, 1) var subtitle_font_size: int = 16:
	set(value):
		if subtitle_font_size == value:
			return
		subtitle_font_size = value
		_queue_refresh()
@export_range(10, 30, 1) var header_font_size: int = 15:
	set(value):
		if header_font_size == value:
			return
		header_font_size = value
		_queue_refresh()
@export_range(10, 34, 1) var row_font_size: int = 21:
	set(value):
		if row_font_size == value:
			return
		row_font_size = value
		_queue_refresh()
@export_range(10, 36, 1) var points_font_size: int = 22:
	set(value):
		if points_font_size == value:
			return
		points_font_size = value
		_queue_refresh()
@export_range(10, 34, 1) var summary_font_size: int = 22:
	set(value):
		if summary_font_size == value:
			return
		summary_font_size = value
		_queue_refresh()

@onready var dimmer: ColorRect = get_node_or_null("Dimmer") as ColorRect
@onready var center_container: CenterContainer = get_node_or_null("CenterContainer") as CenterContainer
@onready var leaderboard_window: Control = get_node_or_null("CenterContainer/LeaderboardWindow") as Control
@onready var header_panel: Panel = get_node_or_null("CenterContainer/LeaderboardWindow/HeaderPanel") as Panel
@onready var header_background: TextureRect = get_node_or_null("CenterContainer/LeaderboardWindow/HeaderPanel/HeaderBackground") as TextureRect
@onready var side_texture: TextureRect = get_node_or_null("CenterContainer/LeaderboardWindow/SideColumn/SideArtPanel/SideTexture") as TextureRect
@onready var tabs_root: Control = get_node_or_null("CenterContainer/LeaderboardWindow/SideColumn/Tabs") as Control
@onready var rows_clip: ScrollContainer = get_node_or_null("CenterContainer/LeaderboardWindow/TablePanel/RowsClip") as ScrollContainer
@onready var rows_root: Control = get_node_or_null("CenterContainer/LeaderboardWindow/TablePanel/RowsClip/RowsRoot") as Control

var _refresh_queued := false


func _queue_refresh() -> void:
	if not is_inside_tree():
		return
	if _refresh_queued:
		return
	_refresh_queued = true
	call_deferred("_run_queued_refresh")


func _run_queued_refresh() -> void:
	_refresh_queued = false
	refresh_preview()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_window_size()
	_connect_static_buttons()
	if apply_exported_content_on_ready:
		apply_exported_content()
	if apply_exported_styles_on_ready:
		apply_exported_styles()
	_style_scrollbar()
	_update_visibility_flags()
	_update_window_scale()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_window_scale()


func refresh_preview() -> void:
	_apply_window_size()
	if apply_exported_content_on_ready:
		apply_exported_content()
	if apply_exported_styles_on_ready:
		apply_exported_styles()
	_style_scrollbar()
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

	if header_background != null:
		header_background.hide()
	if side_texture != null:
		side_texture.hide()
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

	_style_label("CenterContainer/LeaderboardWindow/HeaderPanel/TitleLabel", title_font_size, title_color, HORIZONTAL_ALIGNMENT_LEFT)
	_style_label("CenterContainer/LeaderboardWindow/HeaderPanel/BadgeBack/BadgeLabel", badge_font_size, badge_color, HORIZONTAL_ALIGNMENT_LEFT)
	_style_label("CenterContainer/LeaderboardWindow/HeaderPanel/SubtitleLabel", subtitle_font_size, body_text_color, HORIZONTAL_ALIGNMENT_LEFT)
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
	for index in range(_get_tab_buttons().size()):
		var tab_button := _get_tab_buttons()[index]
		PixelUIStyle.apply_atlas_button(tab_button, "green_button" if index == selected_tab_index else "pink_button")
		tab_button.add_theme_font_size_override("font_size", 17)
		tab_button.add_theme_color_override("font_color", Color(0.18, 0.08, 0.23))
		tab_button.add_theme_color_override("font_hover_color", Color(0.3, 0.13, 0.38))
		tab_button.add_theme_constant_override("icon_max_width", 30)
	_style_label("CenterContainer/LeaderboardWindow/SideColumn/SideArtPanel/Guide", 14, body_text_color, HORIZONTAL_ALIGNMENT_LEFT)
	var find_button := get_node_or_null("CenterContainer/LeaderboardWindow/SideColumn/SideArtPanel/FindMeButton") as Button
	if find_button != null:
		_apply_flat_button_style(find_button, Color(0.2, 0.5, 1), Color.BLACK, 16)
		find_button.disabled = not _has_personal_row()
		find_button.tooltip_text = "Jump to your ranking" if not find_button.disabled else "Your row is not in the loaded rankings; check your summary below."
		if not find_button.pressed.is_connected(_find_personal_row):
			find_button.pressed.connect(_find_personal_row)
	_apply_rows_style()


# Skins RowsClip's vertical scrollbar to match the panel instead of the engine default gray one.
# ScrollContainer doesn't expose its scrollbar as theme_override_styles on itself -- Godot builds
# an actual VScrollBar/HScrollBar child at runtime, reachable only via get_v_scroll_bar()/
# get_h_scroll_bar(), so this has to run in script rather than being paintable directly on a node
# in the Scene tree the way CloseButton/RewardsButton's textures are. Unconditional (see the
# Scrollbar export category above for why) -- called from _ready() and refresh_preview(), not
# from apply_exported_styles().
func _style_scrollbar() -> void:
	if rows_clip == null:
		return

	var track_style := PixelUIStyle.atlas_style("scroll_bar", Color.WHITE, 0)
	var grabber_style := PixelUIStyle.atlas_style("scroll_handle", Color.WHITE, 0)
	var grabber_hover_style := PixelUIStyle.atlas_style("scroll_handle", Color(1.15, 1.15, 1.15), 0)
	var grabber_pressed_style := PixelUIStyle.atlas_style("scroll_handle", Color(0.72, 0.72, 0.72), 0)

	var v_bar := rows_clip.get_v_scroll_bar()
	if v_bar != null:
		v_bar.custom_minimum_size.x = scrollbar_thickness
		v_bar.add_theme_stylebox_override("scroll", track_style)
		v_bar.add_theme_stylebox_override("scroll_focus", track_style)
		v_bar.add_theme_stylebox_override("grabber", grabber_style)
		v_bar.add_theme_stylebox_override("grabber_highlight", grabber_hover_style)
		v_bar.add_theme_stylebox_override("grabber_pressed", grabber_pressed_style)

	var h_bar := rows_clip.get_h_scroll_bar()
	if h_bar != null:
		h_bar.custom_minimum_size.y = scrollbar_thickness
		h_bar.add_theme_stylebox_override("scroll", track_style)
		h_bar.add_theme_stylebox_override("scroll_focus", track_style)
		h_bar.add_theme_stylebox_override("grabber", grabber_style)
		h_bar.add_theme_stylebox_override("grabber_highlight", grabber_hover_style)
		h_bar.add_theme_stylebox_override("grabber_pressed", grabber_pressed_style)


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
	# _apply_tabs_content() above still syncs .text/.icon/.button_pressed -- needed so the
	# selected tab and real data stay correct. The STYLE repaint is different: it always
	# overwrote hand-styled tab buttons with a flat programmatic color, even when
	# apply_exported_styles_on_ready is off (the "leave my node edits alone" switch every other
	# repaint call site in this file already honors). That meant a custom StyleBoxTexture on
	# TabLandfill/TabWeekly/TabGlobal got clobbered the instant a player opened the panel or
	# clicked a tab, in-editor styling be damned. Gate it the same way _ready()/refresh_preview()
	# already do.
	if apply_exported_styles_on_ready:
		apply_exported_styles()


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
		var row_style := StyleBoxFlat.new()
		row_style.bg_color = Color(0.25, 0.13, 0.30) if i % 2 == 0 else Color(0.20, 0.10, 0.25)
		if highlighted:
			row_style.bg_color = Color(0.32, 0.23, 0.18)
		row.add_theme_stylebox_override("panel", row_style)
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
	var name_color := Color(0.94, 0.91, 0.98)
	var points_color := Color(0.94, 0.91, 0.98)
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
	label.set_meta("pixelmania_font_role", "preserve")
	PixelUIStyle.apply_label_shadow(label, font_size, color)
	label.add_theme_font_size_override("font_size", font_size)


func _style_child_label(parent: Node, path: NodePath, font_size: int, color: Color, align: HorizontalAlignment) -> void:
	var label := parent.get_node_or_null(path) as Label
	if label == null:
		return
	label.horizontal_alignment = align
	label.set_meta("pixelmania_font_role", "preserve")
	PixelUIStyle.apply_label_shadow(label, font_size, color)
	label.add_theme_font_size_override("font_size", font_size)


func _style_panel(path: NodePath, fill: Color, border: Color, border_width: int = 3, radius: int = 6, shadow_size: int = 4) -> void:
	var panel := get_node_or_null(path) as Panel
	if panel != null:
		if str(path).ends_with("/WindowBack"):
			panel.add_theme_stylebox_override("panel", PixelUIStyle.atlas_style("outer_panel", Color.WHITE, float(border_width)))
		else:
			panel.add_theme_stylebox_override("panel", _style(fill, border, border_width, radius, shadow_size))


func _style(fill: Color, _border: Color, border_width: int = 3, _radius: int = 6, _shadow_size: int = 4) -> StyleBoxTexture:
	return PixelUIStyle.atlas_style("inner_panel", Color(1, 1, 1, fill.a), float(border_width))


func _apply_flat_button_style(button: Button, fill: Color, _border: Color, font_size: int) -> void:
	button.set_meta("pixelmania_font_role", "preserve")
	PixelUIStyle.apply_button_text(button, font_size, body_text_color)
	button.add_theme_font_size_override("font_size", font_size)
	var region := "blue_button"
	if fill.r > fill.g * 1.5: region = "red_button"
	elif fill.g > fill.b * 1.5: region = "green_button"
	PixelUIStyle.apply_atlas_button(button, region)
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
	# Same reasoning as select_tab() above -- don't repaint hand-styled tab buttons on click when
	# the scene was told to leave styling alone.
	if apply_exported_styles_on_ready:
		apply_exported_styles()


func _on_rewards_pressed() -> void:
	rewards_pressed.emit()


func _on_close_pressed() -> void:
	close_pressed.emit()
	if close_button_hides_scene:
		visible = false


func _find_personal_row() -> void:
	for row in _get_row_nodes():
		if row.visible and _child_label_text(row, "RankNumber", "") == summary_rank_value:
			rows_clip.ensure_control_visible(row)
			return
	var find_button := get_node_or_null("CenterContainer/LeaderboardWindow/SideColumn/SideArtPanel/FindMeButton") as Button
	if find_button != null:
		find_button.tooltip_text = "Your rank is shown below; your row is outside the loaded rankings."


func _has_personal_row() -> bool:
	if summary_rank_value.to_int() <= 0:
		return false
	for row in _get_row_nodes():
		if row.visible and _child_label_text(row, "RankNumber", "") == summary_rank_value:
			return true
	return false
