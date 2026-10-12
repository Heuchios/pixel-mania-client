extends Node
## Ephemeral presence only; never changes actions, permissions or trade state.
const AFK_SECONDS := 60.0
const ATLAS = preload("res://Assets/ui/UI_3.0.png")
const CELLS := {"edit": 10, "afk": 13, "shop": 16, "trade": 19}
const EDIT_PANELS := ["is_world_lock_ui_open", "is_area_lock_ui_open", "is_door_editor_open", "is_password_door_entry_open", "is_vending_open", "is_safe_open", "is_donation_box_open", "is_mailbox_open", "is_bulletin_board_open", "is_display_open", "is_fish_monger_open", "is_cctv_open", "is_oil_refinery_open", "is_battery_charger_open", "is_generator_open", "is_crafting_open", "is_furnace_open", "is_sign_open", "is_magnet_machine_open", "is_quest_board_open", "is_theme_machine_confirm_open"]
static var shared_frames: SpriteFrames
var world
var idle_seconds := 0.0
var last_position := Vector2(INF, INF)
var last_world := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

static func add_animations(base: SpriteFrames) -> SpriteFrames:
	if shared_frames != null:
		return shared_frames
	shared_frames = base.duplicate()
	for activity in CELLS:
		shared_frames.add_animation(activity)
		shared_frames.set_animation_loop(activity, true)
		shared_frames.set_animation_speed(activity, 3.0)
		for frame in 3:
			var texture := AtlasTexture.new()
			texture.atlas = ATLAS
			texture.region = Rect2((CELLS[activity] + frame) * 32, 64, 32, 32)
			shared_frames.add_frame(activity, texture)
	return shared_frames

func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventJoypadButton:
		idle_seconds = 0.0
	elif event is InputEventMouseMotion and event.relative.length_squared() > 0:
		idle_seconds = 0.0
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.2:
		idle_seconds = 0.0

func _process(delta: float) -> void:
	if not is_instance_valid(world) or world.get("in_world") != true:
		idle_seconds = 0.0
		last_position = Vector2(INF, INF)
		if is_instance_valid(world) and is_instance_valid(world.get("player")):
			world.player.set_meta("activity_bubble", "")
		return
	var actor = world.get("player")
	if not is_instance_valid(actor):
		return
	var world_name := str(world.get("current_world_name"))
	if world_name != last_world or not last_position.is_finite() or actor.global_position.distance_squared_to(last_position) > 0.01:
		idle_seconds = 0.0
	else:
		idle_seconds += maxf(delta, 0.0)
	last_world = world_name
	last_position = actor.global_position
	actor.set_meta("activity_bubble", resolve_activity())

func resolve_activity() -> String:
	if idle_seconds >= AFK_SECONDS:
		return "afk"
	if panel_open("is_trade_open"):
		return "trade"
	if panel_open("is_shop_open"):
		return "shop"
	for method in EDIT_PANELS:
		if panel_open(method):
			return "edit"
	return ""

func panel_open(method: String) -> bool:
	return is_instance_valid(world) and world.has_method(method) and bool(world.call(method))
