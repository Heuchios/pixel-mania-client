extends Control

# RecipeBookScene
# ---------------------------------------------------------------------------
# Recipe book UI. It is a READ-ONLY reference view: it renders recipe data and
# never mutates inventory, world state or anything server-authoritative, so it
# needs no packets and no server round-trip.
#
# Data comes from RecipeBookData, which derives the entries from the client
# item database + ItemDatabase.SPLICE_RECIPES. Call setup(world) once (the
# gameplay UI manager does this) and the book keeps itself populated.
# set_tier_recipes()/set_all_recipes() stay public so other sources (crafting,
# furnace, a future server-side discovery table) can feed it too.
#
# Skinning:
#   Every panel/button uses placeholder StyleBoxFlat resources. Swap each to a
#   StyleBoxTexture, or drop textures on the TextureRect nodes. Generated nodes
#   are duplicated from the hidden template nodes, so skinning a template skins
#   every generated child:
#     TierTabs/TierTabTemplate          -> every tier tab
#     RecipeGrid/SlotTemplate           -> every recipe slot
#     IngredientsGrid/MiniSlotTemplate  -> every "made from" slot
#     UsedForGrid/MiniSlotTemplate      -> every "used for" slot
#
# Recipe dictionary shape (all keys optional except "id"):
#   {
#     "id": "wood_plank", "name": "Wood Plank", "icon": Texture2D,
#     "description": "...", "category": "blocks",
#     "found": true,                     # omit entirely when unknown
#     "ingredients": [{"id":.., "name":.., "icon":.., "count":..}],
#     "used_for": [{"id":.., "name":.., "icon":..}]
#   }
# When no recipe carries a "found" key the footer shows a plain total instead
# of a discovery counter, so the book never claims progress it cannot know.
# ---------------------------------------------------------------------------

signal closed()
signal tier_changed(tier: int)
signal recipe_selected(tier: int, recipe_id: String)
signal recipe_deselected()
signal filters_changed(active_categories: PackedStringArray)

const RecipeBookData = preload("res://Scripts/ui/recipe_book_data.gd")

const SLOT_INDEX_META := &"recipe_slot_index"
const RECIPE_ID_META := &"recipe_id"
const CATEGORY_META := &"category"

const WINDOW_BASE_SIZE := Vector2(1024.0, 660.0)
const WINDOW_SCREEN_MARGIN := Vector2(32.0, 32.0)
const MIN_WINDOW_SCALE := 0.42

@export_group("Tiers")
@export var first_tier: int = 1
@export var tier_count: int = 10
@export var start_tier: int = 1
## Shrink the tab strip to the tiers that actually have recipes.
@export var auto_tier_range: bool = true

@export_group("Grid")
@export var slot_columns: int = 10
## Empty slots drawn for a tier with no recipe data, so the layout stays
## visible while you are skinning. Set to 0 to disable.
@export var placeholder_slot_count: int = 45

@export_group("Text")
@export var title_text: String = "Recipe Book"
@export var tier_tab_format: String = "TIER %d"
@export var found_format: String = "Tier %d recipes found %d/%d"
@export var total_format: String = "Tier %d recipes: %d"
@export var empty_detail_title: String = "Select a recipe"
@export var empty_detail_text: String = "Pick a slot to see what it is made from."

@export_group("Behaviour")
@export var close_on_escape: bool = true
@export var start_hidden: bool = true
@export var play_open_animation: bool = true

@onready var backdrop: ColorRect = get_node_or_null("Backdrop") as ColorRect
@onready var window: Control = get_node_or_null("Window") as Control
@onready var title_label: Label = get_node_or_null("Window/Margin/Layout/TitleBar/TitleLabel") as Label
@onready var close_button: Button = get_node_or_null("Window/Margin/Layout/TitleBar/CloseButton") as Button
@onready var tier_tabs: HBoxContainer = get_node_or_null("Window/Margin/Layout/TierTabsScroll/TierTabs") as HBoxContainer
@onready var tier_tab_template: Button = get_node_or_null("Window/Margin/Layout/TierTabsScroll/TierTabs/TierTabTemplate") as Button
@onready var recipe_grid: GridContainer = get_node_or_null("Window/Margin/Layout/Body/GridPanel/GridMargin/GridScroll/RecipeGrid") as GridContainer
@onready var slot_template: Button = get_node_or_null("Window/Margin/Layout/Body/GridPanel/GridMargin/GridScroll/RecipeGrid/SlotTemplate") as Button
@onready var detail_panel: Control = get_node_or_null("Window/Margin/Layout/Body/DetailPanel") as Control
@onready var detail_title: Label = get_node_or_null("Window/Margin/Layout/Body/DetailPanel/DetailMargin/DetailLayout/DetailHeader/DetailTitle") as Label
@onready var detail_close_button: Button = get_node_or_null("Window/Margin/Layout/Body/DetailPanel/DetailMargin/DetailLayout/DetailHeader/DetailCloseButton") as Button
@onready var preview_icon: TextureRect = get_node_or_null("Window/Margin/Layout/Body/DetailPanel/DetailMargin/DetailLayout/PreviewRow/PreviewSlot/Icon") as TextureRect
@onready var detail_description: RichTextLabel = get_node_or_null("Window/Margin/Layout/Body/DetailPanel/DetailMargin/DetailLayout/DetailDescription") as RichTextLabel
@onready var ingredients_label: Label = get_node_or_null("Window/Margin/Layout/Body/DetailPanel/DetailMargin/DetailLayout/IngredientsLabel") as Label
@onready var ingredients_grid: GridContainer = get_node_or_null("Window/Margin/Layout/Body/DetailPanel/DetailMargin/DetailLayout/IngredientsGrid") as GridContainer
@onready var used_for_label: Label = get_node_or_null("Window/Margin/Layout/Body/DetailPanel/DetailMargin/DetailLayout/UsedForLabel") as Label
@onready var used_for_grid: GridContainer = get_node_or_null("Window/Margin/Layout/Body/DetailPanel/DetailMargin/DetailLayout/UsedForGrid") as GridContainer
@onready var filters_box: HBoxContainer = get_node_or_null("Window/Margin/Layout/Footer/Filters") as HBoxContainer
@onready var found_label: Label = get_node_or_null("Window/Margin/Layout/Footer/FoundLabel") as Label

var world = null

# tier (int) -> Array[Dictionary]
var _tier_recipes: Dictionary = {}
var _tier_buttons: Dictionary = {}
var _current_tier: int = -1
var _selected_recipe_id: String = ""
var _slot_pool: Array[Button] = []
var _ingredient_pool: Array[Button] = []
var _used_for_pool: Array[Button] = []
var _filter_boxes: Array[CheckBox] = []
var _visible_recipes: Array = []
var _window_fit_scale: float = 1.0


func _ready() -> void:
	if title_label != null:
		title_label.text = title_text
	if close_button != null and not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)
	if detail_close_button != null and not detail_close_button.pressed.is_connected(clear_selection):
		detail_close_button.pressed.connect(clear_selection)
	if backdrop != null and not backdrop.gui_input.is_connected(_on_backdrop_gui_input):
		backdrop.gui_input.connect(_on_backdrop_gui_input)
	if not resized.is_connected(_fit_window_to_screen):
		resized.connect(_fit_window_to_screen)

	_hide_template(tier_tab_template)
	_hide_template(slot_template)
	_hide_template(_mini_template(ingredients_grid))
	_hide_template(_mini_template(used_for_grid))

	if recipe_grid != null:
		recipe_grid.columns = maxi(1, slot_columns)

	_collect_filter_boxes()
	_build_tier_tabs()
	_clear_detail()
	_fit_window_to_screen()

	if start_hidden:
		visible = false
	else:
		select_tier(start_tier)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not close_on_escape:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _selected_recipe_id != "":
			clear_selection()
		else:
			_on_close_pressed()


# --- Game wiring ------------------------------------------------------------

## Called once by the gameplay UI manager. Only stores the reference: the
## recipe list is built lazily on first open so world entry does not pay for
## parsing recipes and resolving icons the player may never look at.
func setup(world_ref) -> void:
	world = world_ref


func refresh_from_world() -> bool:
	if world == null or not is_instance_valid(world):
		return false
	var recipes_by_tier: Dictionary = RecipeBookData.build_from_world(world)
	if recipes_by_tier.is_empty():
		return false
	set_all_recipes(recipes_by_tier)
	return true


func open_recipe_book() -> void:
	open()


func close_recipe_book() -> void:
	close()


func is_open() -> bool:
	return visible


# --- Public API -------------------------------------------------------------

func open(tier: int = -1) -> void:
	if _tier_recipes.is_empty():
		refresh_from_world()
	visible = true
	_fit_window_to_screen()
	var target_tier: int = tier if tier >= 0 else (_current_tier if _current_tier >= 0 else start_tier)
	select_tier(target_tier)
	if play_open_animation and window != null:
		_play_open_animation()


func close() -> void:
	visible = false
	closed.emit()


func set_tier_range(new_first_tier: int, new_tier_count: int) -> void:
	first_tier = new_first_tier
	tier_count = maxi(0, new_tier_count)
	_build_tier_tabs()
	select_tier(clampi(_current_tier, first_tier, first_tier + maxi(1, tier_count) - 1))


## Replace the recipe list of a single tier. Pass an empty array to clear it.
func set_tier_recipes(tier: int, recipes: Array) -> void:
	if recipes.is_empty():
		_tier_recipes.erase(tier)
	else:
		_tier_recipes[tier] = recipes.duplicate()
	if tier == _current_tier:
		_refresh_grid()


## Replace every tier at once: {tier_int: Array[Dictionary]}.
func set_all_recipes(recipes_by_tier: Dictionary) -> void:
	_tier_recipes.clear()
	for tier_key in recipes_by_tier.keys():
		var recipes: Array = recipes_by_tier[tier_key]
		if recipes.is_empty():
			continue
		_tier_recipes[int(tier_key)] = recipes.duplicate()

	if auto_tier_range and not _tier_recipes.is_empty():
		var tiers: Array = _tier_recipes.keys()
		tiers.sort()
		var lowest: int = int(tiers[0])
		var highest: int = int(tiers[tiers.size() - 1])
		first_tier = lowest
		tier_count = maxi(1, highest - lowest + 1)
		start_tier = clampi(start_tier, first_tier, highest)
		_build_tier_tabs()

	_selected_recipe_id = ""
	if _current_tier < first_tier or _current_tier > first_tier + tier_count - 1:
		_current_tier = -1
		select_tier(start_tier)
	else:
		_clear_detail()
		_refresh_grid()


func get_current_tier() -> int:
	return _current_tier


func get_selected_recipe_id() -> String:
	return _selected_recipe_id


func get_active_categories() -> PackedStringArray:
	var active := PackedStringArray()
	for box in _filter_boxes:
		if is_instance_valid(box) and box.button_pressed:
			active.append(str(box.get_meta(CATEGORY_META, box.name)))
	return active


func select_tier(tier: int) -> void:
	if tier_count <= 0:
		return
	var clamped: int = clampi(tier, first_tier, first_tier + tier_count - 1)
	if clamped == _current_tier:
		_sync_tier_button_state()
		return
	_current_tier = clamped
	_sync_tier_button_state()
	_selected_recipe_id = ""
	_clear_detail()
	_refresh_grid()
	tier_changed.emit(_current_tier)


func select_recipe(recipe_id: String) -> void:
	var recipe: Dictionary = _find_recipe(_current_tier, recipe_id)
	if recipe.is_empty():
		clear_selection()
		return
	_selected_recipe_id = recipe_id
	_sync_slot_selection()
	_show_detail(recipe)
	recipe_selected.emit(_current_tier, recipe_id)


func clear_selection() -> void:
	if _selected_recipe_id == "":
		_clear_detail()
		return
	_selected_recipe_id = ""
	_sync_slot_selection()
	_clear_detail()
	recipe_deselected.emit()


# --- Tier tabs --------------------------------------------------------------

func _build_tier_tabs() -> void:
	if tier_tabs == null or tier_tab_template == null:
		return

	_tier_buttons.clear()
	var tabs: Array[Button] = []
	for child in tier_tabs.get_children():
		if child is Button and child != tier_tab_template:
			tabs.append(child as Button)

	for index in range(tier_count):
		var tier: int = first_tier + index
		var tab: Button
		if index < tabs.size():
			tab = tabs[index]
		else:
			tab = tier_tab_template.duplicate() as Button
			tier_tabs.add_child(tab)
			tabs.append(tab)
		tab.name = "TierTab_%d" % tier
		tab.text = tier_tab_format % tier
		tab.visible = true
		tab.disabled = false
		tab.focus_mode = Control.FOCUS_NONE
		tab.mouse_filter = Control.MOUSE_FILTER_PASS
		tab.set_meta(&"tier", tier)
		var callback := Callable(self, "_on_tier_tab_pressed").bind(tier)
		if not tab.pressed.is_connected(callback):
			tab.pressed.connect(callback)
		_tier_buttons[tier] = tab

	for extra_index in range(tier_count, tabs.size()):
		tabs[extra_index].visible = false

	_sync_tier_button_state()


func _sync_tier_button_state() -> void:
	for tier_key in _tier_buttons.keys():
		var tab: Button = _tier_buttons[tier_key] as Button
		if tab == null or not is_instance_valid(tab):
			continue
		tab.set_pressed_no_signal(int(tier_key) == _current_tier)


func _on_tier_tab_pressed(tier: int) -> void:
	select_tier(tier)


# --- Recipe grid ------------------------------------------------------------

func _refresh_grid() -> void:
	if recipe_grid == null or slot_template == null:
		return

	recipe_grid.columns = maxi(1, slot_columns)
	_visible_recipes = _filtered_recipes(_current_tier)

	var slot_count: int = _visible_recipes.size()
	var is_placeholder: bool = slot_count == 0
	if is_placeholder:
		slot_count = maxi(0, placeholder_slot_count)

	while _slot_pool.size() < slot_count:
		var new_slot: Button = slot_template.duplicate() as Button
		new_slot.name = "Slot_%d" % _slot_pool.size()
		new_slot.focus_mode = Control.FOCUS_NONE
		new_slot.mouse_filter = Control.MOUSE_FILTER_PASS
		new_slot.set_meta(SLOT_INDEX_META, _slot_pool.size())
		new_slot.pressed.connect(_on_slot_pressed.bind(new_slot))
		recipe_grid.add_child(new_slot)
		_slot_pool.append(new_slot)

	for index in range(_slot_pool.size()):
		var slot: Button = _slot_pool[index]
		if index >= slot_count:
			slot.visible = false
			continue
		slot.visible = true
		if is_placeholder:
			_apply_slot_data(slot, {})
		else:
			_apply_slot_data(slot, _visible_recipes[index])

	_update_found_label()


func _apply_slot_data(slot: Button, recipe: Dictionary) -> void:
	var recipe_id: String = str(recipe.get("id", ""))
	slot.set_meta(RECIPE_ID_META, recipe_id)
	slot.disabled = recipe_id == ""
	slot.set_pressed_no_signal(recipe_id != "" and recipe_id == _selected_recipe_id)
	slot.tooltip_text = str(recipe.get("name", ""))

	var icon: TextureRect = slot.get_node_or_null("Icon") as TextureRect
	if icon != null:
		icon.texture = recipe.get("icon", null) as Texture2D
		icon.visible = icon.texture != null

	var selected_frame: CanvasItem = slot.get_node_or_null("SelectedFrame") as CanvasItem
	if selected_frame != null:
		selected_frame.visible = slot.button_pressed

	# Only dim a slot when the data explicitly says the recipe is undiscovered.
	# Without a discovery source every recipe reads as available.
	var locked_overlay: CanvasItem = slot.get_node_or_null("LockedOverlay") as CanvasItem
	if locked_overlay != null:
		locked_overlay.visible = recipe_id != "" and recipe.has("found") and not bool(recipe.get("found", false))


func _on_slot_pressed(slot: Button) -> void:
	var recipe_id: String = str(slot.get_meta(RECIPE_ID_META, ""))
	if recipe_id == "":
		slot.set_pressed_no_signal(false)
		return
	if recipe_id == _selected_recipe_id:
		clear_selection()
		return
	select_recipe(recipe_id)


func _sync_slot_selection() -> void:
	for slot in _slot_pool:
		if not is_instance_valid(slot) or not slot.visible:
			continue
		var is_selected: bool = _selected_recipe_id != "" and str(slot.get_meta(RECIPE_ID_META, "")) == _selected_recipe_id
		slot.set_pressed_no_signal(is_selected)
		var selected_frame: CanvasItem = slot.get_node_or_null("SelectedFrame") as CanvasItem
		if selected_frame != null:
			selected_frame.visible = is_selected


# --- Detail panel -----------------------------------------------------------

func _show_detail(recipe: Dictionary) -> void:
	if detail_panel != null:
		detail_panel.visible = true
	if detail_title != null:
		detail_title.text = str(recipe.get("name", recipe.get("id", "")))
	if detail_description != null:
		detail_description.text = str(recipe.get("description", ""))
	if preview_icon != null:
		preview_icon.texture = recipe.get("icon", null) as Texture2D
		preview_icon.visible = preview_icon.texture != null

	var ingredients: Array = recipe.get("ingredients", []) as Array
	var used_for: Array = recipe.get("used_for", []) as Array
	_fill_mini_grid(ingredients_grid, _ingredient_pool, ingredients)
	_fill_mini_grid(used_for_grid, _used_for_pool, used_for)
	if ingredients_label != null:
		ingredients_label.visible = not ingredients.is_empty()
	if ingredients_grid != null:
		ingredients_grid.visible = not ingredients.is_empty()
	if used_for_label != null:
		used_for_label.visible = not used_for.is_empty()
	if used_for_grid != null:
		used_for_grid.visible = not used_for.is_empty()


func _clear_detail() -> void:
	if detail_title != null:
		detail_title.text = empty_detail_title
	if detail_description != null:
		detail_description.text = empty_detail_text
	if preview_icon != null:
		preview_icon.texture = null
		preview_icon.visible = false
	_fill_mini_grid(ingredients_grid, _ingredient_pool, [])
	_fill_mini_grid(used_for_grid, _used_for_pool, [])
	if ingredients_label != null:
		ingredients_label.visible = false
	if ingredients_grid != null:
		ingredients_grid.visible = false
	if used_for_label != null:
		used_for_label.visible = false
	if used_for_grid != null:
		used_for_grid.visible = false


func _fill_mini_grid(grid: GridContainer, pool: Array[Button], entries: Array) -> void:
	if grid == null:
		return
	var template: Button = _mini_template(grid)
	if template == null:
		return

	while pool.size() < entries.size():
		var new_mini: Button = template.duplicate() as Button
		new_mini.name = "%s_%d" % [grid.name, pool.size()]
		new_mini.disabled = true
		new_mini.focus_mode = Control.FOCUS_NONE
		new_mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(new_mini)
		pool.append(new_mini)

	for index in range(pool.size()):
		var mini_button: Button = pool[index]
		if index >= entries.size():
			mini_button.visible = false
			continue
		mini_button.visible = true
		var entry: Dictionary = entries[index] as Dictionary
		var icon: TextureRect = mini_button.get_node_or_null("Icon") as TextureRect
		if icon != null:
			icon.texture = entry.get("icon", null) as Texture2D
			icon.visible = icon.texture != null
		var count_label: Label = mini_button.get_node_or_null("Count") as Label
		if count_label != null:
			var count: int = int(entry.get("count", 0))
			count_label.text = "" if count <= 1 else str(count)
			count_label.visible = count > 1
		mini_button.tooltip_text = str(entry.get("name", entry.get("id", "")))


func _mini_template(grid: GridContainer) -> Button:
	if grid == null:
		return null
	return grid.get_node_or_null("MiniSlotTemplate") as Button


# --- Filters ----------------------------------------------------------------

func _collect_filter_boxes() -> void:
	_filter_boxes.clear()
	if filters_box == null:
		return
	for child in filters_box.get_children():
		if not (child is CheckBox):
			continue
		var box: CheckBox = child as CheckBox
		if not box.has_meta(CATEGORY_META):
			box.set_meta(CATEGORY_META, String(box.name).to_snake_case().replace("filter_", ""))
		box.focus_mode = Control.FOCUS_NONE
		if not box.toggled.is_connected(_on_filter_toggled):
			box.toggled.connect(_on_filter_toggled)
		_filter_boxes.append(box)


func _on_filter_toggled(_pressed: bool) -> void:
	_selected_recipe_id = ""
	_clear_detail()
	_refresh_grid()
	filters_changed.emit(get_active_categories())


func _filtered_recipes(tier: int) -> Array:
	var recipes: Array = _tier_recipes.get(tier, []) as Array
	if recipes.is_empty():
		return []

	var active: PackedStringArray = get_active_categories()
	if active.is_empty() or _filter_boxes.is_empty():
		return recipes.duplicate()

	var filtered: Array = []
	for entry in recipes:
		var recipe: Dictionary = entry as Dictionary
		var category: String = str(recipe.get("category", ""))
		if category == "" or active.has(category):
			filtered.append(recipe)
	return filtered


# --- Helpers ----------------------------------------------------------------

func _find_recipe(tier: int, recipe_id: String) -> Dictionary:
	var recipes: Array = _tier_recipes.get(tier, []) as Array
	for entry in recipes:
		var recipe: Dictionary = entry as Dictionary
		if str(recipe.get("id", "")) == recipe_id:
			return recipe
	return {}


func _update_found_label() -> void:
	if found_label == null:
		return

	var total: int = _visible_recipes.size()
	if total == 0:
		found_label.text = total_format % [_current_tier, maxi(0, placeholder_slot_count)]
		return

	var tracked: int = 0
	var found: int = 0
	for entry in _visible_recipes:
		var recipe: Dictionary = entry as Dictionary
		if not recipe.has("found"):
			continue
		tracked += 1
		if bool(recipe.get("found", false)):
			found += 1

	if tracked == 0:
		# No discovery source is wired, so report the count instead of faking
		# progress the client cannot know.
		found_label.text = total_format % [_current_tier, total]
		return
	found_label.text = found_format % [_current_tier, found, total]


func _hide_template(node: Control) -> void:
	if node == null:
		return
	# Hidden templates are skipped by their container's layout and never receive
	# input, so they cost nothing but stay editable/skinnable in the editor.
	node.visible = false


func _on_close_pressed() -> void:
	close()


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_close_pressed()
	elif event is InputEventScreenTouch and event.pressed:
		_on_close_pressed()


func _fit_window_to_screen() -> void:
	if window == null:
		return
	var screen_size: Vector2 = get_viewport_rect().size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return
	var available := Vector2(
		maxf(1.0, screen_size.x - WINDOW_SCREEN_MARGIN.x),
		maxf(1.0, screen_size.y - WINDOW_SCREEN_MARGIN.y)
	)
	_window_fit_scale = clampf(
		minf(available.x / WINDOW_BASE_SIZE.x, available.y / WINDOW_BASE_SIZE.y),
		MIN_WINDOW_SCALE,
		1.0
	)
	window.pivot_offset = window.size * 0.5
	window.scale = Vector2.ONE * _window_fit_scale


func _play_open_animation() -> void:
	var target_scale := Vector2.ONE * _window_fit_scale
	window.pivot_offset = window.size * 0.5
	window.scale = target_scale * 0.96
	window.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween := window.create_tween()
	tween.set_parallel(true)
	tween.tween_property(window, "scale", target_scale, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(window, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
