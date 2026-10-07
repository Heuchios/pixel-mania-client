extends Label
## Lobby-only tips, shuffled without repeats until every tip has been shown.
const TIP_SECONDS := 9.0
const FADE_SECONDS := 0.4
const TIPS: Array[String] = [
	"Tap a world's heart to save it to your favorites.",
	"Use your world history to revisit places you've joined.",
	"Find PixelMania's official worlds in the PM tab.",
	"Search crafting recipes by item name or ingredient.",
	"The Ready to Craft filter shows recipes you have materials for.",
	"Check the output quantity before crafting a recipe.",
	"Your Fishing Journal keeps track of the fish you've discovered.",
	"Sell your catches to the Fish Monger for gems.",
	"Check both players' offers before accepting a trade.",
	"Vending prices can be items per World Lock or World Locks per item.",
	"Review the quantity and total before confirming a purchase.",
	"Area locks let you give trusted players building access.",
]
var _remaining: Array[int] = []
var _last := -1
var _elapsed := 0.0
var _first := true
var _rng := RandomNumberGenerator.new()
func _ready() -> void:
	_rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("manual_screen_layout", true)
	set_meta("pixelmania_font_size", 22)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preload("res://Scripts/ui/pixel_ui_style.gd").apply_small_label(self, 22)
	add_theme_color_override("font_color", Color("d7c4e7"))
	_next_tip()
	get_viewport().size_changed.connect(_layout)
	_layout()
func _layout() -> void:
	var screen := get_viewport_rect().size
	var width := minf(1200.0, maxf(180.0, screen.x - 180.0))
	position = Vector2((screen.x - width) * 0.5, screen.y - 84.0)
	size = Vector2(width, 64)
	var font_size := 22 if screen.x >= 1000 else 16
	set_meta("pixelmania_font_size", font_size)
	add_theme_font_size_override("font_size", font_size)
func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_elapsed += delta
	if _elapsed >= TIP_SECONDS:
		_elapsed = fmod(_elapsed, TIP_SECONDS)
		_first = false
		_next_tip()
	var fade_in := 1.0 if _first else clampf(_elapsed / FADE_SECONDS, 0.0, 1.0)
	var fade_out := clampf((TIP_SECONDS - _elapsed) / FADE_SECONDS, 0.0, 1.0)
	modulate.a = minf(fade_in, fade_out)
func _next_tip() -> void:
	if _remaining.is_empty():
		for i in range(TIPS.size()):
			_remaining.append(i)
	var candidates := _remaining.duplicate()
	candidates.erase(_last)
	var next: int = candidates[_rng.randi_range(0, candidates.size() - 1)] if not candidates.is_empty() else _remaining[0]
	_remaining.erase(next)
	_last = next
	text = "TIP  /  " + TIPS[next]
	call_deferred("_layout")
