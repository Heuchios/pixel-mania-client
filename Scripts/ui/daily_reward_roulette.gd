extends Control
## Cosmetic roulette: the server's saved reward selects the destination pocket.

signal pocket_tick

const Style = preload("res://Scripts/ui/pixel_ui_style.gd")
const LAMP_SHADER = preload("res://Assets/shaders/daily_roulette_lamp.gdshader")
const LAMP_COUNT := 48
const GEM_TEXTURES = [preload("res://Assets/currency/medium_gem.png"), preload("res://Assets/currency/large_gem.png"), preload("res://Assets/currency/huge_gem.png")]
const TOP := -PI * 0.5
const POCKET_COUNT := 12
const STEP := TAU / POCKET_COUNT
const SPIN_DURATION := 6.4
const WINDUP_END := 0.065
const CATCH_AT := 0.84
const STOP_AT := 0.965
const WINDUP_ANGLE := 0.16
const GOLD := Color("ffda79")
const INK := Color("281336")
const FILLS := [Color("4b285c"), Color("27215b"), Color("66311d")]
const EDGES := [Color("cfa8e2"), Color("768bff"), Color("ffc647")]

var pockets: Array[Dictionary] = []
var angle := 0.0
var ball_angle := TOP
var ball_radius := 156.0
var ball_visible := false
var spinning := false
var selected := -1
var winner_index := -1
var elapsed := 0.0
var progress := 0.0
var pointer_kick := 0.0
var landing_flash := 0.0
var win_age := -1.0
var pointer_age := 1.0
var motion_energy := 0.0
var ball_lift := 0.0
var catch_wheel_angle := 0.0
var animation_stage := "idle"
var last_tick := -1
var last_tick_time := -1.0
var start_angle := 0.0
var target_angle := 0.0
var ball_start := TOP
var ball_target := TOP
var rng := RandomNumberGenerator.new()
var lamp_mesh: MultiMesh
var lamp_layer: MultiMeshInstance2D
var lamp_material: ShaderMaterial
var lamp_tint := Color.TRANSPARENT
var foreground: Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rng.randomize()
	_setup_lamps()
	foreground = Control.new()
	foreground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(foreground)
	foreground.draw.connect(_draw_foreground)
	resized.connect(_redraw_wheel)
	visibility_changed.connect(_sync_processing)
	_sync_processing()

func _setup_lamps() -> void:
	lamp_mesh = MultiMesh.new()
	lamp_mesh.transform_format = MultiMesh.TRANSFORM_2D
	lamp_mesh.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2(16, 16)
	lamp_mesh.mesh = quad
	lamp_mesh.instance_count = LAMP_COUNT
	lamp_mesh.custom_aabb = AABB(Vector3(-177, -177, -1), Vector3(354, 354, 2))
	for i in range(LAMP_COUNT):
		var point := (Vector2.from_angle(TOP + i * TAU / LAMP_COUNT) * 169.0).round()
		lamp_mesh.set_instance_transform_2d(i, Transform2D(0.0, point))
	lamp_material = ShaderMaterial.new()
	lamp_material.shader = LAMP_SHADER
	lamp_layer = MultiMeshInstance2D.new()
	lamp_layer.multimesh = lamp_mesh
	lamp_layer.material = lamp_material
	lamp_layer.position = size * 0.5
	add_child(lamp_layer)
	_update_lamps()

func _update_lamps() -> void:
	if lamp_mesh == null: return
	var tint := _lamp_color()
	if tint != lamp_tint:
		lamp_tint = tint
		lamp_material.set_shader_parameter("lamp_color", tint)
	for i in range(LAMP_COUNT):
		lamp_mesh.set_instance_custom_data(i, Color(lamp_strength(i), 0, 0, 1))

func _redraw_wheel() -> void:
	queue_redraw()
	if foreground != null: foreground.queue_redraw()
	if lamp_layer != null: lamp_layer.position = size * 0.5

func _sync_processing() -> void:
	set_process(is_visible_in_tree())

func configure(rewards: Array) -> void:
	spinning = false
	animation_stage = "idle"
	win_age = -1.0
	landing_flash = 0.0
	motion_energy = 0.0
	ball_lift = 0.0
	selected = -1
	winner_index = -1
	ball_visible = false
	pockets.clear()
	if rewards.is_empty():
		_redraw_wheel()
		_update_lamps()
		return
	# Decorative pockets are a prize preview, never an odds table or a local roll.
	for tier in [0, 0, 1, 0, 0, 1, 0, 0, 2, 0, 1, 0]:
		pockets.append(rewards[mini(tier, rewards.size() - 1)].duplicate(true))
	angle = STEP * 0.15
	_redraw_wheel()
	_update_lamps()

func show_saved_reward(reward: Dictionary) -> void:
	var matches := _matching_pockets(reward)
	if matches.is_empty(): return
	winner_index = matches[0]
	angle = -winner_index * STEP
	ball_angle = TOP
	ball_radius = 137.0
	ball_visible = true
	selected = winner_index
	animation_stage = "saved"
	win_age = -1.0
	_redraw_wheel()
	_update_lamps()

func begin_spin(reward: Dictionary) -> bool:
	var matches := _matching_pockets(reward)
	if matches.is_empty(): return false
	winner_index = matches[rng.randi_range(0, matches.size() - 1)]
	start_angle = fposmod(angle, TAU)
	target_angle = start_angle + TAU * 5.0 + fposmod(-winner_index * STEP - start_angle, TAU)
	ball_start = fposmod(ball_angle - TOP, TAU) + TOP
	catch_wheel_angle = _wheel_angle_at(CATCH_AT)
	var catch_position := TOP + catch_wheel_angle + winner_index * STEP
	ball_target = ball_start - TAU * 6.0 - fposmod(ball_start - catch_position, TAU)
	selected = -1
	last_tick = -1
	last_tick_time = -1.0
	landing_flash = 0.0
	win_age = -1.0
	pointer_age = 1.0
	ball_visible = true
	spinning = true
	set_spin_progress(0.0)
	return true

func _matching_pockets(reward: Dictionary) -> Array[int]:
	var matches: Array[int] = []
	for i in range(pockets.size()):
		if int(pockets[i].get("gems", -1)) == int(reward.get("gems", -2)):
			matches.append(i)
	return matches

static func _coast(t: float, acceleration: float, cruise_end: float) -> float:
	# Smooth acceleration and a longer, visible coast instead of an early near-stop.
	t = clampf(t, 0.0, 1.0)
	var tail := 1.0 - cruise_end
	var area := acceleration * 0.5 + cruise_end - acceleration + tail / 3.0
	if t < acceleration:
		var a := t / acceleration
		return acceleration * (a * a * a - 0.5 * pow(a, 4)) / area
	if t < cruise_end: return (t - acceleration * 0.5) / area
	var u := clampf((t - cruise_end) / tail, 0.0, 1.0)
	return (cruise_end - acceleration * 0.5 + tail * (1.0 - pow(1.0 - u, 3)) / 3.0) / area

func _wheel_angle_at(t: float) -> float:
	if t < WINDUP_END:
		return start_angle - WINDUP_ANGLE * smoothstep(0.0, WINDUP_END, t)
	var released := clampf((t - WINDUP_END) / (STOP_AT - WINDUP_END), 0.0, 1.0)
	return lerpf(start_angle - WINDUP_ANGLE, target_angle, _coast(released, 0.13, 0.31))

func set_spin_progress(value: float) -> void:
	progress = clampf(value, 0.0, 1.0)
	angle = _wheel_angle_at(progress)
	motion_energy = clampf(absf(_wheel_angle_at(progress + 0.001) - _wheel_angle_at(progress - 0.001)) / (0.002 * SPIN_DURATION * 13.0), 0.0, 1.0)
	animation_stage = "windup" if progress < WINDUP_END else ("spin" if progress < 0.56 else ("slowdown" if progress < CATCH_AT else "settling"))
	if progress < CATCH_AT:
		var orbit := clampf((progress - WINDUP_END) / (CATCH_AT - WINDUP_END), 0.0, 1.0)
		ball_angle = lerpf(ball_start, ball_target, _coast(orbit, 0.085, 0.4))
		var drop := smoothstep(0.68, CATCH_AT, progress)
		ball_lift = absf(sin(drop * PI * 3.0)) * (1.0 - drop) * 7.0
		ball_radius = lerpf(156.0, 137.0, drop)
	else:
		# Once caught, the ball rides the confirmed pocket through the last turn.
		var settle := clampf((progress - CATCH_AT) / (1.0 - CATCH_AT), 0.0, 1.0)
		var bounce := sin(settle * PI * 4.0) * pow(1.0 - settle, 2)
		ball_angle = ball_target + angle - catch_wheel_angle + bounce * 0.055
		ball_radius = 137.0 + bounce * 2.0
		ball_lift = absf(bounce) * 4.0
	var tick := floori((angle + STEP * 0.5) / STEP)
	if tick != last_tick and progress >= WINDUP_END:
		last_tick = tick
		pointer_age = 0.0
		# Cap sound and sparkle cadence at speed; individual clicks emerge on slowdown.
		if is_visible_in_tree() and progress - last_tick_time >= 0.012:
			last_tick_time = progress
			pocket_tick.emit()
	_redraw_wheel()

func finish_spin() -> void:
	set_spin_progress(1.0)
	spinning = false
	selected = winner_index
	landing_flash = 1.0
	win_age = 0.0
	animation_stage = "landed"
	_redraw_wheel()
	_update_lamps()

func pointed_index() -> int:
	return posmod(roundi(-angle / STEP), pockets.size()) if not pockets.is_empty() else -1

func _process(delta: float) -> void:
	elapsed += delta
	pointer_age += delta
	pointer_kick = sin(pointer_age * 38.0) * exp(-pointer_age * 16.0)
	if win_age >= 0.0: win_age += delta
	landing_flash = exp(-win_age * 3.0) if win_age >= 0.0 and win_age < 3.0 else 0.0
	_update_lamps()
	# Retain the wheel's canvas commands once motion and the landing flash finish.
	if spinning or (win_age >= 0.0 and win_age < 3.0 + delta):
		_redraw_wheel()
	elif pointer_age < 0.6 + delta and foreground != null:
		foreground.queue_redraw()

func lamp_strength(index: int) -> float:
	var position := index / float(LAMP_COUNT)
	if spinning:
		if progress < WINDUP_END:
			var charge := progress / WINDUP_END
			return 0.12 + 0.88 * smoothstep(position, position + 0.12, charge)
		var head := fposmod(angle / TAU * 0.45, 1.0)
		var counter_head := fposmod(ball_angle / TAU * 0.32 + 0.5, 1.0)
		var chase := maxf(_comet(head - position), 0.8 * _comet(position - counter_head))
		var focus := smoothstep(0.58, 0.94, progress)
		var ball_position := fposmod((ball_angle - TOP) / TAU, 1.0)
		var distance := absf(wrapf(position - ball_position, -0.5, 0.5))
		var crown := exp(-pow(distance / 0.065, 2))
		return 0.1 + 0.9 * lerpf(chase, crown, focus)
	# Keep the marquee moving before a spin and after the saved prize is shown.
	var head := fposmod(elapsed * 0.16, 1.0)
	var first := _comet(head - position)
	var second := _comet(position + head - 0.5)
	var ambient := 0.18 + maxf(first, second) * 0.75
	if selected >= 0:
		var distance := minf(position, 1.0 - position)
		var crown := exp(-pow(distance / 0.07, 2))
		var celebration := 0.0
		if win_age >= 0.0:
			var tier := _tier(pockets[selected])
			var duration := 1.2 + tier * 0.6
			var wave := win_age / 0.85
			if tier == 2: wave = fposmod(wave, 1.0)
			celebration = exp(-pow((distance - wave * 0.5) / 0.075, 2)) * (1.0 - smoothstep(duration * 0.65, duration, win_age))
		return maxf(ambient, clampf(0.12 + crown * (0.58 + sin(elapsed * 2.6) * 0.12) + celebration * 0.9, 0.0, 1.0))
	return ambient

static func _comet(distance: float) -> float:
	# A soft leading edge and long fading tail avoid bulbs snapping on at the head.
	var offset := wrapf(distance, -0.5, 0.5)
	return exp(-maxf(offset, 0.0) * 12.0 - pow(minf(offset, 0.0) / 0.04, 2))

func _lamp_color() -> Color:
	if selected >= 0:
		return [Color("a5ffc3"), Color("acdfff"), GOLD][_tier(pockets[selected])]
	return GOLD

func _tier(reward: Dictionary) -> int:
	var gems := int(reward.get("gems", 0))
	return 2 if gems >= 5000 else (1 if gems >= 1000 else 0)

func _point(center: Vector2, radius: float, radians: float) -> Vector2:
	return center + Vector2.from_angle(radians) * radius

func _disc(center: Vector2, radius: float, color: Color, canvas: CanvasItem = null) -> void:
	if canvas == null: canvas = self
	canvas.draw_circle(center, radius, color, true, -1.0, true)

func _sector(center: Vector2, inner: float, outer: float, from: float, to: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(13): points.append(_point(center, outer, lerpf(from, to, i / 12.0)))
	for i in range(12, -1, -1): points.append(_point(center, inner, lerpf(from, to, i / 12.0)))
	draw_colored_polygon(points, color)

func _text(text: String, point: Vector2, color: Color, font_size: int = Style.DEFAULT_TEXT_FONT_SIZE, canvas: CanvasItem = null) -> void:
	if canvas == null: canvas = self
	var font := Style.get_game_font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline := point + Vector2(-width * 0.5, (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5)
	canvas.draw_string(font, baseline.round(), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw() -> void:
	var center := size * 0.5
	# Every rim, pocket and hub shares this exact center; no snapped or offset rings.
	_disc(center, 186, Color(0.11, 0.05, 0.16, 0.35))
	_disc(center, 182, INK)
	_disc(center, 178, Color("9d5a28"))
	_disc(center, 174, GOLD)
	_disc(center, 164, Color("2e183e"))
	_disc(center, 160, Color("100b20"))
	_disc(center, 149, Color("b17b3e"))
	_disc(center, 146, INK)
	if spinning and motion_energy > 0.03:
		# Short sweeps suggest momentum without smearing the gem art or labels.
		for i in range(3):
			var head := angle * 0.7 + i * TAU / 3.0
			draw_arc(center, 154.0, head - motion_energy * 0.75, head, 18, Color(1.0, 0.84, 0.46, motion_energy * 0.18), 2.0, true)
	for i in range(pockets.size()):
		var tier := _tier(pockets[i])
		var middle := TOP + angle + i * STEP
		var chosen := i == selected
		var fill: Color = FILLS[tier].lightened(0.13 + landing_flash * 0.18) if chosen else FILLS[tier]
		_sector(center, 49, 143, middle - STEP * 0.5 + 0.008, middle + STEP * 0.5 - 0.008, fill)
		_sector(center, 137, 143, middle - STEP * 0.5 + 0.01, middle + STEP * 0.5 - 0.01, GOLD if chosen else EDGES[tier])
		draw_line(_point(center, 53, middle - STEP * 0.5), _point(center, 144, middle - STEP * 0.5), Color("a77491"), 2, true)
		# Identical local placement in every pocket, rotating with the actual wheel.
		draw_set_transform(center, middle - TOP)
		draw_texture_rect(GEM_TEXTURES[tier], Rect2(Vector2(-18, -142), Vector2(36, 36)), false)
		var amount: String = ["250", "1K", "5K"][tier]
		_text(amount, Vector2(0, -96), GOLD if tier == 2 else Color("f5e7fc"))
		draw_set_transform(Vector2.ZERO)
	if selected >= 0:
		var middle := TOP + angle + selected * STEP
		_sector(center, 51, 55, middle - STEP * 0.5, middle + STEP * 0.5, GOLD)
		for edge in [-0.5, 0.5]:
			draw_line(_point(center, 54, middle + STEP * edge), _point(center, 143, middle + STEP * edge), GOLD, 3, true)

func _draw_foreground() -> void:
	var center := size * 0.5
	var hub_scale := 1.0
	if spinning and progress < WINDUP_END:
		hub_scale -= 0.065 * smoothstep(0.0, WINDUP_END, progress)
	elif spinning:
		var launch := (progress - WINDUP_END) * SPIN_DURATION
		hub_scale += -0.065 * cos(launch * 18.0) * exp(-launch * 7.0)
	elif win_age >= 0.0:
		hub_scale += sin(win_age * 13.0) * exp(-win_age * 5.0) * 0.06
	foreground.draw_set_transform(center, 0.0, Vector2.ONE * hub_scale)
	_disc(Vector2.ZERO, 56, Color("110b20"), foreground)
	_disc(Vector2.ZERO, 54, Color("a05c2b"), foreground)
	_disc(Vector2.ZERO, 50, GOLD.lerp(Color.WHITE, landing_flash * 0.3), foreground)
	_disc(Vector2.ZERO, 43, Color("43204f"), foreground)
	_disc(Vector2.ZERO, 36, Color("4e285d"), foreground)
	var landed := win_age >= 0.0 and win_age < 1.8
	_text("YOU" if landed else ("GOOD" if spinning else "DAILY"), Vector2(0, -11), Color("fff0ca"), Style.DEFAULT_TEXT_FONT_SIZE, foreground)
	_text("WIN!" if landed else ("LUCK" if spinning else "SPIN"), Vector2(0, 14), GOLD, Style.DEFAULT_TEXT_FONT_SIZE, foreground)
	foreground.draw_set_transform(Vector2.ZERO)
	if ball_visible:
		if spinning and progress < CATCH_AT:
			for i in range(14, 0, -1):
				var point := _point(center, ball_radius, ball_angle + i * motion_energy * 0.033)
				var alpha := (1.0 - i / 15.0) * motion_energy
				_disc(point, lerpf(1.5, 4.0, alpha), Color(1, 0.9, 0.66, alpha * 0.36), foreground)
		var ball := _point(center, ball_radius, ball_angle)
		_disc(ball + Vector2(2, 3), 8 - ball_lift * 0.3, Color(0.035, 0.025, 0.08, 1.0 - ball_lift * 0.06), foreground)
		ball.y -= ball_lift
		_disc(ball, 10, Color(1.0, 0.88, 0.55, 0.10 + landing_flash * 0.3), foreground)
		_disc(ball, 7, Color("c6af87"), foreground)
		_disc(ball - Vector2(1, 1), 5, Color("fff6da"), foreground)
		foreground.draw_rect(Rect2(ball - Vector2(3, 3), Vector2(3, 3)), Color.WHITE)
	# Spring-loaded pointer stays fixed while the wheel rotates beneath it.
	var pivot := center + Vector2(0, -184)
	var preload_angle := -0.12 * smoothstep(0.0, WINDUP_END, progress) if spinning and progress < WINDUP_END else 0.0
	foreground.draw_set_transform(pivot, preload_angle - pointer_kick * 0.3)
	foreground.draw_colored_polygon(PackedVector2Array([Vector2(-17, -2), Vector2(17, -2), Vector2(14, 15), Vector2(0, 29), Vector2(-14, 15)]), INK)
	foreground.draw_colored_polygon(PackedVector2Array([Vector2(-12, 1), Vector2(12, 1), Vector2(10, 12), Vector2(0, 23), Vector2(-10, 12)]), GOLD)
	foreground.draw_rect(Rect2(-8, 2, 16, 5), Color("fff6d2"))
	foreground.draw_set_transform(Vector2.ZERO)
