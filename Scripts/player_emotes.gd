extends Node
## Short cosmetic gestures; movement, inventory and health stay authoritative.
const DURATIONS := {"wave": 2.4, "laugh": 2.6, "sad": 3.0}
const COOLDOWN_MSEC := 1000
const INTERRUPT_STATES := ["walk", "run", "jump", "fall", "punch", "place_animation", "hurt", "dead", "dead_spirit"]
var actor: Node2D
var emote_id := ""
var elapsed := 0.0
var poses: Array[Dictionary] = []

static func play(actor_node: Node2D, id: String) -> bool:
	if not is_instance_valid(actor_node) or not DURATIONS.has(id): return false
	var controller = actor_node.get_node_or_null("PlayerEmotes")
	if controller == null:
		controller = load("res://Scripts/player_emotes.gd").new()
		controller.name = "PlayerEmotes"
		controller.actor = actor_node
		actor_node.add_child(controller)
	controller.start(id)
	return true

static func cancel(actor_node: Node) -> void:
	if not is_instance_valid(actor_node): return
	var controller = actor_node.get_node_or_null("PlayerEmotes")
	if controller != null: controller.stop()

static func active_face(actor_node: Node, movement_state: String) -> String:
	if not is_instance_valid(actor_node): return ""
	if INTERRUPT_STATES.has(movement_state):
		cancel(actor_node)
		return ""
	if int(actor_node.get_meta("player_emote_until_msec", 0)) <= Time.get_ticks_msec(): return ""
	var id := str(actor_node.get_meta("player_emote_id", ""))
	return id if DURATIONS.has(id) else ""

func _ready() -> void:
	process_priority = 100
	set_process(false)

func start(id: String) -> void:
	stop()
	emote_id = id
	elapsed = 0.0
	actor.set_meta("player_emote_id", id)
	actor.set_meta("player_emote_until_msec", Time.get_ticks_msec() + int(DURATIONS[id] * 1000.0))
	for path in ["PlayerVisual/RightArm", "PlayerVisual/HandItem", "PlayerVisual/Head", "PlayerVisual/Body"]:
		var part := actor.get_node_or_null(path) as Node2D
		if part != null: poses.append({"node": part, "position": part.position, "rotation": part.rotation, "z_index": part.z_index})
	set_process(true)

func stop() -> void:
	for pose in poses:
		if is_instance_valid(pose.node):
			pose.node.position = pose.position
			pose.node.rotation = pose.rotation
			pose.node.z_index = pose.z_index
	poses.clear()
	if is_instance_valid(actor):
		actor.set_meta("player_emote_id", "")
		actor.set_meta("player_emote_until_msec", 0)
	emote_id = ""
	set_process(false)

func _process(delta: float) -> void:
	if not is_instance_valid(actor) or emote_id == "":
		stop()
		return
	elapsed += delta
	var state := str(actor.get_meta("animation_state", "idle"))
	var forced_face := str(actor.get_meta("face_expression_override", ""))
	var moving: bool = actor is CharacterBody2D and (actor.velocity.length() > 6.0 or not actor.is_on_floor())
	if elapsed >= float(DURATIONS[emote_id]) or moving or INTERRUPT_STATES.has(state) or forced_face in ["hurt", "dead", "dead_spirit"] or int(actor.get_meta("face_hurt_until_msec", 0)) > Time.get_ticks_msec() or int(actor.get_meta("face_punch_until_msec", 0)) > Time.get_ticks_msec() or not actor.is_visible_in_tree():
		stop()
		return
	# The body-part parents also carry equipped sleeves, hair and hats.
	var envelope := minf(1.0, elapsed / 0.15) * minf(1.0, (float(DURATIONS[emote_id]) - elapsed) / 0.2)
	for pose in poses:
		var part: Node2D = pose.node
		var offset := Vector2.ZERO
		var turn := 0.0
		if emote_id == "wave" and part.name in [&"RightArm", &"HandItem"]:
			# Swing the near arm forward toward the face. PlayerVisual mirrors it when facing left.
			var shoulder := Vector2(-6, 2)
			var wave_angle := (-2.3 + sin(elapsed * TAU * 2.5) * 0.35) * envelope
			part.position = shoulder + (Vector2(pose.position) - shoulder).rotated(wave_angle)
			part.rotation = float(pose.rotation) + wave_angle
			continue
		elif emote_id == "laugh" and part.name in [&"Head", &"Body"]:
			offset.y = -absf(sin(elapsed * TAU * 2.25)) * (2.0 if part.name == &"Head" else 1.0)
		elif emote_id == "sad" and part.name == &"Head":
			offset.y = 2.0
			turn = 0.08
		part.position = pose.position + offset * envelope
		part.rotation = float(pose.rotation) + turn * envelope
