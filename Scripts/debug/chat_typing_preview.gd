extends Control
## F6: type in either field; Enter/Escape end the offline preview message.
const MANAGER = preload("res://Scripts/player_animation_manager.gd")
const INPUT = preload("res://Scripts/debug/chat_typing_preview_input.gd")
var chat: Control
var actors: Array[Node2D] = []
var managers: Array[Node] = []
var status: Label

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_meta("ignore_mobile_ui_scale", true)
	var background := ColorRect.new()
	background.color = Color("101a39")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	label("CHAT TYPING", Vector2(60, 40), 34)
	label("Type below to animate the dots. Enter or Escape stops them.", Vector2(60, 100), 22)
	label("The bubble follows the face in either direction.", Vector2(60, 145), 22)
	var template: Node = load("res://Scenes/player/netfox_player.tscn").instantiate()
	for i in 2:
		var actor := Node2D.new()
		actor.position = Vector2(540 + i * 820, 465)
		actor.scale = Vector2(6, 6)
		var visual := template.get_node("PlayerVisual").duplicate()
		visual.scale.x = 1 if i == 0 else -1
		actor.add_child(visual)
		add_child(actor)
		for sprite in visual.find_children("*", "AnimatedSprite2D", true, false):
			if sprite.sprite_frames != null and sprite.sprite_frames.has_animation("idle"):
				sprite.play("idle")
		var manager := MANAGER.new()
		manager.player = actor
		manager.player_visual = visual
		manager.face_expression_animated = visual.get_node("Head/FaceExpressionAnimated")
		actor.add_child(manager)
		actors.append(actor)
		managers.append(manager)
		label("FACING RIGHT" if i == 0 else "FACING LEFT", Vector2(410 + i * 820, 540), 24)
	template.free()
	chat = INPUT.new()
	add_child(chat)
	for i in 2:
		var field := LineEdit.new()
		field.position = Vector2(330 + i * 820, 635)
		field.size = Vector2(470, 60)
		field.placeholder_text = "Main chat" if i == 0 else "Quick chat"
		field.add_theme_font_size_override("font_size", 24)
		chat.add_child(field)
		if i == 0: chat.chat_input = field
		else: chat.quick_chat_input = field
		chat.wire_chat_input_activity(field)
		field.text_submitted.connect(chat.finish_preview_message)
	status = label("Start typing in either chat field.", Vector2(60, 750), 24)
	label("UI_3.0.png  |  atlas (7, 2) > (8, 2) > (9, 2)", Vector2(60, 845), 22)
	var indicator: AnimatedSprite2D = load("res://Scenes/player/chat_typing_indicator.tscn").instantiate()
	var frames := indicator.sprite_frames
	indicator.free()
	for i in 3:
		var tile := TextureRect.new()
		tile.texture = frames.get_frame_texture("typing", i)
		tile.position = Vector2(70 + i * 140, 895)
		tile.size = Vector2(96, 96)
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tile)

func label(text: String, pos: Vector2, font_size: int) -> Label:
	var result := Label.new()
	result.text = text
	result.position = pos
	result.set_meta("pixelmania_font_role", "preserve")
	result.add_theme_font_override("font", preload("res://Assets/font/font.ttf"))
	result.add_theme_font_size_override("font_size", font_size)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(result)
	return result

func _process(_delta: float) -> void:
	if chat == null: return
	var typing: bool = chat.is_chat_typing()
	for i in actors.size():
		actors[i].set_meta("remote_chat_typing", typing)
		managers[i].update_face_expression_animation("idle")
	status.text = "Typing..." if typing else "Waiting for chat input."
