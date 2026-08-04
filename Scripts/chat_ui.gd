extends Control

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")

const CHAT_PANEL_HEIGHT = 448.0
const CHAT_OPEN_SPEED = 9.0
const MAX_CHAT_MESSAGES = 50
const CHAT_SCROLL_BOTTOM_THRESHOLD := 24
const CHAT_SCROLL_SLIDER_MAX := 1000.0
const CHAT_SCROLL_SLIDER_PAGE := 150.0
const UI_STYLE_PATH = "res://Assets/ui/pixelmania/"
const CHAT_MAX_WIDTH = 1680.0
const CHAT_MIN_WIDTH = 1000.0
const CHAT_SIDE_MARGIN = 10.0
const CHAT_HEADER_HEIGHT = 60.0
const CHAT_HANDLE_HEIGHT = 26.0
const CHAT_BUTTON_Y = 232.0
const CHAT_BUTTON_SIZE = Vector2(64, 64)
const MESSAGE_ICON_PATH = "res://Assets/ui/icons/message.png"
const BROADCAST_HOLD_SECONDS = 0.55
const BROADCAST_HOLD_MOVE_CANCEL = 18.0
const CHAT_FONT_PATH = "res://Assets/font/font.ttf"
const CHAT_MESSAGE_FONT_SIZE := 24
const CHAT_MESSAGE_LINE_HEIGHT := 31.0
const CHAT_MESSAGE_PAD_X = 12.0
const CHAT_MESSAGE_PAD_Y = 6.0
const CHAT_MESSAGE_MIN_ROW_HEIGHT = 42.0
const CHAT_FILTER_WORLD = "world"
const CHAT_FILTER_LOCAL = "local"
const CHAT_FILTER_SYSTEM = "system"
const CHAT_CONTENT_FILTER_WORDS: Array[String] = [
	"ass",
	"asshole",
	"bastard",
	"bitch",
	"bullshit",
	"crap",
	"cunt",
	"damn",
	"dick",
	"douche",
	"fag",
	"faggot",
	"fuck",
	"motherfucker",
	"nigga",
	"nigger",
	"piss",
	"prick",
	"pussy",
	"shit",
	"slut",
	"whore"
]
const CHAT_SYSTEM_COLOR = Color(1.0, 0.86, 0.22, 1.0)
const NOTIFICATION_BUBBLE_TEXT_COLOR = Color(1.0, 0.58, 0.12, 1.0)
const BUBBLE_KIND_NONE = ""
const BUBBLE_KIND_CHAT = "chat"
const BUBBLE_KIND_NOTIFICATION = "notification"
const CHAT_BUBBLE_COMPONENT = preload("res://Scripts/chat_bubble_component.gd")

var player = null
var world = null
var ui_layer_ref = null

var chat_panel = null
var chat_handle = null
var chat_messages_root = null
var chat_messages_scroll = null
var chat_messages_scroll_slider = null
var chat_input = null
var chat_send_button = null
var chat_button = null
var chat_button_icon = null
var chat_button_icon_shadow = null
var chat_button_tween = null
var quick_chat_bar = null
var quick_chat_input = null
var quick_chat_send_button = null
var title_label = null
var close_button = null
var messages_panel = null
var handle_label = null
var hint_label = null
var channel_tabs = null
var chat_world_tab = null
var chat_local_tab = null
var chat_system_tab = null
var chat_tab_selected_style = null
var chat_tab_normal_style = null
var using_authored_scene_layout := false
var authored_panel_content_nodes: Array = []
var authored_chat_panel_size := Vector2.ZERO
var authored_chat_panel_visual_bounds := Rect2(Vector2.ZERO, Vector2.ZERO)
var authored_chat_handle_rect := Rect2(Vector2.ZERO, Vector2.ZERO)
var authored_quick_chat_size := Vector2.ZERO
var chat_button_icon_base_position := Vector2.ZERO
var chat_button_shadow_base_position := Vector2(5, 7)

var chat_messages = []
var chat_panel_amount = 0.0
var chat_panel_target = 0.0

var chat_bubble_node = null
var active_bubble_kind := BUBBLE_KIND_NONE

var chat_drag_active = false
var chat_drag_start_y = 0.0
var chat_drag_start_amount = 0.0
var chat_handle_dragged = false
var chat_handle_drag_index = -1
const CHAT_HANDLE_DRAG_TAP_THRESHOLD := 6.0
const CHAT_HANDLE_TOUCH_PADDING := Vector2(30.0, 18.0)
var quick_chat_active = false
var chat_button_hovered = false
var chat_scroll_slider_syncing := false
var chat_scroll_programmatic := false
var chat_scroll_stick_to_bottom := true
var chat_message_refresh_generation := 0
var chat_filter_mode := CHAT_FILTER_WORLD
var chat_content_filter_enabled := true

var is_setup = false
var chat_font: Font = null


func get_ui_texture(file_name: String):
	var path = UI_STYLE_PATH + file_name
	if ResourceLoader.exists(path):
		return load(path)
	return null


func get_chat_font() -> Font:
	if chat_font == null and ResourceLoader.exists(CHAT_FONT_PATH):
		var loaded_font: Resource = load(CHAT_FONT_PATH)
		if loaded_font is Font:
			chat_font = loaded_font
	return chat_font


func apply_chat_font_to_control(control: Control) -> void:
	if control == null:
		return

	var font := get_chat_font()
	if font == null:
		return

	control.add_theme_font_override("font", font)
	if control is Label:
		var label := control as Label
		if label.label_settings != null:
			label.label_settings.font = font


func apply_chat_font_to_tree(root: Node) -> void:
	if root == null:
		return

	if root is Control:
		apply_chat_font_to_control(root as Control)

	for child in root.get_children():
		apply_chat_font_to_tree(child)


func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	setup_chat_ui()


func _process(delta):
	if not chat_drag_active:
		chat_panel_amount = move_toward(
			chat_panel_amount,
			chat_panel_target,
			delta * CHAT_OPEN_SPEED
		)
	clear_notification_bubble_if_chat_active()
	update_chat_bubble(delta)
	update_chat_position()


func _input(event):
	if handle_global_chat_handle_touch_input(event):
		get_viewport().set_input_as_handled()


func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if is_chat_input_focused():
				send_chat_message()
				get_viewport().set_input_as_handled()
			else:
				if not can_focus_chat_from_keyboard():
					return
				focus_chat_input()
				get_viewport().set_input_as_handled()
			return

		if event.keycode == KEY_T:
			if not can_focus_chat_from_keyboard():
				return
			focus_chat_input()
			get_viewport().set_input_as_handled()
			return

		if event.keycode == KEY_ESCAPE:
			if is_chat_input_focused():
				release_chat_focus()
				get_viewport().set_input_as_handled()


func set_player(new_player):
	var player_changed: bool = player != new_player
	player = new_player
	_ensure_local_chat_bubble_anchor()
	if player_changed or chat_bubble_node == null or not is_instance_valid(chat_bubble_node):
		setup_chat_bubble()


func set_world(new_world):
	world = new_world
	if new_world != null and "ui_layer" in new_world:
		ui_layer_ref = new_world.ui_layer


func set_chat_content_filter_enabled(enabled: bool) -> void:
	if chat_content_filter_enabled == enabled:
		return
	chat_content_filter_enabled = enabled
	refresh_chat_messages()


func is_chat_content_filter_enabled() -> bool:
	return chat_content_filter_enabled


func get_filtered_chat_text(message: String) -> String:
	if not chat_content_filter_enabled:
		return message
	return filter_inappropriate_chat_text(message)


func get_display_chat_text(message: String, metadata: Dictionary) -> String:
	if not chat_content_filter_enabled:
		return message
	var server_filtered_message := str(metadata.get("filtered_message", "")).strip_edges()
	if server_filtered_message != "":
		return server_filtered_message
	return filter_inappropriate_chat_text(message)


func filter_inappropriate_chat_text(message: String) -> String:
	var result := ""
	var token := ""
	for i in range(message.length()):
		var character := message.substr(i, 1)
		if is_chat_word_character(character):
			token += character
			continue
		result += censor_chat_token(token)
		token = ""
		result += character
	result += censor_chat_token(token)
	return result


func censor_chat_token(token: String) -> String:
	if token == "":
		return ""
	var normalized := normalize_chat_filter_token(token)
	if CHAT_CONTENT_FILTER_WORDS.has(normalized):
		return "*".repeat(max(3, token.length()))
	return token


func normalize_chat_filter_token(token: String) -> String:
	var lower_token := token.to_lower()
	var normalized := ""
	for i in range(lower_token.length()):
		var character := lower_token.substr(i, 1)
		match character:
			"0":
				normalized += "o"
			"1", "!":
				normalized += "i"
			"3":
				normalized += "e"
			"4", "@":
				normalized += "a"
			"5", "$":
				normalized += "s"
			"7":
				normalized += "t"
			_:
				normalized += character
	return normalized


func is_chat_word_character(character: String) -> bool:
	if character.length() != 1:
		return false
	var code := character.unicode_at(0)
	return (
		(code >= 48 and code <= 57)
		or (code >= 65 and code <= 90)
		or (code >= 97 and code <= 122)
		or character == "!"
		or character == "$"
		or character == "@"
	)


func setup(parent_world):
	set_world(parent_world)
	if parent_world != null and "player" in parent_world:
		set_player(parent_world.player)
	setup_chat_ui()
	update_chat_position()


func restore_after_world_enter():
	setup_chat_ui()
	if world != null and "player" in world:
		set_player(world.player)
	update_chat_position()


func can_focus_chat_from_keyboard() -> bool:
	if world == null:
		return true

	if world.has_method("is_movement_blocking_ui_open") and world.is_movement_blocking_ui_open():
		return false

	if world.has_method("is_any_text_input_focused") and world.is_any_text_input_focused() and not is_chat_input_focused():
		return false

	if "fishing_active" in world and bool(world.fishing_active):
		return false

	return true


func setup_chat_ui():
	if is_setup:
		if chat_bubble_node == null:
			setup_chat_bubble()
		update_chat_position()
		return
	is_setup = true
	if bind_authored_chat_scene():
		setup_chat_bubble()
		add_chat_message("System", "Chat ready.")
		update_chat_position()
		refresh_chat_messages(true)
		return

	chat_panel = get_node_or_null("ChatPanel")
	if chat_panel != null and not (chat_panel is Panel):
		chat_panel.name = "OldChatPanel"
		chat_panel.queue_free()
		chat_panel = null
	if chat_panel == null:
		chat_panel = Panel.new()
		chat_panel.name = "ChatPanel"
		add_child(chat_panel)
	chat_panel.size = Vector2(1560, CHAT_PANEL_HEIGHT)
	chat_panel.visible = true
	chat_panel.z_index = 120
	chat_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	chat_panel.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.050, 0.120, 0.175, 0.42),
		Color(0.18, 0.46, 0.76, 0.72),
		3, 18, 8
	))
	if not chat_panel.gui_input.is_connected(_on_chat_panel_gui_input):
		chat_panel.gui_input.connect(_on_chat_panel_gui_input)
	for child in chat_panel.get_children():
		child.queue_free()
	var top_bar = Panel.new()
	top_bar.name = "TopBar"
	top_bar.position = Vector2.ZERO
	top_bar.size = Vector2(1532, CHAT_HEADER_HEIGHT)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.070, 0.150, 0.235, 0.62),
		Color(0.030, 0.100, 0.170, 0.66),
		1, 18, 5
	))
	chat_panel.add_child(top_bar)
	var header_gloss = ColorRect.new()
	header_gloss.name = "HeaderGloss"
	header_gloss.position = Vector2(18, 12)
	header_gloss.size = Vector2(1450, 16)
	header_gloss.color = Color(0.80, 0.95, 1.0, 0.10)
	header_gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat_panel.add_child(header_gloss)
	var header_line = ColorRect.new()
	header_line.name = "HeaderLine"
	header_line.position = Vector2(0, CHAT_HEADER_HEIGHT - 5.0)
	header_line.size = Vector2(1532, 4)
	header_line.color = Color(0.42, 0.72, 1.0, 0.55)
	header_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat_panel.add_child(header_line)
	title_label = Label.new()
	title_label.name = "Title"
	title_label.text = "CHAT"
	title_label.position = Vector2(28, 10)
	title_label.size = Vector2(260, 42)
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(title_label, 31, Color(0.96, 0.99, 1.0, 1.0))
	chat_panel.add_child(title_label)
	hint_label = Label.new()
	hint_label.name = "Hint"
	hint_label.text = "WORLD MESSAGES"
	hint_label.position = Vector2(118, 23)
	hint_label.size = Vector2(360, 24)
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(hint_label, 13)
	chat_panel.add_child(hint_label)
	close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "X"
	close_button.size = Vector2(42, 36)
	close_button.position = Vector2(1508, 10)
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.visible = true
	PixelUIStyle.apply_close_button(close_button)
	close_button.pressed.connect(close_chat_panel)
	if not close_button.gui_input.is_connected(_on_chat_wheel_gui_input):
		close_button.gui_input.connect(_on_chat_wheel_gui_input)
	chat_panel.add_child(close_button)
	messages_panel = Panel.new()
	messages_panel.name = "MessagesPanel"
	messages_panel.position = Vector2(18, 92)
	messages_panel.size = Vector2(1528, 342)
	messages_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	messages_panel.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.070, 0.150, 0.205, 0.30),
		Color(0.30, 0.66, 0.92, 0.46),
		3, 14, 3
	))
	chat_panel.add_child(messages_panel)
	chat_messages_scroll = ScrollContainer.new()
	chat_messages_scroll.name = "MessagesScroll"
	chat_messages_scroll.position = Vector2(26, 74)
	chat_messages_scroll.size = Vector2(1508, 322)
	chat_messages_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	chat_messages_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	chat_messages_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	if not chat_messages_scroll.gui_input.is_connected(_on_chat_panel_gui_input):
		chat_messages_scroll.gui_input.connect(_on_chat_panel_gui_input)
	chat_panel.add_child(chat_messages_scroll)
	apply_chat_scrollbar_style()
	chat_messages_root = VBoxContainer.new()
	chat_messages_root.name = "Messages"
	chat_messages_root.position = Vector2.ZERO
	chat_messages_root.size = Vector2(1488, 322)
	chat_messages_root.custom_minimum_size = Vector2(1488, 322)
	chat_messages_root.add_theme_constant_override("separation", 5)
	chat_messages_root.alignment = BoxContainer.ALIGNMENT_END
	chat_messages_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat_messages_scroll.add_child(chat_messages_root)
	chat_input = LineEdit.new()
	chat_input.name = "ChatInput"
	chat_input.placeholder_text = "Type message or /command..."
	chat_input.position = Vector2(16, CHAT_PANEL_HEIGHT - 66.0)
	chat_input.size = Vector2(1384, 42)
	chat_input.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_chat_input_style(chat_input, 18)
	if not chat_input.text_submitted.is_connected(_on_chat_input_submitted):
		chat_input.text_submitted.connect(_on_chat_input_submitted)
	wire_chat_input_activity(chat_input)
	if not chat_input.gui_input.is_connected(_on_chat_wheel_gui_input):
		chat_input.gui_input.connect(_on_chat_wheel_gui_input)
	chat_panel.add_child(chat_input)
	chat_send_button = Button.new()
	chat_send_button.name = "SendButton"
	chat_send_button.text = "SEND"
	chat_send_button.position = Vector2(1416, CHAT_PANEL_HEIGHT - 66.0)
	chat_send_button.size = Vector2(128, 42)
	chat_send_button.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_chat_arcade_button_style(chat_send_button, true, false, 17)
	chat_send_button.pressed.connect(send_chat_message)
	if not chat_send_button.gui_input.is_connected(_on_chat_wheel_gui_input):
		chat_send_button.gui_input.connect(_on_chat_wheel_gui_input)
	chat_panel.add_child(chat_send_button)
	chat_handle = get_node_or_null("ChatPullHandle")
	if chat_handle != null and not (chat_handle is Panel):
		chat_handle.name = "OldChatPullHandle"
		chat_handle.queue_free()
		chat_handle = null
	if chat_handle == null:
		chat_handle = Panel.new()
		chat_handle.name = "ChatPullHandle"
		add_child(chat_handle)
	chat_handle.size = Vector2(340, CHAT_HANDLE_HEIGHT)
	chat_handle.mouse_filter = Control.MOUSE_FILTER_STOP
	chat_handle.z_index = 121
	chat_handle.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.060, 0.145, 0.225, 0.82),
		Color(0.42, 0.78, 1.0, 0.72),
		3, 12, 4
	))
	if not chat_handle.gui_input.is_connected(_on_chat_handle_gui_input):
		chat_handle.gui_input.connect(_on_chat_handle_gui_input)
	for child in chat_handle.get_children():
		child.queue_free()
	handle_label = Label.new()
	handle_label.name = "HandleLabel"
	handle_label.text = "CHAT"
	handle_label.position = Vector2.ZERO
	handle_label.size = chat_handle.size
	handle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	handle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	handle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(handle_label, 12, Color(0.90, 0.98, 1.0, 1.0))
	chat_handle.add_child(handle_label)
	chat_button = get_node_or_null("ChatButton")
	if chat_button == null:
		chat_button = Button.new()
		chat_button.name = "ChatButton"
		add_child(chat_button)
	chat_button.text = ""
	chat_button.size = CHAT_BUTTON_SIZE
	chat_button.z_index = 122
	chat_button.visible = true
	chat_button.mouse_filter = Control.MOUSE_FILTER_STOP
	chat_button.focus_mode = Control.FOCUS_NONE
	apply_chat_icon_button_style(chat_button)
	setup_chat_button_icon()
	if chat_button.pressed.is_connected(toggle_chat_panel):
		chat_button.pressed.disconnect(toggle_chat_panel)
	if not chat_button.pressed.is_connected(_on_chat_button_pressed):
		chat_button.pressed.connect(_on_chat_button_pressed)
	if not chat_button.mouse_entered.is_connected(_on_chat_button_mouse_entered):
		chat_button.mouse_entered.connect(_on_chat_button_mouse_entered)
	if not chat_button.mouse_exited.is_connected(_on_chat_button_mouse_exited):
		chat_button.mouse_exited.connect(_on_chat_button_mouse_exited)
	if not chat_button.button_down.is_connected(_on_chat_button_down):
		chat_button.button_down.connect(_on_chat_button_down)
	if not chat_button.button_up.is_connected(_on_chat_button_up):
		chat_button.button_up.connect(_on_chat_button_up)
	setup_quick_chat_bar()
	apply_chat_font_to_tree(self)
	setup_chat_bubble()
	add_chat_message("System", "Chat ready.")
	update_chat_position()
	refresh_chat_messages(true)


func bind_authored_chat_scene() -> bool:
	var authored_panel = get_node_or_null("ChatPanel")
	var authored_messages_root = get_node_or_null("ChatPanel/MessagesPanel/MessagesScroll/MessagesRoot")
	var authored_input = get_node_or_null("ChatPanel/ChatInput")
	var authored_send = get_node_or_null("ChatPanel/SendButton")

	if not (authored_panel is Control):
		return false
	if not (authored_messages_root is VBoxContainer):
		return false
	if not (authored_input is LineEdit):
		return false
	if not (authored_send is Button):
		return false

	using_authored_scene_layout = true
	chat_panel = authored_panel
	messages_panel = get_node_or_null("ChatPanel/MessagesPanel")
	chat_messages_scroll = get_node_or_null("ChatPanel/MessagesPanel/MessagesScroll")
	chat_messages_scroll_slider = get_node_or_null("ChatPanel/MessagesScrollSlider")
	chat_messages_root = authored_messages_root
	chat_input = authored_input
	chat_send_button = authored_send
	close_button = get_node_or_null("ChatPanel/CloseButton")
	chat_handle = get_node_or_null("ChatPanel/ChatHandle")
	channel_tabs = get_node_or_null("ChatPanel/ChannelTabs")
	chat_world_tab = get_node_or_null("ChatPanel/ChannelTabs/WorldTab")
	chat_local_tab = get_node_or_null("ChatPanel/ChannelTabs/LocalTab")
	chat_system_tab = get_node_or_null("ChatPanel/ChannelTabs/SystemTab")
	quick_chat_bar = get_node_or_null("QuickChatBar")
	quick_chat_input = get_node_or_null("QuickChatBar/QuickChatInput")
	quick_chat_send_button = get_node_or_null("QuickChatBar/QuickChatSendButton")
	chat_button = get_node_or_null("ChatButton")
	chat_button_icon = get_node_or_null("ChatButton/ChatButtonIcon")
	chat_button_icon_shadow = get_node_or_null("ChatButton/ChatButtonIconShadow")

	if not (chat_messages_scroll is ScrollContainer):
		chat_messages_scroll = null
	if not (chat_messages_scroll_slider is VScrollBar):
		chat_messages_scroll_slider = null
	if not (close_button is Button):
		close_button = null
	if not (chat_handle is Control):
		chat_handle = null
	if not (channel_tabs is Control):
		channel_tabs = null
	if not (chat_world_tab is Button):
		chat_world_tab = null
	if not (chat_local_tab is Button):
		chat_local_tab = null
	if not (chat_system_tab is Button):
		chat_system_tab = null
	if not (quick_chat_bar is Control):
		quick_chat_bar = null
	if not (quick_chat_input is LineEdit):
		quick_chat_input = null
	if not (quick_chat_send_button is Button):
		quick_chat_send_button = null
	if not (chat_button is Button):
		chat_button = null
	if not (chat_button_icon is TextureRect):
		chat_button_icon = null
	if not (chat_button_icon_shadow is TextureRect):
		chat_button_icon_shadow = null
	if chat_button_icon != null:
		chat_button_icon_base_position = chat_button_icon.position
	if chat_button_icon_shadow != null:
		chat_button_shadow_base_position = chat_button_icon_shadow.position

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat_panel.visible = true
	chat_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat_panel.z_index = max(chat_panel.z_index, 120)
	if not chat_panel.gui_input.is_connected(_on_chat_panel_gui_input):
		chat_panel.gui_input.connect(_on_chat_panel_gui_input)

	if chat_messages_scroll != null:
		chat_messages_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		chat_messages_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		chat_messages_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
		if not chat_messages_scroll.gui_input.is_connected(_on_chat_panel_gui_input):
			chat_messages_scroll.gui_input.connect(_on_chat_panel_gui_input)

	setup_messages_scroll_slider()
	setup_chat_channel_tabs()
	apply_authored_chat_text_defaults()

	chat_messages_root.alignment = BoxContainer.ALIGNMENT_END
	chat_messages_root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	chat_input.mouse_filter = Control.MOUSE_FILTER_STOP
	if not chat_input.text_submitted.is_connected(_on_chat_input_submitted):
		chat_input.text_submitted.connect(_on_chat_input_submitted)
	wire_chat_input_activity(chat_input)
	if not chat_input.gui_input.is_connected(_on_chat_wheel_gui_input):
		chat_input.gui_input.connect(_on_chat_wheel_gui_input)

	chat_send_button.mouse_filter = Control.MOUSE_FILTER_STOP
	if not chat_send_button.pressed.is_connected(send_chat_message):
		chat_send_button.pressed.connect(send_chat_message)
	if not chat_send_button.gui_input.is_connected(_on_chat_wheel_gui_input):
		chat_send_button.gui_input.connect(_on_chat_wheel_gui_input)

	if close_button != null:
		close_button.mouse_filter = Control.MOUSE_FILTER_STOP
		if not close_button.pressed.is_connected(close_chat_panel):
			close_button.pressed.connect(close_chat_panel)
		if not close_button.gui_input.is_connected(_on_chat_wheel_gui_input):
			close_button.gui_input.connect(_on_chat_wheel_gui_input)

	if chat_handle != null:
		chat_handle.mouse_filter = Control.MOUSE_FILTER_STOP
		chat_handle.z_index = max(chat_handle.z_index, 121)
		if not chat_handle.gui_input.is_connected(_on_chat_handle_gui_input):
			chat_handle.gui_input.connect(_on_chat_handle_gui_input)
		if chat_handle is Button:
			var handle_button := chat_handle as Button
			handle_button.focus_mode = Control.FOCUS_NONE
			handle_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
			handle_button.toggle_mode = false
			if handle_button.pressed.is_connected(toggle_chat_panel):
				handle_button.pressed.disconnect(toggle_chat_panel)

	if quick_chat_bar != null:
		quick_chat_bar.visible = false
		quick_chat_bar.mouse_filter = Control.MOUSE_FILTER_STOP
		quick_chat_bar.z_index = max(quick_chat_bar.z_index, 123)

	if quick_chat_input != null:
		quick_chat_input.mouse_filter = Control.MOUSE_FILTER_STOP
		if not quick_chat_input.text_submitted.is_connected(_on_quick_chat_input_submitted):
			quick_chat_input.text_submitted.connect(_on_quick_chat_input_submitted)
		wire_chat_input_activity(quick_chat_input)

	if quick_chat_send_button != null:
		quick_chat_send_button.mouse_filter = Control.MOUSE_FILTER_STOP
		if not quick_chat_send_button.pressed.is_connected(send_chat_message):
			quick_chat_send_button.pressed.connect(send_chat_message)

	if chat_button != null:
		chat_button.z_index = max(chat_button.z_index, 122)
		chat_button.mouse_filter = Control.MOUSE_FILTER_STOP
		chat_button.focus_mode = Control.FOCUS_NONE
		chat_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
		chat_button.custom_minimum_size = CHAT_BUTTON_SIZE
		chat_button.size = CHAT_BUTTON_SIZE
		if chat_button.pressed.is_connected(toggle_chat_panel):
			chat_button.pressed.disconnect(toggle_chat_panel)
		if not chat_button.pressed.is_connected(_on_chat_button_pressed):
			chat_button.pressed.connect(_on_chat_button_pressed)
		if not chat_button.mouse_entered.is_connected(_on_chat_button_mouse_entered):
			chat_button.mouse_entered.connect(_on_chat_button_mouse_entered)
		if not chat_button.mouse_exited.is_connected(_on_chat_button_mouse_exited):
			chat_button.mouse_exited.connect(_on_chat_button_mouse_exited)
		if not chat_button.button_down.is_connected(_on_chat_button_down):
			chat_button.button_down.connect(_on_chat_button_down)
		if not chat_button.button_up.is_connected(_on_chat_button_up):
			chat_button.button_up.connect(_on_chat_button_up)

	authored_panel_content_nodes.clear()
	for child in chat_panel.get_children():
		if child != chat_handle:
			authored_panel_content_nodes.append(child)
	apply_chat_font_to_tree(self)
	capture_authored_chat_scene_layout()

	return true


func capture_authored_chat_scene_layout() -> void:
	if chat_panel == null:
		return

	authored_chat_panel_size = chat_panel.size
	if chat_handle is Control:
		var handle_control: Control = chat_handle as Control
		authored_chat_handle_rect = Rect2(handle_control.position, handle_control.size)
		authored_chat_panel_size.x = maxf(authored_chat_panel_size.x, handle_control.position.x + handle_control.size.x)
		authored_chat_panel_size.y = maxf(authored_chat_panel_size.y, handle_control.position.y + handle_control.size.y)
		chat_panel.size = authored_chat_panel_size
	else:
		authored_chat_handle_rect = Rect2(Vector2.ZERO, Vector2(260, CHAT_HANDLE_HEIGHT))

	authored_chat_panel_visual_bounds = Rect2(Vector2.ZERO, authored_chat_panel_size)
	for child in chat_panel.get_children():
		if not (child is Control):
			continue
		var child_control: Control = child as Control
		var child_rect: Rect2 = Rect2(child_control.position, child_control.size)
		if child_rect.size.x <= 0.0 or child_rect.size.y <= 0.0:
			continue
		authored_chat_panel_visual_bounds = authored_chat_panel_visual_bounds.merge(child_rect)

	if quick_chat_bar is Control:
		var quick_control: Control = quick_chat_bar as Control
		authored_quick_chat_size = quick_control.size
	else:
		authored_quick_chat_size = Vector2.ZERO


func setup_chat_button_icon():
	if chat_button == null:
		return

	for child in chat_button.get_children():
		child.queue_free()

	chat_button_icon = null
	chat_button_icon_shadow = null

	if not ResourceLoader.exists(MESSAGE_ICON_PATH):
		chat_button.text = "CHAT"
		chat_button.size = Vector2(108, 42)
		apply_chat_arcade_button_style(chat_button, false, false, 15)
		return

	var icon_texture: Texture2D = load(MESSAGE_ICON_PATH) as Texture2D
	if icon_texture == null:
		chat_button.text = "CHAT"
		chat_button.size = Vector2(108, 42)
		apply_chat_arcade_button_style(chat_button, false, false, 15)
		return

	chat_button_icon_shadow = TextureRect.new()
	chat_button_icon_shadow.name = "MessageIconShadow"
	chat_button_icon_shadow.texture = icon_texture
	chat_button_icon_shadow.position = Vector2(5, 7)
	chat_button_icon_shadow.size = CHAT_BUTTON_SIZE
	chat_button_icon_shadow.pivot_offset = CHAT_BUTTON_SIZE * 0.5
	chat_button_icon_shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chat_button_icon_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat_button_icon_shadow.modulate = Color(0.0, 0.0, 0.0, 0.38)
	chat_button.add_child(chat_button_icon_shadow)
	chat_button_shadow_base_position = chat_button_icon_shadow.position

	chat_button_icon = TextureRect.new()
	chat_button_icon.name = "MessageIcon"
	chat_button_icon.texture = icon_texture
	chat_button_icon.position = Vector2.ZERO
	chat_button_icon.size = CHAT_BUTTON_SIZE
	chat_button_icon.pivot_offset = CHAT_BUTTON_SIZE * 0.5
	chat_button_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chat_button_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat_button_icon.modulate = Color(1.0, 1.0, 1.0, 0.96)
	chat_button.add_child(chat_button_icon)
	chat_button_icon_base_position = chat_button_icon.position


func apply_chat_icon_button_style(button: Button):
	if button == null:
		return

	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _on_chat_button_mouse_entered():
	chat_button_hovered = true
	animate_chat_button_icon(false)


func _on_chat_button_mouse_exited():
	chat_button_hovered = false
	animate_chat_button_icon(false)


func _on_chat_button_down():
	animate_chat_button_icon(true)


func _on_chat_button_up():
	animate_chat_button_icon(false)


func animate_chat_button_icon(pressed: bool):
	if chat_button_icon == null or chat_button_icon_shadow == null:
		return

	if chat_button_tween != null:
		chat_button_tween.kill()

	var icon_position: Vector2 = chat_button_icon_base_position
	var shadow_position: Vector2 = chat_button_shadow_base_position
	var icon_scale: Vector2 = Vector2.ONE
	var shadow_alpha: float = 0.38
	var icon_alpha: float = 0.96

	if chat_button_hovered:
		icon_position = chat_button_icon_base_position + Vector2(-2, -3)
		shadow_position = chat_button_shadow_base_position + Vector2(2, 3)
		icon_scale = Vector2(1.06, 1.06)
		shadow_alpha = 0.48
		icon_alpha = 1.0

	if pressed:
		icon_position = chat_button_icon_base_position + Vector2(1, 2)
		shadow_position = chat_button_shadow_base_position + Vector2(-2, -3)
		icon_scale = Vector2(0.96, 0.96)
		shadow_alpha = 0.28

	chat_button_tween = create_tween()
	chat_button_tween.set_parallel(true)
	chat_button_tween.tween_property(chat_button_icon, "position", icon_position, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	chat_button_tween.tween_property(chat_button_icon, "scale", icon_scale, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	chat_button_tween.tween_property(chat_button_icon, "modulate", Color(1.0, 1.0, 1.0, icon_alpha), 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	chat_button_tween.tween_property(chat_button_icon_shadow, "position", shadow_position, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	chat_button_tween.tween_property(chat_button_icon_shadow, "scale", icon_scale, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	chat_button_tween.tween_property(chat_button_icon_shadow, "modulate", Color(0.0, 0.0, 0.0, shadow_alpha), 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func setup_chat_bubble():
	# Bubble lives on the UI CanvasLayer so it renders at native resolution
	# and stays crisp at any camera zoom level — same approach as username label.
	var layer = ui_layer_ref
	if layer == null and world != null and "ui_layer" in world:
		layer = world.ui_layer
	if layer == null:
		return

	# Remove old bubble if it exists on the player node
	if player != null:
		var old = player.get_node_or_null("ChatBubble")
		if old != null:
			old.queue_free()

	# Remove old UI-layer bubble
	var old_ui = layer.get_node_or_null("ChatBubbleUI")
	if old_ui != null:
		old_ui.queue_free()

	chat_bubble_node = CHAT_BUBBLE_COMPONENT.new()
	chat_bubble_node.name = "ChatBubbleUI"
	layer.add_child(chat_bubble_node)
	active_bubble_kind = BUBBLE_KIND_NONE


func _ensure_local_chat_bubble_anchor():
	if player == null:
		return

	var anchor = player.get_node_or_null("ChatBubbleAnchor")
	if anchor == null:
		anchor = Marker2D.new()
		anchor.name = "ChatBubbleAnchor"
		player.add_child(anchor)

	if not (anchor is Node2D):
		return

	anchor.position = Vector2(
		anchor.position.x,
		-CHAT_BUBBLE_COMPONENT.get_anchor_offset_world_px()
	)


func setup_quick_chat_bar():
	quick_chat_bar = get_node_or_null("QuickChatBar")
	if quick_chat_bar != null and not (quick_chat_bar is Panel):
		quick_chat_bar.name = "OldQuickChatBar"
		quick_chat_bar.queue_free()
		quick_chat_bar = null
	if quick_chat_bar == null:
		quick_chat_bar = Panel.new()
		quick_chat_bar.name = "QuickChatBar"
		add_child(quick_chat_bar)

	quick_chat_bar.size = Vector2(720, 48)
	quick_chat_bar.z_index = 123
	quick_chat_bar.visible = false
	quick_chat_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	quick_chat_bar.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.060, 0.135, 0.200, 0.72),
		Color(0.40, 0.78, 1.0, 0.62),
		3, 13, 5
	))

	for child in quick_chat_bar.get_children():
		child.queue_free()

	quick_chat_input = LineEdit.new()
	quick_chat_input.name = "QuickChatInput"
	quick_chat_input.placeholder_text = "Type message or /command..."
	quick_chat_input.position = Vector2(10, 6)
	quick_chat_input.size = Vector2(582, 36)
	quick_chat_input.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_chat_input_style(quick_chat_input, 16)
	if not quick_chat_input.text_submitted.is_connected(_on_quick_chat_input_submitted):
		quick_chat_input.text_submitted.connect(_on_quick_chat_input_submitted)
	wire_chat_input_activity(quick_chat_input)
	quick_chat_bar.add_child(quick_chat_input)

	quick_chat_send_button = Button.new()
	quick_chat_send_button.name = "QuickSendButton"
	quick_chat_send_button.text = "SEND"
	quick_chat_send_button.position = Vector2(604, 6)
	quick_chat_send_button.size = Vector2(106, 36)
	quick_chat_send_button.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_chat_arcade_button_style(quick_chat_send_button, true, false, 14)
	if not quick_chat_send_button.pressed.is_connected(send_chat_message):
		quick_chat_send_button.pressed.connect(send_chat_message)
	quick_chat_bar.add_child(quick_chat_send_button)


func apply_chat_input_style(line_edit: LineEdit, font_size: int = 18):
	if line_edit == null:
		return

	PixelUIStyle.apply_input(line_edit, font_size)
	apply_chat_font_to_control(line_edit)
	line_edit.add_theme_stylebox_override("normal", PixelUIStyle.style_box(Color(0.82, 0.94, 1.0, 0.18), Color(0.30, 0.72, 1.0, 0.68), 3, 12, 4))
	line_edit.add_theme_stylebox_override("focus", PixelUIStyle.style_box(Color(0.86, 0.97, 1.0, 0.27), Color(0.86, 0.96, 1.0, 0.98), 3, 12, 7))
	line_edit.add_theme_color_override("font_color", Color(0.98, 1.0, 1.0, 1.0))
	line_edit.add_theme_color_override("font_placeholder_color", Color(0.76, 0.90, 1.0, 0.74))
	line_edit.add_theme_color_override("caret_color", Color(0.95, 0.76, 0.10, 1.0))
	line_edit.add_theme_color_override("selection_color", Color(0.20, 0.48, 0.82, 0.58))


func apply_chat_arcade_button_style(button: Button, selected: bool = false, danger: bool = false, font_size: int = 14):
	if button == null:
		return

	PixelUIStyle.apply_button_text(button, font_size)
	apply_chat_font_to_control(button)
	if danger:
		button.add_theme_stylebox_override("normal", PixelUIStyle.style_box(Color(0.62, 0.08, 0.15, 0.98), Color(0.18, 0.01, 0.05, 1.0), 3, 12, 6))
		button.add_theme_stylebox_override("hover", PixelUIStyle.style_box(Color(0.86, 0.12, 0.22, 0.98), Color(1.0, 0.38, 0.40, 0.72), 3, 12, 7))
		button.add_theme_stylebox_override("pressed", PixelUIStyle.style_box(Color(0.40, 0.03, 0.09, 0.98), Color(0.12, 0.0, 0.02, 1.0), 3, 12, 4))
		button.add_theme_stylebox_override("disabled", PixelUIStyle.style_box(Color(0.30, 0.04, 0.08, 0.72), Color(0.10, 0.0, 0.02, 0.92), 3, 12, 3))
		return
	if selected:
		button.add_theme_stylebox_override("normal", PixelUIStyle.style_box(Color(0.95, 0.68, 0.08, 0.98), Color(1.0, 0.90, 0.22, 0.95), 3, 8, 6))
		button.add_theme_stylebox_override("hover", PixelUIStyle.style_box(Color(1.0, 0.76, 0.12, 0.98), Color(1.0, 0.96, 0.38, 1.0), 3, 8, 7))
		button.add_theme_stylebox_override("pressed", PixelUIStyle.style_box(Color(0.72, 0.36, 0.04, 0.98), Color(0.42, 0.15, 0.01, 1.0), 3, 8, 4))
		button.add_theme_stylebox_override("disabled", PixelUIStyle.style_box(Color(0.48, 0.34, 0.05, 0.76), Color(0.74, 0.58, 0.12, 0.78), 3, 8, 3))
		return
	PixelUIStyle.apply_blue_button(button, font_size)


func apply_chat_scrollbar_style():
	if chat_messages_scroll == null:
		return
	if using_authored_scene_layout and chat_messages_scroll_slider != null:
		return

	var scrollbar = chat_messages_scroll.get_v_scroll_bar()
	if scrollbar == null:
		return

	scrollbar.custom_minimum_size = Vector2(15, scrollbar.custom_minimum_size.y)
	scrollbar.add_theme_stylebox_override("scroll", PixelUIStyle.style_box(Color(0.08, 0.18, 0.26, 0.32), Color(0.24, 0.52, 0.74, 0.42), 2, 8, 0))
	scrollbar.add_theme_stylebox_override("grabber", PixelUIStyle.style_box(Color(0.30, 0.68, 0.96, 0.86), Color(0.78, 0.96, 1.0, 0.68), 2, 8, 4))
	scrollbar.add_theme_stylebox_override("grabber_highlight", PixelUIStyle.style_box(Color(0.46, 0.82, 1.0, 0.98), Color(0.90, 1.0, 1.0, 0.86), 2, 8, 6))
	scrollbar.add_theme_stylebox_override("grabber_pressed", PixelUIStyle.style_box(Color(1.0, 0.66, 0.12, 0.98), Color(1.0, 0.92, 0.40, 0.90), 2, 8, 6))


func setup_messages_scroll_slider() -> void:
	if chat_messages_scroll == null:
		return

	if chat_messages_scroll_slider == null:
		apply_chat_scrollbar_style()
		return

	chat_messages_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	chat_messages_scroll_slider.mouse_filter = Control.MOUSE_FILTER_STOP

	var internal_scrollbar: VScrollBar = chat_messages_scroll.get_v_scroll_bar()
	if internal_scrollbar != null:
		var internal_value_callback: Callable = Callable(self, "_on_messages_scroll_changed")
		if not internal_scrollbar.value_changed.is_connected(internal_value_callback):
			internal_scrollbar.value_changed.connect(internal_value_callback)

		var internal_range_callback: Callable = Callable(self, "_queue_messages_scroll_slider_sync")
		if not internal_scrollbar.changed.is_connected(internal_range_callback):
			internal_scrollbar.changed.connect(internal_range_callback)

	var slider_callback: Callable = Callable(self, "_on_messages_scroll_slider_value_changed")
	if not chat_messages_scroll_slider.value_changed.is_connected(slider_callback):
		chat_messages_scroll_slider.value_changed.connect(slider_callback)

	var resize_callback: Callable = Callable(self, "_queue_messages_scroll_slider_sync")
	if not chat_messages_scroll.resized.is_connected(resize_callback):
		chat_messages_scroll.resized.connect(resize_callback)
	if chat_messages_root != null and not chat_messages_root.resized.is_connected(resize_callback):
		chat_messages_root.resized.connect(resize_callback)

	call_deferred("_sync_messages_scroll_slider")


func _queue_messages_scroll_slider_sync() -> void:
	call_deferred("_sync_messages_scroll_slider")


func _sync_messages_scroll_slider() -> void:
	if chat_messages_scroll == null or chat_messages_scroll_slider == null:
		return

	var internal_scrollbar: VScrollBar = chat_messages_scroll.get_v_scroll_bar()
	if internal_scrollbar == null:
		return

	chat_scroll_slider_syncing = true
	var internal_max_scroll: float = maxf(0.0, float(internal_scrollbar.max_value) - float(internal_scrollbar.page))
	var has_scroll_range: bool = internal_max_scroll > 0.5
	var slider_max_scroll: float = CHAT_SCROLL_SLIDER_MAX - CHAT_SCROLL_SLIDER_PAGE
	var normalized_scroll: float = 0.0
	if has_scroll_range:
		normalized_scroll = clampf(float(chat_messages_scroll.scroll_vertical) / internal_max_scroll, 0.0, 1.0)
	chat_messages_scroll_slider.visible = true
	chat_messages_scroll_slider.mouse_filter = Control.MOUSE_FILTER_STOP if has_scroll_range else Control.MOUSE_FILTER_IGNORE
	chat_messages_scroll_slider.min_value = 0.0
	chat_messages_scroll_slider.max_value = CHAT_SCROLL_SLIDER_MAX
	chat_messages_scroll_slider.page = CHAT_SCROLL_SLIDER_PAGE
	chat_messages_scroll_slider.step = 1.0
	chat_messages_scroll_slider.value = normalized_scroll * slider_max_scroll
	if not has_scroll_range:
		chat_messages_scroll.scroll_vertical = 0
	chat_scroll_slider_syncing = false


func _on_messages_scroll_slider_value_changed(value: float) -> void:
	if chat_scroll_slider_syncing or chat_messages_scroll == null:
		return

	var max_scroll: int = get_messages_scroll_max()
	if max_scroll <= 0:
		chat_scroll_programmatic = true
		chat_messages_scroll.scroll_vertical = 0
		chat_scroll_programmatic = false
		chat_scroll_stick_to_bottom = true
		return
	var slider_max_scroll: float = maxf(1.0, float(chat_messages_scroll_slider.max_value) - float(chat_messages_scroll_slider.page))
	var normalized_scroll: float = clampf((value - float(chat_messages_scroll_slider.min_value)) / slider_max_scroll, 0.0, 1.0)
	chat_scroll_programmatic = true
	chat_messages_scroll.scroll_vertical = int(round(normalized_scroll * float(max_scroll)))
	chat_scroll_programmatic = false
	chat_scroll_stick_to_bottom = is_messages_scroll_at_bottom()


func _on_messages_scroll_changed(_value: float) -> void:
	if not chat_scroll_programmatic:
		chat_scroll_stick_to_bottom = is_messages_scroll_at_bottom()
	if chat_scroll_slider_syncing or chat_messages_scroll_slider == null:
		return
	_sync_messages_scroll_slider()


func get_messages_scroll_max() -> int:
	if chat_messages_scroll == null:
		return 0

	var internal_scrollbar: VScrollBar = chat_messages_scroll.get_v_scroll_bar()
	if internal_scrollbar == null:
		return max(0, int(chat_messages_scroll.scroll_vertical))

	return max(0, int(round(float(internal_scrollbar.max_value) - float(internal_scrollbar.page))))


func is_messages_scroll_at_bottom(threshold: int = CHAT_SCROLL_BOTTOM_THRESHOLD) -> bool:
	if chat_messages_scroll == null:
		return true
	return get_messages_scroll_max() - int(chat_messages_scroll.scroll_vertical) <= max(0, threshold)


func set_messages_scroll_vertical(value: int, user_initiated: bool = false) -> void:
	if chat_messages_scroll == null:
		return

	chat_scroll_programmatic = true
	chat_messages_scroll.scroll_vertical = clamp(value, 0, get_messages_scroll_max())
	chat_scroll_programmatic = false
	if user_initiated:
		chat_scroll_stick_to_bottom = is_messages_scroll_at_bottom()
	_sync_messages_scroll_slider()


func scroll_messages_to_bottom_deferred() -> void:
	if chat_messages_scroll == null:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	set_messages_scroll_vertical(get_messages_scroll_max())
	chat_scroll_stick_to_bottom = true


func setup_chat_channel_tabs() -> void:
	if chat_world_tab == null and chat_local_tab == null and chat_system_tab == null:
		return

	if chat_tab_selected_style == null and chat_world_tab != null:
		chat_tab_selected_style = chat_world_tab.get_theme_stylebox("normal")
	if chat_tab_normal_style == null:
		if chat_local_tab != null:
			chat_tab_normal_style = chat_local_tab.get_theme_stylebox("normal")
		elif chat_system_tab != null:
			chat_tab_normal_style = chat_system_tab.get_theme_stylebox("normal")

	connect_chat_channel_tab(chat_world_tab, CHAT_FILTER_WORLD)
	connect_chat_channel_tab(chat_local_tab, CHAT_FILTER_LOCAL)
	connect_chat_channel_tab(chat_system_tab, CHAT_FILTER_SYSTEM)
	apply_chat_channel_tab_visuals()


func apply_authored_chat_text_defaults() -> void:
	var default_size := CHAT_MESSAGE_FONT_SIZE
	var text_controls: Array = [
		chat_input,
		chat_send_button,
		quick_chat_input,
		quick_chat_send_button,
		chat_world_tab,
		chat_local_tab,
		chat_system_tab
	]
	for control in text_controls:
		if control is Control:
			var text_control := control as Control
			apply_chat_font_to_control(text_control)
			text_control.add_theme_font_size_override("font_size", default_size)


func connect_chat_channel_tab(tab_button, filter_mode: String) -> void:
	if tab_button == null or not (tab_button is Button):
		return

	var button := tab_button as Button
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_NONE
	button.toggle_mode = true

	var callback: Callable = Callable(self, "_on_chat_channel_tab_pressed").bind(filter_mode)
	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)


func _on_chat_channel_tab_pressed(filter_mode: String) -> void:
	set_chat_filter_mode(filter_mode)


func set_chat_filter_mode(filter_mode: String) -> void:
	if filter_mode != CHAT_FILTER_LOCAL and filter_mode != CHAT_FILTER_SYSTEM:
		filter_mode = CHAT_FILTER_WORLD

	if chat_filter_mode == filter_mode:
		apply_chat_channel_tab_visuals()
		return

	chat_filter_mode = filter_mode
	apply_chat_channel_tab_visuals()
	refresh_chat_messages(true)


func apply_chat_channel_tab_visuals() -> void:
	apply_chat_channel_tab_visual(chat_world_tab, chat_filter_mode == CHAT_FILTER_WORLD)
	apply_chat_channel_tab_visual(chat_local_tab, chat_filter_mode == CHAT_FILTER_LOCAL)
	apply_chat_channel_tab_visual(chat_system_tab, chat_filter_mode == CHAT_FILTER_SYSTEM)


func apply_chat_channel_tab_visual(tab_button, selected: bool) -> void:
	if tab_button == null or not (tab_button is Button):
		return

	var button := tab_button as Button
	apply_chat_font_to_control(button)
	button.button_pressed = selected
	if selected:
		button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
		button.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1.0))
		if chat_tab_selected_style != null:
			button.add_theme_stylebox_override("normal", chat_tab_selected_style)
			button.add_theme_stylebox_override("hover", chat_tab_selected_style)
			button.add_theme_stylebox_override("pressed", chat_tab_selected_style)
		return

	button.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0, 0.95))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1.0))
	if chat_tab_normal_style != null:
		button.add_theme_stylebox_override("normal", chat_tab_normal_style)
	if chat_tab_selected_style != null:
		button.add_theme_stylebox_override("hover", chat_tab_selected_style)
		button.add_theme_stylebox_override("pressed", chat_tab_selected_style)


func layout_quick_chat_bar(screen_size: Vector2):
	if quick_chat_bar == null:
		return

	var bar_width = clamp(screen_size.x - 440.0, 520.0, 760.0)
	quick_chat_bar.size = Vector2(bar_width, 48)

	if quick_chat_input != null:
		quick_chat_input.position = Vector2(10, 6)
		quick_chat_input.size = Vector2(bar_width - 138.0, 36)

	if quick_chat_send_button != null:
		quick_chat_send_button.position = Vector2(bar_width - 116.0, 6)
		quick_chat_send_button.size = Vector2(106, 36)

	var base_x = (screen_size.x - bar_width) * 0.5
	var base_y = 58.0
	if chat_handle != null:
		base_y = chat_handle.position.y + chat_handle.size.y + 8.0

	quick_chat_bar.position = Vector2(max(18.0, base_x), base_y)
	quick_chat_bar.visible = quick_chat_active and not is_chat_open()


func layout_chat_controls(screen_size: Vector2):
	if chat_panel == null:
		return
	if using_authored_scene_layout:
		layout_authored_top_drawer_controls(screen_size)
		return
	var right_button_space = 245.0
	var available_width = max(CHAT_MIN_WIDTH, screen_size.x - right_button_space - CHAT_SIDE_MARGIN)
	var target_width = clamp(available_width, CHAT_MIN_WIDTH, CHAT_MAX_WIDTH)
	chat_panel.size = Vector2(target_width, CHAT_PANEL_HEIGHT)
	var top_bar = chat_panel.get_node_or_null("TopBar")
	if top_bar != null:
		top_bar.size = Vector2(target_width, CHAT_HEADER_HEIGHT)
	var header_gloss = chat_panel.get_node_or_null("HeaderGloss")
	if header_gloss != null:
		header_gloss.size = Vector2(max(1.0, target_width - 90.0), 16)
	var header_line = chat_panel.get_node_or_null("HeaderLine")
	if header_line != null:
		header_line.position = Vector2(0, CHAT_HEADER_HEIGHT - 5.0)
		header_line.size = Vector2(target_width, 4)
	if hint_label != null:
		hint_label.size = Vector2(max(220.0, target_width - 360.0), 24)
	if close_button != null:
		close_button.position = Vector2(target_width - 54.0, 11)
	var input_y = CHAT_PANEL_HEIGHT - 58.0
	var messages_y = CHAT_HEADER_HEIGHT + 14.0
	var messages_height = input_y - messages_y - 18.0
	if messages_panel != null:
		messages_panel.position = Vector2(16, messages_y)
		messages_panel.size = Vector2(target_width - 32.0, messages_height)
	if chat_messages_scroll != null:
		chat_messages_scroll.position = Vector2(26, messages_y + 10.0)
		chat_messages_scroll.size = Vector2(target_width - 52.0, messages_height - 20.0)
	if chat_messages_root != null:
		chat_messages_root.size = Vector2(target_width - 76.0, max(320.0, messages_height - 20.0))
		chat_messages_root.custom_minimum_size = Vector2(target_width - 76.0, max(320.0, messages_height - 20.0))
	if chat_input != null:
		chat_input.position = Vector2(16, input_y)
		chat_input.size = Vector2(target_width - 176.0, 40)
	if chat_send_button != null:
		chat_send_button.position = Vector2(target_width - 144.0, input_y)
		chat_send_button.size = Vector2(128, 40)
	if chat_handle != null:
		chat_handle.size = Vector2(340, CHAT_HANDLE_HEIGHT)
		if handle_label != null:
			handle_label.size = chat_handle.size


func layout_authored_top_drawer_controls(screen_size: Vector2) -> void:
	var visual_width: float = max(1.0, authored_chat_panel_visual_bounds.size.x)
	var panel_x: float = round((screen_size.x - visual_width) * 0.5 - authored_chat_panel_visual_bounds.position.x)
	var closed_y: float = get_authored_chat_closed_y()
	var open_y: float = get_authored_chat_open_y()
	chat_panel.size = authored_chat_panel_size
	chat_panel.position = Vector2(panel_x, lerp(closed_y, open_y, chat_panel_amount))

	layout_authored_quick_chat_bar(screen_size)
	layout_chat_button(screen_size)


func layout_authored_quick_chat_bar(screen_size: Vector2) -> void:
	if quick_chat_bar == null:
		return

	var bar_width: float = max(1.0, authored_quick_chat_size.x)
	var base_x: float = (screen_size.x - bar_width) * 0.5
	var base_y: float = 58.0
	if chat_handle != null:
		base_y = chat_panel.position.y + chat_handle.position.y + chat_handle.size.y + 8.0

	quick_chat_bar.size = authored_quick_chat_size
	quick_chat_bar.position = Vector2(max(18.0, base_x), base_y)


func get_authored_chat_open_y() -> float:
	return 8.0 - authored_chat_panel_visual_bounds.position.y


func get_authored_chat_closed_y() -> float:
	return 8.0 - authored_chat_handle_rect.position.y


func get_authored_chat_drag_height() -> float:
	return max(1.0, get_authored_chat_open_y() - get_authored_chat_closed_y())


func update_authored_chat_visibility(blocked_by_modal: bool) -> void:
	var panel_opening_or_open: bool = chat_panel_amount > 0.01 or chat_panel_target > 0.01
	if chat_input != null and chat_input.has_focus():
		panel_opening_or_open = true

	chat_panel.visible = not blocked_by_modal
	chat_panel.mouse_filter = Control.MOUSE_FILTER_STOP if panel_opening_or_open or chat_drag_active else Control.MOUSE_FILTER_IGNORE

	for content_node in authored_panel_content_nodes:
		if content_node is CanvasItem:
			content_node.visible = panel_opening_or_open and not blocked_by_modal

	if chat_handle != null:
		chat_handle.visible = not blocked_by_modal
	if chat_button != null:
		chat_button.visible = not blocked_by_modal
	if quick_chat_bar != null:
		quick_chat_bar.visible = quick_chat_active and not panel_opening_or_open and not blocked_by_modal

	if blocked_by_modal:
		if chat_input != null:
			chat_input.release_focus()
		if quick_chat_input != null:
			quick_chat_input.release_focus()
		quick_chat_active = false


func update_chat_position():
	if chat_panel == null:
		return
	var blocked_by_modal: bool = is_chat_blocked_by_modal_ui()
	chat_panel.visible = not blocked_by_modal
	if chat_handle != null:
		chat_handle.visible = not blocked_by_modal
	if chat_button != null:
		chat_button.visible = not blocked_by_modal
	if quick_chat_bar != null:
		quick_chat_bar.visible = quick_chat_active and not blocked_by_modal
	if blocked_by_modal:
		if using_authored_scene_layout:
			update_authored_chat_visibility(blocked_by_modal)
		return
	var screen_size = get_viewport_rect().size
	layout_chat_controls(screen_size)
	if using_authored_scene_layout:
		update_authored_chat_visibility(blocked_by_modal)
		return
	var panel_x = CHAT_SIDE_MARGIN
	var closed_y = -CHAT_PANEL_HEIGHT + CHAT_HANDLE_HEIGHT
	var open_y = 0.0
	chat_panel.position = Vector2(
		panel_x,
		lerp(closed_y, open_y, chat_panel_amount)
	)
	if chat_handle != null:
		chat_handle.position = Vector2(
			chat_panel.position.x + (chat_panel.size.x - chat_handle.size.x) / 2.0,
			chat_panel.position.y + CHAT_PANEL_HEIGHT - 1
		)
	layout_quick_chat_bar(screen_size)
	if chat_button != null:
		layout_chat_button(screen_size)


func layout_chat_button(screen_size: Vector2) -> void:
	if chat_button == null:
		return

	chat_button.size = CHAT_BUTTON_SIZE
	chat_button.custom_minimum_size = CHAT_BUTTON_SIZE
	var button_y: float = CHAT_BUTTON_Y
	if screen_size.y < CHAT_BUTTON_Y + chat_button.size.y + 14.0:
		button_y = max(60.0, screen_size.y - chat_button.size.y - 62.0)
	var button_x: float = screen_size.x - 102.0
	chat_button.position = Vector2(max(8.0, button_x), button_y)


func _on_chat_panel_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		if _scroll_chat_messages_for_wheel(event):
			get_viewport().set_input_as_handled()
			return
		get_viewport().set_input_as_handled()
	if event is InputEventScreenTouch and event.pressed:
		get_viewport().set_input_as_handled()


func _on_chat_wheel_gui_input(event: InputEvent) -> void:
	if _scroll_chat_messages_for_wheel(event):
		get_viewport().set_input_as_handled()


func _scroll_chat_messages_for_wheel(event: InputEvent) -> bool:
	if chat_messages_scroll == null:
		return false
	if not (event is InputEventMouseButton):
		return false

	var mouse_event: InputEventMouseButton = event
	if not mouse_event.pressed:
		return false
	if mouse_event.button_index != MOUSE_BUTTON_WHEEL_UP and mouse_event.button_index != MOUSE_BUTTON_WHEEL_DOWN:
		return false

	var scroll_step: int = int(max(36.0, chat_messages_scroll.size.y * 0.22))
	var direction: int = -1 if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP else 1
	set_messages_scroll_vertical(chat_messages_scroll.scroll_vertical + direction * scroll_step, true)
	return true


func handle_global_chat_handle_touch_input(event: InputEvent) -> bool:
	if is_chat_blocked_by_modal_ui() or chat_handle == null:
		return false

	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if touch_event.pressed:
			if not chat_handle_touch_contains_point(touch_event.position):
				return false
			chat_handle_drag_index = touch_event.index
			chat_drag_active = true
			chat_drag_start_y = touch_event.position.y
			chat_drag_start_amount = chat_panel_amount
			chat_handle_dragged = false
			return true

		if chat_drag_active and touch_event.index == chat_handle_drag_index:
			var should_toggle_panel: bool = not chat_handle_dragged
			finish_chat_drag()
			if should_toggle_panel:
				toggle_chat_panel()
			return true
		return false

	if event is InputEventScreenDrag and chat_drag_active:
		var drag_event: InputEventScreenDrag = event as InputEventScreenDrag
		if chat_handle_drag_index != -1 and drag_event.index != chat_handle_drag_index:
			return false
		var drag_distance: float = absf(drag_event.position.y - chat_drag_start_y)
		if drag_distance > CHAT_HANDLE_DRAG_TAP_THRESHOLD:
			chat_handle_dragged = true
			update_chat_drag(drag_event.position.y)
		return true

	return false


func _on_chat_handle_gui_input(event: InputEvent):
	if _scroll_chat_messages_for_wheel(event):
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			chat_handle_drag_index = -1
			chat_drag_active = true
			chat_drag_start_y = get_viewport().get_mouse_position().y
			chat_drag_start_amount = chat_panel_amount
			chat_handle_dragged = false
		else:
			var should_toggle_panel: bool = not chat_handle_dragged
			finish_chat_drag()
			if should_toggle_panel:
				toggle_chat_panel()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and chat_drag_active:
		var mouse_drag_distance: float = absf(get_viewport().get_mouse_position().y - chat_drag_start_y)
		if mouse_drag_distance > CHAT_HANDLE_DRAG_TAP_THRESHOLD:
			chat_handle_dragged = true
			update_chat_drag(get_viewport().get_mouse_position().y)
		get_viewport().set_input_as_handled()

	if event is InputEventScreenTouch:
		if event.pressed:
			chat_handle_drag_index = event.index
			chat_drag_active = true
			chat_drag_start_y = event.position.y
			chat_drag_start_amount = chat_panel_amount
			chat_handle_dragged = false
		else:
			if event.index == chat_handle_drag_index:
				var should_toggle_panel: bool = not chat_handle_dragged
				finish_chat_drag()
				if should_toggle_panel:
					toggle_chat_panel()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and chat_drag_active:
		if chat_handle_drag_index == -1 or event.index == chat_handle_drag_index:
			var drag_distance: float = absf(event.position.y - chat_drag_start_y)
			if drag_distance > CHAT_HANDLE_DRAG_TAP_THRESHOLD:
				chat_handle_dragged = true
				update_chat_drag(event.position.y)
		get_viewport().set_input_as_handled()


func update_chat_drag(current_y: float):
	var drag_down_distance = current_y - chat_drag_start_y
	var drag_height: float = CHAT_PANEL_HEIGHT
	if using_authored_scene_layout:
		drag_height = get_authored_chat_drag_height()
	chat_panel_amount = clamp(
		chat_drag_start_amount + drag_down_distance / drag_height,
		0.0, 1.0
	)
	chat_panel_target = chat_panel_amount
	update_chat_position()


func finish_chat_drag():
	if not chat_drag_active:
		return
	chat_drag_active = false
	# No snap — stay wherever the player left it.
	chat_panel_target = chat_panel_amount
	if chat_panel_amount > 0.05:
		chat_scroll_stick_to_bottom = true
		scroll_messages_to_bottom_deferred()


func open_chat_panel():
	if is_chat_blocked_by_modal_ui():
		return
	quick_chat_active = false
	if quick_chat_input != null:
		quick_chat_input.release_focus()
	hide_active_bubble()
	chat_panel_target = 1.0
	chat_scroll_stick_to_bottom = true
	scroll_messages_to_bottom_deferred()


func close_chat_panel():
	chat_panel_target = 0.0
	if chat_input != null:
		chat_input.release_focus()
	if quick_chat_input != null:
		quick_chat_input.release_focus()
	quick_chat_active = false


func toggle_chat_panel():
	if chat_panel_target > 0.5 or chat_panel_amount > 0.5:
		close_chat_panel()
	else:
		open_chat_panel()


func _on_chat_button_pressed():
	if is_chat_input_focused():
		send_chat_message()
		return

	if can_focus_chat_from_keyboard():
		focus_chat_input()


func is_chat_open() -> bool:
	return chat_panel_amount > 0.05 or chat_panel_target > 0.05


func is_chat_ui_at_point(point: Vector2) -> bool:
	if is_chat_blocked_by_modal_ui():
		return false

	if using_authored_scene_layout:
		var panel_opening_or_open: bool = chat_panel_amount > 0.01 or chat_panel_target > 0.01
		if panel_opening_or_open and authored_chat_panel_contains_screen_point(point):
			return true
		if chat_handle_touch_contains_point(point):
			return true
		if quick_chat_active and control_contains_screen_point(quick_chat_bar, point):
			return true
		return control_contains_screen_point(chat_button, point)

	if control_contains_screen_point(chat_panel, point):
		return true
	if chat_handle_touch_contains_point(point):
		return true
	if quick_chat_active and control_contains_screen_point(quick_chat_bar, point):
		return true
	return control_contains_screen_point(chat_button, point)


func authored_chat_panel_contains_screen_point(point: Vector2) -> bool:
	if chat_panel == null or not is_instance_valid(chat_panel):
		return false
	if chat_panel is CanvasItem and not chat_panel.is_visible_in_tree():
		return false

	var visual_rect: Rect2 = Rect2(
		chat_panel.global_position + authored_chat_panel_visual_bounds.position,
		authored_chat_panel_visual_bounds.size
	)
	return visual_rect.has_point(point)


func control_contains_screen_point(control, point: Vector2) -> bool:
	if control == null or not is_instance_valid(control):
		return false
	if control is CanvasItem and not control.is_visible_in_tree():
		return false
	if not (control is Control):
		return false

	var control_node := control as Control
	return control_node.get_global_rect().has_point(point)


func chat_handle_touch_contains_point(point: Vector2) -> bool:
	if chat_handle == null or not is_instance_valid(chat_handle):
		return false
	if chat_handle is CanvasItem and not chat_handle.is_visible_in_tree():
		return false
	if not (chat_handle is Control):
		return false

	var handle_control: Control = chat_handle as Control
	var touch_rect: Rect2 = handle_control.get_global_rect().grow_individual(
		CHAT_HANDLE_TOUCH_PADDING.x,
		CHAT_HANDLE_TOUCH_PADDING.y,
		CHAT_HANDLE_TOUCH_PADDING.x,
		CHAT_HANDLE_TOUCH_PADDING.y
	)
	return touch_rect.has_point(point)


func is_chat_blocked_by_modal_ui() -> bool:
	if world != null and world.has_method("is_movement_blocking_ui_open"):
		return bool(world.is_movement_blocking_ui_open())

	return false


func focus_chat_input():
	hide_notification_bubble()
	if chat_panel_target > 0.5 or chat_panel_amount > 0.65:
		if chat_input != null:
			quick_chat_active = false
			chat_input.grab_focus()
		return

	if quick_chat_input == null:
		setup_quick_chat_bar()
	if quick_chat_input == null:
		return

	chat_panel_target = 0.0
	quick_chat_active = true
	update_chat_position()
	quick_chat_input.grab_focus()


func release_chat_focus():
	if chat_input != null:
		chat_input.release_focus()
	if quick_chat_input != null:
		quick_chat_input.release_focus()
	quick_chat_active = false


func is_chat_input_focused() -> bool:
	var main_focused: bool = false
	if chat_input != null:
		main_focused = chat_input.has_focus()

	var quick_focused: bool = false
	if quick_chat_input != null:
		quick_focused = quick_chat_input.has_focus()

	return main_focused or quick_focused


func wire_chat_input_activity(line_edit: LineEdit) -> void:
	if line_edit == null:
		return
	if not line_edit.focus_entered.is_connected(_on_chat_text_activity):
		line_edit.focus_entered.connect(_on_chat_text_activity)
	if not line_edit.text_changed.is_connected(_on_chat_text_changed):
		line_edit.text_changed.connect(_on_chat_text_changed)


func _on_chat_text_activity() -> void:
	hide_notification_bubble()


func _on_chat_text_changed(_new_text: String) -> void:
	hide_notification_bubble()


func clear_notification_bubble_if_chat_active() -> void:
	if is_chat_input_focused() or quick_chat_active:
		hide_notification_bubble()


func hide_active_bubble() -> void:
	if chat_bubble_node != null and chat_bubble_node.has_method("hide_chat_bubble"):
		chat_bubble_node.hide_chat_bubble()
	active_bubble_kind = BUBBLE_KIND_NONE


func hide_notification_bubble() -> void:
	if active_bubble_kind != BUBBLE_KIND_NOTIFICATION:
		return
	hide_active_bubble()


func is_chat_bubble_visible() -> bool:
	return chat_bubble_node != null and is_instance_valid(chat_bubble_node) and bool(chat_bubble_node.visible)


func can_show_notification_bubble() -> bool:
	if is_chat_input_focused() or quick_chat_active:
		return false
	if active_bubble_kind == BUBBLE_KIND_CHAT and is_chat_bubble_visible():
		return false
	return true


func _on_chat_input_submitted(_text: String):
	send_chat_message()


func _on_quick_chat_input_submitted(_text: String):
	send_chat_message()


func send_chat_message():
	var source_input: LineEdit = get_active_chat_input()
	if source_input == null:
		return

	var source_was_quick: bool = source_input == quick_chat_input
	var message: String = source_input.text.strip_edges()

	if message == "":
		release_chat_focus()
		return

	source_input.text = ""

	if message.begins_with("/"):
		if world != null and world.has_method("handle_chat_command"):
			world.handle_chat_command(message)
		elif world != null and world.command_manager != null and world.command_manager.has_method("handle_command"):
			world.command_manager.handle_command(message)
		else:
			add_chat_message("System", "Commands are not ready.")
	else:
		var network = get_node_or_null("/root/NetworkManager")
		if network != null and network.has_method("send_chat_message"):
			if network.send_chat_message(message):
				show_chat_bubble(message)
			else:
				add_chat_message("Me", message)
				show_chat_bubble(message)
		else:
			add_chat_message("Me", message)
			show_chat_bubble(message)

	# Keep chat where the player dragged it, but release focus so movement works.
	release_chat_focus()
	if source_was_quick:
		chat_panel_target = 0.0


func get_active_chat_input() -> LineEdit:
	if quick_chat_input != null and quick_chat_input.has_focus():
		return quick_chat_input as LineEdit
	if chat_input != null and chat_input.has_focus():
		return chat_input as LineEdit
	if quick_chat_active and quick_chat_input != null:
		return quick_chat_input as LineEdit
	return chat_input as LineEdit


func add_chat_message(sender: String, message: String, metadata: Dictionary = {}):
	chat_messages.append({
		"sender": sender,
		"message": message,
		"metadata": metadata.duplicate(true)
	})
	while chat_messages.size() > MAX_CHAT_MESSAGES:
		chat_messages.pop_front()
	refresh_chat_messages()


func get_chat_message_metadata(data: Dictionary) -> Dictionary:
	var metadata_value: Variant = data.get("metadata", {})
	return metadata_value if metadata_value is Dictionary else {}


func get_chat_message_type(metadata: Dictionary) -> String:
	var message_type: String = str(metadata.get("type", "")).strip_edges().to_lower()
	if message_type == "":
		message_type = str(metadata.get("channel", "")).strip_edges().to_lower()
	return message_type


func is_system_chat_message(sender: String, metadata: Dictionary) -> bool:
	var clean_sender: String = sender.strip_edges().to_lower()
	if clean_sender == "system" or clean_sender == "server":
		return true

	var player_id: String = str(metadata.get("player_id", "")).strip_edges().to_lower()
	if player_id == "system" or player_id == "server":
		return true

	var message_type: String = get_chat_message_type(metadata)
	return message_type == "system" or message_type == "server" or message_type.find("system") != -1


func is_broadcast_chat_message(metadata: Dictionary) -> bool:
	return get_chat_message_type(metadata) == "broadcast"


func is_local_chat_message(sender: String, metadata: Dictionary) -> bool:
	return not is_system_chat_message(sender, metadata) and not is_broadcast_chat_message(metadata)


func should_show_chat_message(data: Dictionary) -> bool:
	if chat_filter_mode == CHAT_FILTER_WORLD:
		return true

	var sender: String = str(data.get("sender", ""))
	var metadata: Dictionary = get_chat_message_metadata(data)
	if chat_filter_mode == CHAT_FILTER_SYSTEM:
		return is_system_chat_message(sender, metadata)
	if chat_filter_mode == CHAT_FILTER_LOCAL:
		return is_local_chat_message(sender, metadata)

	return true


func get_filtered_chat_messages() -> Array:
	var filtered_messages: Array = []
	for message_data in chat_messages:
		if not (message_data is Dictionary):
			continue
		var data: Dictionary = message_data
		if should_show_chat_message(data):
			filtered_messages.append(data)
	return filtered_messages


func get_chat_message_color_key(sender: String, metadata: Dictionary) -> String:
	if is_system_chat_message(sender, metadata):
		return "System"
	if is_broadcast_chat_message(metadata):
		return "Broadcast"
	return sender


func get_sender_color(sender: String) -> Color:
	match sender.strip_edges().to_lower():
		"system": return CHAT_SYSTEM_COLOR
		"server": return CHAT_SYSTEM_COLOR
		"broadcast": return Color(1.0, 0.72, 0.18, 1.0)
		"me":     return Color(0.92, 0.99, 1.0, 1.0)
		_:        return Color(0.97, 1.0, 1.0, 1.0)


func format_chat_message_line(sender: String, message: String, metadata: Dictionary) -> String:
	var display_message := get_display_chat_text(message, metadata)
	if is_broadcast_chat_message(metadata):
		var source_world: String = str(metadata.get("world", "")).strip_edges()
		if source_world != "":
			return "Broadcast [" + source_world + "] " + sender + ": " + display_message
		return "Broadcast " + sender + ": " + display_message
	if is_system_chat_message(sender, metadata):
		return "System: " + display_message

	return sender + ": " + display_message


func format_authored_chat_message_line(sender: String, message: String, metadata: Dictionary) -> String:
	var display_message := get_display_chat_text(message, metadata)
	if is_broadcast_chat_message(metadata):
		return format_chat_message_line(sender, message, metadata)
	if is_system_chat_message(sender, metadata):
		return "[System] " + display_message
	if sender == "Me":
		return "[Me] " + display_message
	return sender + ": " + display_message


func get_authored_sender_color(sender: String) -> Color:
	match sender.strip_edges().to_lower():
		"system": return CHAT_SYSTEM_COLOR
		"server": return CHAT_SYSTEM_COLOR
		"broadcast": return Color(1.0, 0.72, 0.18, 1.0)
		"me": return Color(1.0, 0.88, 0.25, 1.0)
		_: return Color(1.0, 1.0, 1.0, 1.0)


func refresh_chat_messages(force_scroll_to_bottom: bool = false):
	if chat_messages_root == null:
		return

	var previous_scroll: int = int(chat_messages_scroll.scroll_vertical) if chat_messages_scroll != null else 0
	var should_scroll_to_bottom: bool = (
		force_scroll_to_bottom
		or chat_scroll_stick_to_bottom
		or is_messages_scroll_at_bottom()
	)
	chat_message_refresh_generation += 1
	var refresh_generation: int = chat_message_refresh_generation

	if using_authored_scene_layout:
		refresh_authored_chat_messages(should_scroll_to_bottom, previous_scroll, refresh_generation)
		return

	for child in chat_messages_root.get_children():
		child.queue_free()
	var visible_messages: Array = get_filtered_chat_messages()
	var start_index = max(0, visible_messages.size() - MAX_CHAT_MESSAGES)
	var usable_width = max(300.0, chat_messages_root.size.x - 14.0)
	var total_height = 0.0
	for i in range(start_index, visible_messages.size()):
		var data = visible_messages[i]
		var sender = str(data["sender"])
		var message = str(data["message"])
		var metadata: Dictionary = get_chat_message_metadata(data)
		var source_world: String = str(metadata.get("world", "")).strip_edges()
		var is_broadcast: bool = is_broadcast_chat_message(metadata)
		var full_text = format_chat_message_line(sender, message, metadata)
		var label_width = max(1.0, usable_width - CHAT_MESSAGE_PAD_X * 2.0)
		var label = Label.new()
		label.name = "MessageLabel"
		label.add_theme_font_size_override("font_size", CHAT_MESSAGE_FONT_SIZE)
		apply_chat_font_to_control(label)
		label.add_theme_color_override("font_color", get_sender_color(get_chat_message_color_key(sender, metadata)))
		label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.72))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var wrapped_text = CHAT_BUBBLE_COMPONENT.wrap_text_to_width(
			full_text,
			label_width,
			label.get_theme_font("font"),
			CHAT_MESSAGE_FONT_SIZE
		)
		var line_count = CHAT_BUBBLE_COMPONENT.count_wrapped_lines(wrapped_text)
		var row_height = max(
			CHAT_MESSAGE_MIN_ROW_HEIGHT,
			float(line_count) * CHAT_MESSAGE_LINE_HEIGHT + CHAT_MESSAGE_PAD_Y * 2.0
		)
		var row = Panel.new()
		row.name = "MessageRow"
		row.custom_minimum_size = Vector2(usable_width, row_height)
		row.mouse_filter = Control.MOUSE_FILTER_STOP if is_broadcast and source_world != "" else Control.MOUSE_FILTER_IGNORE
		row.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
			Color(0.23, 0.17, 0.05, 0.34) if is_broadcast else Color(0.82, 0.94, 1.0, 0.095),
			Color(1.0, 0.76, 0.22, 0.40) if is_broadcast else Color(0.58, 0.84, 1.0, 0.20),
			1, 9, 1
		))
		if is_broadcast and source_world != "":
			row.gui_input.connect(_on_broadcast_row_gui_input.bind(source_world, row))
		chat_messages_root.add_child(row)
		label.text = wrapped_text
		label.position = Vector2(CHAT_MESSAGE_PAD_X, CHAT_MESSAGE_PAD_Y)
		label.size = Vector2(label_width, row_height - CHAT_MESSAGE_PAD_Y * 2.0)
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.clip_text = false
		row.add_child(label)
		total_height += row_height + 5.0
	var viewport_height: float = chat_messages_scroll.size.y if chat_messages_scroll != null else 320.0
	chat_messages_root.custom_minimum_size = Vector2(usable_width, max(total_height, viewport_height))
	finish_chat_message_refresh(should_scroll_to_bottom, previous_scroll, refresh_generation)


func refresh_authored_chat_messages(
	should_scroll_to_bottom: bool,
	previous_scroll: int,
	refresh_generation: int
):
	for child in chat_messages_root.get_children():
		child.queue_free()

	var visible_messages: Array = get_filtered_chat_messages()
	var start_index = max(0, visible_messages.size() - MAX_CHAT_MESSAGES)
	var usable_width: float = get_authored_message_width()
	var total_height: float = 0.0

	for i in range(start_index, visible_messages.size()):
		var data = visible_messages[i]
		var sender = str(data["sender"])
		var message = str(data["message"])
		var metadata: Dictionary = get_chat_message_metadata(data)
		var source_world: String = str(metadata.get("world", "")).strip_edges()
		var is_broadcast: bool = is_broadcast_chat_message(metadata)
		var full_text: String = format_authored_chat_message_line(sender, message, metadata)
		var label = Label.new()
		label.add_theme_font_size_override("font_size", CHAT_MESSAGE_FONT_SIZE)
		apply_chat_font_to_control(label)
		var wrapped_text: String = CHAT_BUBBLE_COMPONENT.wrap_text_to_width(
			full_text,
			usable_width,
			label.get_theme_font("font"),
			CHAT_MESSAGE_FONT_SIZE
		)
		var line_count: int = CHAT_BUBBLE_COMPONENT.count_wrapped_lines(wrapped_text)
		var row_height: float = max(CHAT_MESSAGE_MIN_ROW_HEIGHT, float(line_count) * CHAT_MESSAGE_LINE_HEIGHT + 4.0)

		label.name = "MessageRow"
		label.text = wrapped_text
		label.custom_minimum_size = Vector2(usable_width, row_height)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.clip_text = false
		label.add_theme_color_override("font_color", get_authored_sender_color(get_chat_message_color_key(sender, metadata)))
		label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 1.0))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		label.mouse_filter = Control.MOUSE_FILTER_STOP if is_broadcast and source_world != "" else Control.MOUSE_FILTER_IGNORE

		if is_broadcast and source_world != "":
			label.gui_input.connect(_on_broadcast_row_gui_input.bind(source_world, label))

		chat_messages_root.add_child(label)
		total_height += row_height

	var viewport_height: float = chat_messages_scroll.size.y if chat_messages_scroll != null else 320.0
	chat_messages_root.custom_minimum_size = Vector2(usable_width, max(total_height, viewport_height))
	finish_chat_message_refresh(should_scroll_to_bottom, previous_scroll, refresh_generation)


func finish_chat_message_refresh(
	should_scroll_to_bottom: bool,
	previous_scroll: int,
	refresh_generation: int
) -> void:
	if chat_messages_scroll == null:
		return

	await get_tree().process_frame
	await get_tree().process_frame
	if refresh_generation != chat_message_refresh_generation:
		return

	if should_scroll_to_bottom:
		set_messages_scroll_vertical(get_messages_scroll_max())
		chat_scroll_stick_to_bottom = true
	else:
		set_messages_scroll_vertical(previous_scroll)
		chat_scroll_stick_to_bottom = is_messages_scroll_at_bottom()


func get_authored_message_width() -> float:
	if chat_messages_scroll != null and chat_messages_scroll.size.x > 0.0:
		return max(300.0, chat_messages_scroll.size.x - 8.0)
	if chat_messages_root != null and chat_messages_root.size.x > 0.0:
		return max(300.0, chat_messages_root.size.x)
	return 980.0


func _on_broadcast_row_gui_input(event: InputEvent, world_name: String, row: Control) -> void:
	if _scroll_chat_messages_for_wheel(event):
		get_viewport().set_input_as_handled()
		return

	if world_name.strip_edges() == "":
		return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			start_broadcast_hold(row, world_name, mouse_event.position)
		else:
			cancel_broadcast_hold(row)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion:
		var motion_event: InputEventMouseMotion = event
		cancel_broadcast_hold_if_moved(row, motion_event.position)
		return

	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event
		if touch_event.pressed:
			start_broadcast_hold(row, world_name, touch_event.position)
		else:
			cancel_broadcast_hold(row)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenDrag:
		var drag_event: InputEventScreenDrag = event
		cancel_broadcast_hold_if_moved(row, drag_event.position)


func start_broadcast_hold(row: Control, world_name: String, start_position: Vector2) -> void:
	if row == null:
		return
	row.set_meta("broadcast_hold_active", true)
	row.set_meta("broadcast_hold_world", world_name)
	row.set_meta("broadcast_hold_start", start_position)
	row.modulate = Color(1.08, 1.02, 0.86, 1.0)
	_wait_for_broadcast_hold(row, world_name)


func cancel_broadcast_hold(row: Control) -> void:
	if row == null or not is_instance_valid(row):
		return
	row.set_meta("broadcast_hold_active", false)
	row.modulate = Color.WHITE


func cancel_broadcast_hold_if_moved(row: Control, current_position: Vector2) -> void:
	if row == null or not is_instance_valid(row):
		return
	if not bool(row.get_meta("broadcast_hold_active", false)):
		return
	var start_value: Variant = row.get_meta("broadcast_hold_start", current_position)
	if not (start_value is Vector2):
		return
	var start_position: Vector2 = start_value
	if start_position.distance_to(current_position) > BROADCAST_HOLD_MOVE_CANCEL:
		cancel_broadcast_hold(row)


func _wait_for_broadcast_hold(row: Control, world_name: String) -> void:
	await get_tree().create_timer(BROADCAST_HOLD_SECONDS).timeout
	if row == null or not is_instance_valid(row):
		return
	if not bool(row.get_meta("broadcast_hold_active", false)):
		return
	if str(row.get_meta("broadcast_hold_world", "")).strip_edges() != world_name.strip_edges():
		return
	row.set_meta("broadcast_hold_active", false)
	row.modulate = Color.WHITE
	warp_to_broadcast_world(world_name)


func warp_to_broadcast_world(world_name: String) -> void:
	var clean_world: String = world_name.strip_edges()
	if clean_world == "":
		return
	release_chat_focus()
	if world != null and world.has_method("enter_world_by_name"):
		world.enter_world_by_name(clean_world)
	if world != null and world.has_method("show_notification"):
		world.show_notification("Warping to " + clean_world + ".")


func show_chat_bubble(message: String):
	return show_bubble_message(message, Color.WHITE, BUBBLE_KIND_CHAT)


func show_notification_bubble(message: String):
	if not can_show_notification_bubble():
		hide_notification_bubble()
		return false
	return show_bubble_message(message, NOTIFICATION_BUBBLE_TEXT_COLOR, BUBBLE_KIND_NOTIFICATION)


func show_bubble_message(message: String, text_color: Color = Color.WHITE, bubble_kind: String = BUBBLE_KIND_CHAT) -> bool:
	if chat_bubble_node == null:
		setup_chat_bubble()
	if chat_bubble_node == null:
		return false

	var clean_message = message.strip_edges()
	if clean_message == "":
		return false
	if bubble_kind == BUBBLE_KIND_CHAT:
		clean_message = get_filtered_chat_text(clean_message)

	var was_shown := true
	if bubble_kind == BUBBLE_KIND_NOTIFICATION and chat_bubble_node.has_method("show_notification_message"):
		was_shown = bool(chat_bubble_node.show_notification_message(clean_message, text_color))
	else:
		chat_bubble_node.show_chat_message(clean_message, text_color)
	if not was_shown:
		return false
	active_bubble_kind = bubble_kind
	var anchor_screen_pos = _get_local_chat_anchor_screen_position()
	_position_bubble_on_screen(anchor_screen_pos)
	return true


func _position_bubble_on_screen(anchor_screen_pos: Vector2):
	if chat_bubble_node == null:
		return
	if chat_bubble_node.size.x <= 0.0 or chat_bubble_node.size.y <= 0.0:
		return

	var bubble_position = Vector2(
		round(anchor_screen_pos.x - chat_bubble_node.size.x / 2.0),
		round(anchor_screen_pos.y - chat_bubble_node.size.y)
	)
	chat_bubble_node.position = CHAT_BUBBLE_COMPONENT.clamp_screen_position(
		bubble_position,
		chat_bubble_node.size,
		chat_bubble_node.get_viewport()
	)


func _get_local_chat_anchor_world_position() -> Vector2:
	if player == null:
		return Vector2.ZERO

	var anchor = player.get_node_or_null("ChatBubbleAnchor")
	if anchor is Node2D:
		return anchor.global_position
	return player.global_position + Vector2(0.0, -CHAT_BUBBLE_COMPONENT.get_anchor_offset_world_px())


func _get_local_username_label_for_chat() -> Label:
	var overhead_layer = null
	if world != null:
		if world.has_method("get_ui_overhead_layer"):
			overhead_layer = world.get_ui_overhead_layer()
		elif "ui_overhead_layer" in world and world.ui_overhead_layer != null:
			overhead_layer = world.ui_overhead_layer
		elif "ui_layer" in world:
			overhead_layer = world.ui_layer

	if overhead_layer == null:
		return null

	var username_label = overhead_layer.get_node_or_null("PlayerUsernameLabel")
	if not (username_label is Label):
		return null

	return username_label


func _get_local_chat_anchor_screen_position() -> Vector2:
	if chat_bubble_node == null:
		return Vector2.ZERO

	var local_username_label := _get_local_username_label_for_chat()
	if local_username_label is Label and local_username_label.text.strip_edges() != "":
		return Vector2(
			local_username_label.position.x + local_username_label.size.x * 0.5,
			local_username_label.position.y - CHAT_BUBBLE_COMPONENT.get_username_gap_screen_px()
		)

	var anchor_world_pos = _get_local_chat_anchor_world_position()
	var viewport = chat_bubble_node.get_viewport()
	if viewport == null:
		return Vector2.ZERO

	return CHAT_BUBBLE_COMPONENT.world_to_screen_position(viewport, anchor_world_pos)


func update_chat_bubble_style_size(_message: String):
	return


func update_chat_bubble(_delta):
	if chat_bubble_node == null:
		return
	if chat_bubble_node.visible == false:
		active_bubble_kind = BUBBLE_KIND_NONE
		return
	if player == null or world == null:
		return
	var anchor_screen_pos = _get_local_chat_anchor_screen_position()
	_position_bubble_on_screen(anchor_screen_pos)
