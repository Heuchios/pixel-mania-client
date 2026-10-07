extends Control
## F6: test the real dropdown and assembled avatar without signing into a world.
const EMOTES = preload("res://Scripts/player_emotes.gd")
const FACE_MANAGER = preload("res://Scripts/player_animation_manager.gd")
var actors: Array[Node2D] = []
var managers: Array[Node] = []
var repeat_timer := 0.0
var interactive: Node2D
var menu: Control
var status: Label
var hud_icons: Array[Control] = []

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_meta("ignore_mobile_ui_scale", true)
	var bg := ColorRect.new()
	bg.color = Color("101a39")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	add_label("PLAYER EMOTES", Vector2(60, 35), 36)
	add_label("Wave, laugh or look sad using the original sprite sheet.", Vector2(60, 95), 22)
	var template: Node = load("res://Scenes/player/netfox_player.tscn").instantiate()
	for i in 4:
		var actor := Node2D.new()
		actor.position = Vector2(230 + i * 400, 440)
		actor.scale = Vector2(5, 5)
		var visual := template.get_node("PlayerVisual").duplicate()
		actor.add_child(visual)
		add_child(actor)
		var manager := FACE_MANAGER.new()
		actor.add_child(manager)
		manager.player = actor
		manager.player_visual = visual
		manager.face_expression_animated = visual.get_node("Head/FaceExpressionAnimated")
		# Keep the authored idle frames, positions and equipment attachment parents.
		for sprite in visual.find_children("*", "AnimatedSprite2D", true, false):
			if sprite.sprite_frames != null and sprite.sprite_frames.has_animation("idle"): sprite.play("idle")
		actors.append(actor)
		managers.append(manager)
		add_label(["WAVE", "LAUGH", "SAD", "TRY IT"][i], Vector2(170 + i * 400, 510), 27)
	template.free()
	interactive = actors[3]
	status = add_label("Click the smile button beneath chat.", Vector2(60, 650), 24)
	add_label("Gestures end automatically. In-game movement and damage cancel them.", Vector2(60, 695), 20)
	add_label("Atlas reference: Assets/player/expressions/emotes.png", Vector2(60, 790), 20)
	var sheet := TextureRect.new()
	sheet.texture = preload("res://Assets/player/expressions/emotes.png")
	sheet.position = Vector2(60, 835)
	sheet.size = Vector2(512, 256)
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sheet)
	for i in 3:
		var icon := TextureRect.new()
		icon.texture = load("res://Assets/ui/icons/%s.png" % ["lobby", "shop", "message"][i])
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size = Vector2(64, 64)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(icon)
		hud_icons.append(icon)
		MobileUIScale.layout_corner_button(icon, i, get_viewport_rect().size)
	menu = preload("res://Scenes/ui/emotes/EmotesScene.tscn").instantiate()
	add_child(menu)
	menu.emote_selected.connect(_selected)
	menu.set_emotes_panel_open(true)
	loop_examples()

func add_label(text: String, pos: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.set_meta("pixelmania_font_role", "preserve")
	label.add_theme_font_override("font", preload("res://Assets/font/font.ttf"))
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func loop_examples() -> void:
	for i in 3: EMOTES.play(actors[i], ["wave", "laugh", "sad"][i])

func _selected(id: String) -> void:
	EMOTES.play(interactive, id)
	status.text = "You selected %s." % id.capitalize()

func _process(delta: float) -> void:
	for i in hud_icons.size():
		MobileUIScale.layout_corner_button(hud_icons[i], i, get_viewport_rect().size)
	repeat_timer += delta
	if repeat_timer > 3.5:
		repeat_timer = 0.0
		loop_examples()
	for manager in managers: manager.update_face_expression_animation("idle")
