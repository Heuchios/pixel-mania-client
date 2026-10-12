extends Node
## Cosmetic gestures; movement, inventory and health stay authoritative.
## A zero duration loops until interrupted.
const DURATIONS := {"wave": 2.4, "laugh": 2.6, "sad": 3.0, "dance": 0.0}
const COMMANDS := {"wave": "wave", "lol": "laugh", "sad": "sad", "dance": "dance"}
const DANCE_LIBRARY = preload("res://Assets/player/animations/dance.tres")
const COOLDOWN_MSEC := 1000
const INTERRUPT_STATES := ["walk", "run", "jump", "fall", "punch", "place_animation", "hurt", "dead", "dead_spirit"]
var actor: Node2D
var emote_id := ""
var elapsed := 0.0
var poses: Array[Dictionary] = []
var dance_player: AnimationPlayer

static func face_for_emote(id: String) -> String:
	return "wave" if id == "dance" else id

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

static func restore_cloned_visual(source_actor: Node, visual_clone: Node) -> void:
	# New remote avatars copy the local rig; do not copy a temporary gesture pose.
	var controller = source_actor.get_node_or_null("PlayerEmotes")
	var source_visual = source_actor.get_node_or_null("PlayerVisual")
	if controller == null or source_visual == null: return
	for pose in controller.poses:
		var part = visual_clone.get_node_or_null(source_visual.get_path_to(pose.node))
		if part is Node2D:
			part.position = pose.position
			part.rotation = pose.rotation
			part.z_index = pose.z_index

static func active_face(actor_node: Node, movement_state: String) -> String:
	if not is_instance_valid(actor_node): return ""
	if INTERRUPT_STATES.has(movement_state):
		cancel(actor_node)
		return ""
	var id := str(actor_node.get_meta("player_emote_id", ""))
	if not DURATIONS.has(id): return ""
	if float(DURATIONS[id]) > 0.0 and int(actor_node.get_meta("player_emote_until_msec", 0)) <= Time.get_ticks_msec(): return ""
	return face_for_emote(id)

func _ready() -> void:
	process_priority = 100
	set_process(false)

func start(id: String) -> void:
	stop()
	emote_id = id
	elapsed = 0.0
	actor.set_meta("player_emote_id", id)
	var duration := float(DURATIONS[id])
	actor.set_meta("player_emote_until_msec", Time.get_ticks_msec() + int(duration * 1000.0) if duration > 0.0 else 0)
	var parts := ["RightArm", "HandItem", "Head", "Body"]
	if id == "dance": parts.append_array(["LeftArm", "LeftFoot", "RightFoot", "Bottom", "BackSlot"])
	for part_name in parts:
		var path: String = "PlayerVisual/" + part_name
		var part := actor.get_node_or_null(path) as Node2D
		if part != null: poses.append({"node": part, "position": part.position, "rotation": part.rotation, "z_index": part.z_index})
	if id == "dance":
		dance_player = actor.get_node_or_null("EmoteAnimationPlayer") as AnimationPlayer
		if dance_player == null:
			dance_player = AnimationPlayer.new()
			dance_player.name = "EmoteAnimationPlayer"
			dance_player.add_animation_library("", DANCE_LIBRARY)
			actor.add_child(dance_player)
		# Sample after locomotion each frame, so idle cannot overwrite the gesture.
		dance_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		dance_player.play("dance")
	set_process(true)

func stop() -> void:
	# stop() without keep_state reapplies the first dance frame, including on
	# repeated cancellation after the saved poses have already been restored.
	if emote_id == "dance" and is_instance_valid(dance_player): dance_player.stop(true)
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
	var duration := float(DURATIONS[emote_id])
	var timed_out := duration > 0.0 and elapsed >= duration
	if timed_out or moving or INTERRUPT_STATES.has(state) or forced_face in ["hurt", "dead", "dead_spirit"] or int(actor.get_meta("face_hurt_until_msec", 0)) > Time.get_ticks_msec() or int(actor.get_meta("face_punch_until_msec", 0)) > Time.get_ticks_msec() or (duration > 0.0 and not actor.is_visible_in_tree()):
		stop()
		return
	# Camera culling must not end a remote dance. Keep checking interruptions,
	# but only sample the animation while the actor is visible.
	if not actor.is_visible_in_tree(): return
	# The body-part parents also carry equipped sleeves, hair and hats.
	var envelope := minf(1.0, elapsed / 0.15)
	if duration > 0.0: envelope *= minf(1.0, (duration - elapsed) / 0.2)
	if emote_id == "dance":
		dance_player.seek(fmod(elapsed, dance_player.get_animation("dance").length), true)
		for pose in poses:
			var part: Node2D = pose.node
			part.position = Vector2(pose.position).lerp(part.position, envelope)
			part.rotation = lerp_angle(float(pose.rotation), part.rotation, envelope)
		return
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
