extends Control
## Cosmetic roulette: the server's saved reward selects the destination pocket.

signal pocket_tick

const Style = preload("res://Scripts/ui/pixel_ui_style.gd")
const GEM_TEXTURES = [preload("res://Assets/currency/medium_gem.png"), preload("res://Assets/currency/large_gem.png"), preload("res://Assets/currency/huge_gem.png")]
const TOP := -PI * 0.5
const POCKET_COUNT := 12
const STEP := TAU / POCKET_COUNT
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
var last_tick := -1
var last_tick_time := -1.0
var start_angle := 0.0
var target_angle := 0.0
var ball_start := TOP
var ball_target := TOP
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rng.randomize()
	visibility_changed.connect(_sync_processing)
	_sync_processing()

func _sync_processing() -> void:
	set_process(is_visible_in_tree())

func configure(rewards: Array) -> void:
	spinning = false
	selected = -1
	winner_index = -1
	ball_visible = false
	pockets.clear()
	if rewards.is_empty():
		queue_redraw()
		return
	# Decorative pockets are a prize preview, never an odds table or a local roll.
	for tier in [0, 0, 1, 0, 0, 1, 0, 0, 2, 0, 1, 0]:
		pockets.append(rewards[mini(tier, rewards.size() - 1)].duplicate(true))
	angle = STEP * 0.15
	queue_redraw()

func show_saved_reward(reward: Dictionary) -> void:
	var matches := _matching_pockets(reward)
	if matches.is_empty(): return
	winner_index = matches[0]
	angle = -winner_index * STEP
	ball_angle = TOP
	ball_radius = 137.0
	ball_visible = true
	selected = winner_index
	queue_redraw()

func begin_spin(reward: Dictionary) -> bool:
	var matches := _matching_pockets(reward)
	if matches.is_empty(): return false
	winner_index = matches[rng.randi_range(0, matches.size() - 1)]
	start_angle = fposmod(angle, TAU)
	target_angle = start_angle + TAU * 6.0 + fposmod(-winner_index * STEP - start_angle, TAU)
	ball_start = ball_angle
	ball_target = ball_start - TAU * 8.0 - fposmod(ball_start - TOP, TAU)
	selected = -1
	last_tick = -1
	last_tick_time = -1.0
	landing_flash = 0.0
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
	# Integral of a continuous speed curve: accelerate, cruise, then coast to rest.
	var tail := 1.0 - cruise_end
	var area := acceleration * 0.5 + cruise_end - acceleration + tail * 0.25
	if t < acceleration: return t * t / (2.0 * acceleration * area)
	if t < cruise_end: return (t - acceleration * 0.5) / area
	var u := clampf((t - cruise_end) / tail, 0.0, 1.0)
	return (cruise_end - acceleration * 0.5 + tail * (1.0 - pow(1.0 - u, 4)) * 0.25) / area

func set_spin_progress(value: float) -> void:
	progress = clampf(value, 0.0, 1.0)
	angle = lerpf(start_angle, target_angle, _coast(progress, 0.12, 0.38))
	ball_angle = lerpf(ball_start, ball_target, _coast(progress, 0.08, 0.5))
	var drop := smoothstep(0.68, 0.96, progress)
	var bounce := sin(drop * PI * 5.0) * (1.0 - drop) * 5.0
	ball_radius = lerpf(156.0, 137.0, drop) + bounce
	var tick := floori((angle + STEP * 0.5) / STEP)
	if tick != last_tick:
		last_tick = tick
		pointer_kick = 1.0
		# Cap sound and sparkle cadence at speed; individual clicks emerge on slowdown.
		if is_visible_in_tree() and progress - last_tick_time >= 0.012:
			last_tick_time = progress
			pocket_tick.emit()
	queue_redraw()

func finish_spin() -> void:
	set_spin_progress(1.0)
	spinning = false
	selected = winner_index
	landing_flash = 1.0
	queue_redraw()

func pointed_index() -> int:
	return posmod(roundi(-angle / STEP), pockets.size()) if not pockets.is_empty() else -1

func _process(delta: float) -> void:
	elapsed += delta
	pointer_kick = move_toward(pointer_kick, 0.0, delta * 9.0)
	landing_flash = move_toward(landing_flash, 0.0, delta * 1.6)
	queue_redraw()

func _tier(reward: Dictionary) -> int:
	var gems := int(reward.get("gems", 0))
	return 2 if gems >= 5000 else (1 if gems >= 1000 else 0)

func _point(center: Vector2, radius: float, radians: float) -> Vector2:
	return center + Vector2.from_angle(radians) * radius

func _disc(center: Vector2, radius: float, color: Color) -> void:
	draw_circle(center, radius, color, true, -1.0, true)

func _sector(center: Vector2, inner: float, outer: float, from: float, to: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(13): points.append(_point(center, outer, lerpf(from, to, i / 12.0)))
	for i in range(12, -1, -1): points.append(_point(center, inner, lerpf(from, to, i / 12.0)))
	draw_colored_polygon(points, color)

func _text(text: String, point: Vector2, color: Color, font_size: int = Style.DEFAULT_TEXT_FONT_SIZE) -> void:
	var font := Style.get_game_font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline := point + Vector2(-width * 0.5, (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5)
	draw_string(font, baseline.round(), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

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
	# Stationary, square marquee lamps chase around the gold rim.
	var chase := int(elapsed * (22.0 if spinning else 4.0))
	for i in range(48):
		var point := _point(center, 169, TOP + i * TAU / 48.0)
		var lit := posmod(i - chase, 8) < 3
		draw_rect(Rect2((point - Vector2(3, 3)).round(), Vector2(6, 6)), Color("fff1bc") if lit else Color("b77936"))
	_disc(center, 56, Color("110b20"))
	_disc(center, 54, Color("a05c2b"))
	_disc(center, 50, GOLD)
	_disc(center, 43, Color("43204f"))
	_disc(center, 36, Color("4e285d"))
	_text("DAILY", center - Vector2(0, 11), Color("fff0ca"))
	_text("SPIN", center + Vector2(0, 14), GOLD)
	if ball_visible:
		if spinning:
			var speed := sin(PI * progress) * 0.7
			for i in range(10, 0, -1):
				var point := _point(center, ball_radius, ball_angle + i * speed * 0.035)
				draw_rect(Rect2(point - Vector2(3, 3), Vector2(6, 6)), Color(1, 0.88, 0.57, (1.0 - i / 11.0) * 0.4))
		var ball := _point(center, ball_radius, ball_angle)
		_disc(ball + Vector2(2, 3), 8, Color("090715"))
		_disc(ball, 7, Color("c6af87"))
		_disc(ball - Vector2(1, 1), 5, Color("fff6da"))
		draw_rect(Rect2(ball - Vector2(3, 3), Vector2(3, 3)), Color.WHITE)
	# Spring-loaded pointer stays fixed while the wheel rotates beneath it.
	var pivot := center + Vector2(0, -184)
	draw_set_transform(pivot, -pointer_kick * 0.15)
	draw_colored_polygon(PackedVector2Array([Vector2(-17, -2), Vector2(17, -2), Vector2(14, 15), Vector2(0, 29), Vector2(-14, 15)]), INK)
	draw_colored_polygon(PackedVector2Array([Vector2(-12, 1), Vector2(12, 1), Vector2(10, 12), Vector2(0, 23), Vector2(-10, 12)]), GOLD)
	draw_rect(Rect2(-8, 2, 16, 5), Color("fff6d2"))
	draw_set_transform(Vector2.ZERO)
