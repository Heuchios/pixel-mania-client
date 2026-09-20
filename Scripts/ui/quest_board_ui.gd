extends Control

const Style = preload("res://Scripts/ui/pixel_ui_style.gd")
const DARK = Color("301b3a")
const LAVENDER = Color("e7c9ee")
const GOLD = Color("ffdc7b")
const CARD_TEXTURE = preload("res://Assets/ui/SHOP/item_card.png")
const FONT = preload("res://Assets/font/font.ttf")
const PORTRAITS = preload("res://Assets/quests/dispatch_portraits.png")
const Decoration = preload("res://Scripts/ui/dispatch_decoration.gd")
const QuestItems = preload("res://Scripts/item_database.gd")
const FAMILY_ICONS = {
	"letters": "res://Assets/ui/icons/shop.png",
	"building": "res://Assets/ui/icons/shop_cat_stations.png",
	"garden": "res://Assets/ui/icons/shop_cat_featured.png",
	"water": "res://Assets/ui/icons/shop_cat_fishing.png",
	"workshop": "res://Assets/ui/icons/shop_cat_stations.png",
	"exploring": "res://Assets/ui/icons/shop_cat_special.png"
}

var world = null
var board: Dictionary = {}
var current_grid := Vector2i.ZERO
var current_tab := "today"
var selected_tier := ""
var answer: Array = []
var answer_instance := ""
var match_slot := 0
var pending_id := ""
var pending_at := 0
var clock_offset := 0
var last_refresh_day := -1
var request_sequence := 0
var accepting_tier := ""
var opened_world := ""
var header_decoration
var base_panel_style: StyleBox
var reset_label: Label

@onready var panel: PanelContainer = $Panel
@onready var content: VBoxContainer = $Panel/Margin/Layout/Scroll/Content
@onready var status: Label = $Panel/Margin/Layout/Status
@onready var footer: Label = $Panel/Margin/Layout/Footer
@onready var wallet: Label = $Panel/Margin/Layout/Header/Wallet
@onready var title: Label = $Panel/Margin/Layout/Header/Title
@onready var scroll: ScrollContainer = $Panel/Margin/Layout/Scroll

func _ready() -> void:
	theme = Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 24
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	base_panel_style = panel.get_theme_stylebox("panel")
	header_decoration = Decoration.new()
	$Panel/Margin/Layout/Header.add_child(header_decoration)
	$Panel/Margin/Layout/Header.move_child(header_decoration, 0)
	$Panel/Margin/Layout/Header/Close.pressed.connect(close_quest_board)
	for pair in [["Today", "today"], ["Storybook", "storybook"], ["Rewards", "rewards"]]:
		var button: Button = get_node("Panel/Margin/Layout/Tabs/" + pair[0])
		_style_button(button)
		button.pressed.connect(_change_tab.bind(pair[1]))
	Style.apply_close_button($Panel/Margin/Layout/Header/Close)
	$Panel/Margin/Layout/Tabs/Today.text = "DAILY QUESTS"
	reset_label = Label.new()
	reset_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reset_label.add_theme_color_override("font_color", DARK)
	reset_label.add_theme_font_size_override("font_size", 18)
	$Panel/Margin/Layout.add_child(reset_label)
	$Panel/Margin/Layout.move_child(reset_label, 2)
	for label in [title, wallet, status, footer]:
		label.add_theme_color_override("font_color", DARK)
	resized.connect(_fit)
	_fit()
	hide()

func setup(parent_world, _ui_node = null) -> void:
	world = parent_world

func _fit() -> void:
	if not is_instance_valid(panel):
		return
	var viewport_size := get_viewport_rect().size
	title.add_theme_font_size_override("font_size", 24 if viewport_size.x < 950 else 34)
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	panel.size = Vector2(minf(1160.0, maxf(580.0, viewport_size.x - 32.0)), minf(760.0, maxf(290.0, viewport_size.y - 32.0)))
	panel.position = (viewport_size - panel.size) * 0.5
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2.ONE * minf(1.0, minf((viewport_size.x - 16.0) / panel.size.x, (viewport_size.y - 16.0) / panel.size.y))

func open_quest_board(grid_pos: Vector2i) -> void:
	current_grid = grid_pos
	opened_world = str(world.current_world_name) if world != null else ""
	current_tab = "today"
	selected_tier = ""
	board = {}
	pending_id = ""
	show()
	_fit()
	_render()
	_request("quest_board_get")

func close_quest_board() -> void:
	hide()
	if world != null and world.has_method("reset_mobile_pointer_state"):
		world.reset_mobile_pointer_state()

func is_quest_board_open() -> bool:
	return visible

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_quest_board()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not visible:
		return
	if world != null and (not world.in_world or str(world.current_world_name) != opened_world):
		close_quest_board()
		return
	if not pending_id.is_empty() and Time.get_ticks_msec() - pending_at > 12000:
		pending_id = ""
		status.text = "Connection delayed. Reopen the board to check your saved progress."
		_render()
	if not board.is_empty():
		var remaining := maxi(0, int(board.get("reset_at", 0)) - Time.get_ticks_msec() - clock_offset)
		var seconds := int(remaining / 1000.0)
		reset_label.text = "New daily quests in %02dh %02dm" % [int(seconds / 3600.0), int(seconds / 60.0) % 60]
		footer.text = "%d / 5 DAYS  |  +100 XP WEEKLY BONUS" % int(board.get("week_days", 0))
		if remaining == 0 and pending_id.is_empty() and last_refresh_day != int(board.get("day", -1)):
			last_refresh_day = int(board.get("day", -1))
			_request("quest_board_get")

func _request(action: String, data: Dictionary = {}) -> void:
	if not pending_id.is_empty():
		return
	request_sequence += 1
	pending_id = "quest_%s_%s" % [Time.get_ticks_usec(), request_sequence]
	pending_at = Time.get_ticks_msec()
	var packet := data.duplicate(true)
	packet.merge({"action": action, "request_id": pending_id, "x": current_grid.x, "y": current_grid.y, "revision": int(board.get("revision", 0))}, true)
	var network = get_node_or_null("/root/NetworkManager")
	if network == null or not network.send_inventory_transaction_request(packet):
		pending_id = ""
		status.text = "Connect to the game server to read the Dispatch."
	else:
		status.text = "Reading your letter..." if action == "quest_board_get" else "Saving your Dispatch..."
	_render()

func handle_inventory_transaction_result(data: Dictionary) -> bool:
	if not str(data.get("action", "")).begins_with("quest_"):
		return false
	if str(data.get("request_id", "")) != pending_id:
		return true
	pending_id = ""
	status.text = str(data.get("message", "Please try again."))
	if bool(data.get("ok", false)) and not accepting_tier.is_empty():
		selected_tier = accepting_tier
	accepting_tier = ""
	var incoming = data.get("quest_board")
	if incoming is Dictionary and not incoming.is_empty():
		load_snapshot(incoming)
	else:
		_render()
	return true

func load_snapshot(snapshot: Dictionary) -> void:
	board = snapshot.duplicate(true)
	clock_offset = int(board.get("server_time", 0)) - Time.get_ticks_msec()
	if not selected_tier.is_empty() and not board.get("active", {}).has(selected_tier):
		selected_tier = ""
	_render()

func _change_tab(tab: String) -> void:
	current_tab = tab
	selected_tier = ""
	scroll.scroll_vertical = 0
	_render()

func _style_button(button: Button, green := false) -> void:
	if green:
		Style.apply_green_button(button, 24)
	else:
		button.add_theme_stylebox_override("normal", Style.style_box(DARK, Color("9872b0"), 2, 0, 0))
		button.add_theme_stylebox_override("hover", Style.style_box(Color("503059"), LAVENDER, 2, 0, 0))
		button.add_theme_stylebox_override("pressed", Style.style_box(Color("503059"), GOLD, 2, 0, 0))
		button.add_theme_color_override("font_color", Color.WHITE)
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.custom_minimum_size.y = 48
	button.disabled = not pending_id.is_empty()

func _button(parent: Node, text: String, callback: Callable, green := false) -> Button:
	var button := Button.new()
	button.text = text
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(button, green)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _label(parent: Node, text: String, color := Color.WHITE, font_size := 24) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _box(parent: Node) -> VBoxContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", Style.style_box(DARK, Color("9671ad"), 3, 0, 0))
	parent.add_child(card)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	card.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	return column

func _render() -> void:
	if not is_instance_valid(content):
		return
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	wallet.text = "GEMS + XP"
	title.text = "QUEST JOURNAL"
	if current_tab == "today" and status.text == "Your story waits for you.":
		status.text = "Play to complete your quests. Return here to refresh progress and claim."
	header_decoration.hide()
	panel.add_theme_stylebox_override("panel", base_panel_style)
	for cosmetic in board.get("cosmetics", []):
		if cosmetic.id == board.get("equipped", ""):
			panel.add_theme_stylebox_override("panel", Style.style_box(LAVENDER, Color(str(cosmetic.color)), 6, 0, 0))
			header_decoration.cosmetic_id = str(cosmetic.id)
			header_decoration.tint = Color(str(cosmetic.color))
			header_decoration.show()
			header_decoration.queue_redraw()
	for pair in [["Today", "today"], ["Storybook", "storybook"], ["Rewards", "rewards"]]:
		var tab: Button = get_node("Panel/Margin/Layout/Tabs/" + pair[0])
		tab.add_theme_color_override("font_color", GOLD if current_tab == pair[1] else Color.WHITE)
	if board.is_empty():
		reset_label.text = ""
		_label(_box(content), "DAILY QUESTS", GOLD, 32)
		_label(_box(content), "Loading your objectives and rewards...")
		return
	if not selected_tier.is_empty():
		_render_active(selected_tier)
	elif current_tab == "rewards":
		_render_rewards()
	elif current_tab == "storybook":
		_render_archive()
	else:
		_render_today()
	_fit()

func _render_today() -> void:
	var toolbar := HBoxContainer.new()
	content.add_child(toolbar)
	_label(toolbar, "All daily quests are active. Complete each to claim its rewards.", DARK, 18)
	var refresh := _button(toolbar, "REFRESH", _request.bind("quest_board_get"))
	refresh.size_flags_horizontal = Control.SIZE_SHRINK_END
	refresh.custom_minimum_size.x = 165
	if board.get("daily_mode", "") == "automatic":
		for daily in board.get("dailies", []):
			var active: Dictionary = board.get("active", {}).get(daily.slot, {})
			_render_daily_row(daily.quest, daily.slot, active, bool(daily.claimed))
		return
	for tier in ["favor", "trip"]:
		if board.get("active", {}).has(tier):
			var active: Dictionary = board.active[tier]
			_render_daily_row(active.quest, tier, active)
		elif board.get("done", {}).get(tier, false):
			_label(_box(content), ("EASY" if tier == "favor" else "CHALLENGE") + "  |  REWARD CLAIMED — new quest at reset", Color("b9f3cf"), 20)
		else:
			for quest in board.get("offers", {}).get(tier, []):
				_render_daily_row(quest, tier)

func _render_daily_row(quest: Dictionary, tier: String, active: Dictionary = {}, claimed := false) -> void:
	var box := _box(content)
	var row := HBoxContainer.new()
	row.tooltip_text = str(quest.get("opening", ""))
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var objectives: Array = active.get("objectives", quest.get("objectives", []))
	var objective: Dictionary = objectives[0] if not objectives.is_empty() else {}
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(64, 64)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.texture = _objective_icon(objective)
	row.add_child(icon)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 8)
	row.add_child(details)
	_label(details, "%s  [%s]" % [str(quest.get("title", "Daily quest")), "EASY" if tier.begins_with("favor") else "CHALLENGE"], Color.WHITE, 22)
	for i in range(objectives.size()):
		var target := maxi(1, int(objectives[i].target))
		var progress: Array = active.get("progress", [])
		var count := mini(target, int(progress[i])) if i < progress.size() else 0
		if claimed:
			count = target
		_label(details, str(objectives[i].label), LAVENDER, 18)
		var bar := ProgressBar.new()
		bar.custom_minimum_size.y = 12
		bar.max_value = target
		bar.value = count
		bar.show_percentage = false
		var track := StyleBoxFlat.new()
		track.bg_color = Color("190e21")
		bar.add_theme_stylebox_override("background", track)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("72d99e")
		bar.add_theme_stylebox_override("fill", fill)
		details.add_child(bar)
		_label(details, "%d / %d" % [count, target], GOLD, 17)
	var rewards := VBoxContainer.new()
	rewards.custom_minimum_size.x = 225 if panel.size.x >= 900 else 150
	rewards.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(rewards)
	var reward: Dictionary = active.get("reward", quest.get("reward", {}))
	_label(rewards, "%d GEMS  +  %d XP" % [int(reward.get("gems", 0)), int(reward.get("xp", 0))], GOLD, 18)
	if claimed:
		var complete := _button(rewards, "CLAIMED", close_quest_board)
		complete.disabled = true
		complete.add_theme_color_override("font_disabled_color", Color("72d99e"))
	elif active.is_empty():
		_button(rewards, "START QUEST", _accept.bind(quest.id, tier), true)
	elif active.get("solved", false):
		_button(rewards, "CLAIM REWARD", _active_request.bind("quest_choose", tier, {"choice": str(quest.choices[0].id)}), true)
	else:
		var incomplete := _button(rewards, "NOT COMPLETE", close_quest_board)
		incomplete.disabled = true
		incomplete.add_theme_stylebox_override("disabled", Style.atlas_style("red_button", Color.WHITE, 3))
		incomplete.add_theme_color_override("font_disabled_color", Color("f3b5bd"))

func _objective_icon(objective: Dictionary) -> Texture2D:
	var item_id := str(objective.get("item_type", ""))
	var action := str(objective.get("action", "plant"))
	if action == "fish":
		return load("res://Assets/inventory_icons/fishing_rod.png")
	if item_id.is_empty():
		item_id = "grass" if action in ["plant", "harvest", "splice"] else "dirt"
	item_id = item_id.trim_suffix("_seed")
	if action != "fish":
		var item: Dictionary = world.item_database.get(item_id, {}) if world != null else QuestItems.ITEMS.get(item_id, {})
		var source = item.get("inventory_icon", item.get("texture", null))
		if source is Texture2D:
			return source
		if source is String and ResourceLoader.exists(source):
			return load(source)
		if source is Dictionary and source.has("atlas"):
			var texture := AtlasTexture.new()
			texture.atlas = load(str(source.atlas))
			var cell: Array = source.get("cell", [0, 0])
			var cell_size: Array = source.get("cell_size", [32, 32])
			texture.region = Rect2(int(cell[0]) * int(cell_size[0]), int(cell[1]) * int(cell_size[1]), int(cell_size[0]), int(cell_size[1]))
			return texture
	return load("res://Assets/ui/icons/shop_cat_fishing.png" if action == "fish" else "res://Assets/ui/icons/shop_cat_featured.png")

func _render_story() -> void:
	var story_column := _box(content)
	_label(story_column, "YOUR STORY", GOLD, 28)
	if board.get("active", {}).has("story"):
		_label(story_column, str(board.active.story.quest.title))
		_button(story_column, "CONTINUE STORY", _select_active.bind("story"), true)
	elif board.get("done", {}).get("story", false):
		_label(story_column, "Today's chapter is complete. The next chapter arrives at reset.")
	else:
		var quest: Dictionary = board.get("story", {})
		if not quest.is_empty():
			_render_offer(story_column, quest, "story")


func _render_offer(parent: Node, quest: Dictionary, tier: String) -> void:
	var box := _box(parent)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 12)
	box.add_child(heading)
	_portrait(heading, str(quest.get("npc", "Pip")))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(words)
	_label(words, str(quest.get("title", "Letter")), Color.WHITE, 24)
	_label(words, str(quest.get("npc", "Pip")) + "  |  " + str(quest.get("family", "letters")).capitalize(), GOLD, 20)
	if tier == "story":
		_label(box, str(quest.get("opening", "")), LAVENDER, 22)
		if not str(quest.get("callback", "")).is_empty():
			_label(box, str(quest.callback), GOLD, 20)
	for objective in quest.get("objectives", []):
		_label(box, str(objective.label), GOLD, 22)
	_label(box, "%d GEMS + %d XP" % [int(quest.get("reward", {}).get("gems", 0)), int(quest.get("reward", {}).get("xp", 0))], LAVENDER, 20)
	_button(box, "READ LETTER" if tier == "story" else "TAKE THIS LETTER", _accept.bind(quest.id, tier), true)

func _accept(quest_id: String, tier: String) -> void:
	accepting_tier = tier if tier == "story" else ""
	_request("quest_accept", {"quest_id": quest_id, "tier": tier})

func _portrait(parent: Node, npc: String) -> void:
	var names := ["Pip", "Rue", "Nell", "Tansy", "Bolt", "Mica"]
	var index := maxi(0, names.find(npc))
	var atlas := AtlasTexture.new()
	atlas.atlas = PORTRAITS
	atlas.region = Rect2((index % 3) * 512, int(index / 3.0) * 512, 512, 512)
	var portrait := TextureRect.new()
	portrait.texture = atlas
	portrait.custom_minimum_size = Vector2(72, 72)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(portrait)

func _select_active(tier: String) -> void:
	selected_tier = tier
	scroll.scroll_vertical = 0
	_render()

func _active_request(action: String, tier: String, data: Dictionary = {}) -> void:
	var active: Dictionary = board.get("active", {}).get(tier, {})
	if active.is_empty():
		return
	data["tier"] = tier
	data["instance_id"] = active.id
	_request(action, data)

func _render_active(tier: String) -> void:
	var active: Dictionary = board.get("active", {}).get(tier, {})
	if active.is_empty():
		selected_tier = ""
		_render_today()
		return
	var instance_key := "%s:%s:%s" % [active.id, active.quest.id, active.accepted_at]
	if answer_instance != instance_key:
		answer_instance = instance_key
		answer = []
		match_slot = 0
	_button(content, "BACK TO TODAY", _change_tab.bind("today"))
	var column := _box(content)
	_portrait(column, str(active.quest.npc))
	_label(column, str(active.quest.title), GOLD, 30)
	_label(column, str(active.quest.opening), LAVENDER)
	if not str(active.quest.get("callback", "")).is_empty():
		_label(column, str(active.quest.callback), GOLD, 22)
	_label(column, "%d GEMS + %d XP" % [int(active.reward.gems), int(active.reward.get("xp", 0))], GOLD, 22)
	if active.get("solved", false):
		if tier != "story":
			_button(column, "CLAIM REWARD", _active_request.bind("quest_choose", tier, {"choice": str(active.quest.choices[0].id)}), true)
			return
		_label(column, "HOW DOES YOUR LETTER END?", Color.WHITE, 28)
		for choice in active.quest.choices:
			_button(column, str(choice.label), _active_request.bind("quest_choose", tier, {"choice": choice.id}), true)
		return
	if active.has("objectives"):
		_label(column, "COMPLETE THROUGH GAMEPLAY", Color.WHITE, 28)
		for i in range(active.objectives.size()):
			var objective: Dictionary = active.objectives[i]
			var count := int(active.progress[i]) if i < active.get("progress", []).size() else 0
			_label(column, "%s  |  %d / %d" % [str(objective.label), count, int(objective.target)], GOLD)
			var bar := ProgressBar.new()
			bar.max_value = int(objective.target)
			bar.value = count
			bar.custom_minimum_size.y = 24
			column.add_child(bar)
		_label(column, "Daily quests track successful gameplay from the daily reset once you have visited the board. Story quests track from acceptance. Harvest mature trees; fishing must land a fish. Return to refresh progress and claim.", LAVENDER, 22)
		_button(column, "GO PLAY", close_quest_board, true)
		_button(column, "REFRESH PROGRESS", _request.bind("quest_board_get"))
		if tier == "story":
			_button(column, "ABANDON QUEST", _confirm_abandon.bind(tier))
		return
	_label(column, "1. INSPECT THE CLUES", Color.WHITE, 26)
	var puzzle: Dictionary = active.puzzle
	for index in range(puzzle.clues.size()):
		var read: bool = active.inspected.has(index)
		_button(column, ("READ: " if read else "OPEN: ") + str(puzzle.clues[index]), _active_request.bind("quest_inspect", tier, {"clue": index}))
	_label(column, "2. " + str(puzzle.prompt), Color.WHITE, 26)
	if puzzle.kind == "build":
		var grid := GridContainer.new()
		grid.columns = 5
		grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(grid)
		for cell in range(25):
			var tile := _button(grid, "%s%s%s" % [String.chr(65 + cell % 5), int(cell / 5.0) + 1, " +" if answer.has(cell) else ""], _toggle_cell.bind(cell))
			tile.custom_minimum_size = Vector2(68, 54)
			if answer.has(cell):
				Style.apply_green_button(tile, 24)
	else:
		if puzzle.kind == "match":
			for index in range(puzzle.slots.size()):
				var picked := str(puzzle.cards[answer[index]]) if index < answer.size() and int(answer[index]) >= 0 else "Choose a card"
				_button(column, ("> " if match_slot == index else "") + str(puzzle.slots[index]) + " → " + picked, _select_match_slot.bind(index))
		else:
			var ordered := PackedStringArray()
			for index in answer:
				ordered.append(str(puzzle.cards[int(index)]))
			_label(column, "Your order: " + " → ".join(ordered), GOLD, 22)
		for index in puzzle.get("display_order", []):
			_button(column, str(puzzle.cards[int(index)]), _pick_card.bind(int(index), str(puzzle.kind)))
	_button(column, "CLEAR ANSWER", _clear_answer)
	if active.get("hint", false):
		_label(column, "HINT: " + str(puzzle.hint), GOLD)
	_button(column, "ASK FOR A HINT", _active_request.bind("quest_hint", tier))
	_button(column, "CHECK MY ANSWER", _submit_answer.bind(tier), true)
	_button(column, "PUT THIS LETTER AWAY", _confirm_abandon.bind(tier))

func _toggle_cell(cell: int) -> void:
	if answer.has(cell):
		answer.erase(cell)
	else:
		answer.append(cell)
	_render()

func _select_match_slot(index: int) -> void:
	match_slot = index
	_render()

func _pick_card(index: int, kind: String) -> void:
	if kind == "match":
		while answer.size() <= match_slot:
			answer.append(-1)
		answer[match_slot] = index
		match_slot = mini(2, match_slot + 1)
	elif not answer.has(index):
		answer.append(index)
	_render()

func _clear_answer() -> void:
	answer = []
	_render()

func _submit_answer(tier: String) -> void:
	_active_request("quest_solve", tier, {"answer": answer.duplicate()})

func _confirm_abandon(tier: String) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "Abandon this quest? Its objective progress will reset. Your own items and earned rewards are kept."
	dialog.confirmed.connect(func():
		_active_request("quest_abandon", tier)
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(480, 180))

func _render_archive() -> void:
	_render_story()
	_label(_box(content), "THE TOWN THAT MISPLACED TOMORROW", GOLD, 30)
	var chapters: Dictionary = board.get("chapters", {})
	if chapters.is_empty():
		_label(_box(content), "Your first postcard is waiting in Today's Dispatch. Story chapters never expire.")
	var chapter_ids := chapters.keys()
	chapter_ids.sort()
	for id in chapter_ids:
		var entry: Dictionary = chapters[id]
		var box := _box(content)
		_portrait(box, str(entry.get("npc", "Pip")))
		_label(box, str(entry.title), GOLD, 26)
		_label(box, "Your choice: " + str(entry.label), LAVENDER)
		_label(box, str(entry.reply))
		if entry.get("arc_reward") != null:
			_label(box, "ARC EMBLEM: " + str(entry.arc_reward), GOLD, 22)
		if entry.get("postcard") != null:
			_label(box, "POSTCARD: " + str(entry.postcard), LAVENDER, 22)

func _render_rewards() -> void:
	_label(_box(content), "DISPATCH COLLECTION", GOLD, 30)
	_label(_box(content), "%d legacy stamps. New daily quests reward gems and XP." % int(board.get("stamps", 0)), LAVENDER, 22)
	_label(_box(content), "Guaranteed cosmetics for your Dispatch. No loot boxes, no trading, and no extra quest slots.", LAVENDER)
	for reward in board.get("cosmetics", []):
		var box := _box(content)
		var decoration = Decoration.new()
		decoration.cosmetic_id = str(reward.id)
		decoration.tint = Color(str(reward.color))
		box.add_child(decoration)
		_label(box, str(reward.name), Color(str(reward.color)), 28)
		_label(box, "%s  |  %s STAMPS" % [str(reward.kind).capitalize(), reward.price], LAVENDER)
		if reward.get("owned", false):
			_button(box, "EQUIPPED" if board.get("equipped", "") == reward.id else "USE ON MY DISPATCH", _request.bind("quest_equip", {"cosmetic_id": reward.id}), true)
		else:
			var buy := _button(box, "REDEEM %s STAMPS" % reward.price, _request.bind("quest_redeem", {"cosmetic_id": reward.id}), true)
			buy.disabled = not pending_id.is_empty() or int(board.get("stamps", 0)) < int(reward.price)
