extends Control
## Native pixel motifs for account-bound Dispatch decorations.
var cosmetic_id := ""
var tint := Color("ffdc7b")
var elapsed := 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(64, 64)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if cosmetic_id == "paper_moth_pet" and is_visible_in_tree():
		elapsed += delta
		queue_redraw()

func _draw() -> void:
	var ink := Color("301b3a")
	var paper := Color("fff1cf")
	var origin := (size - Vector2(64, 64)) * 0.5
	draw_set_transform(origin)
	match cosmetic_id:
		"envelope_sticker":
			draw_rect(Rect2(8, 18, 48, 32), ink)
			draw_rect(Rect2(12, 22, 40, 24), paper)
			draw_polyline(PackedVector2Array([Vector2(12, 22), Vector2(32, 36), Vector2(52, 22)]), tint, 4)
		"postmark_frame":
			for x in range(8, 57, 8):
				draw_rect(Rect2(x, 8, 5, 5), tint)
				draw_rect(Rect2(x, 51, 5, 5), tint)
			for y in range(16, 50, 8):
				draw_rect(Rect2(8, y, 5, 5), tint)
				draw_rect(Rect2(51, y, 5, 5), tint)
			draw_rect(Rect2(20, 22, 24, 20), paper)
		"paper_moth_pin", "paper_moth_pet":
			var wing := 3.0 * sin(elapsed * 4.0) if cosmetic_id == "paper_moth_pet" else 0.0
			draw_colored_polygon(PackedVector2Array([Vector2(30, 26), Vector2(8, 14 + wing), Vector2(12, 40), Vector2(28, 46)]), paper)
			draw_colored_polygon(PackedVector2Array([Vector2(34, 26), Vector2(56, 14 + wing), Vector2(52, 40), Vector2(36, 46)]), tint)
			draw_rect(Rect2(29, 22, 6, 26), ink)
			draw_rect(Rect2(25, 15, 4, 8), tint)
			draw_rect(Rect2(35, 15, 4, 8), tint)
		"courier_satchel":
			draw_rect(Rect2(14, 8, 36, 48), tint)
			draw_rect(Rect2(18, 12, 28, 40), paper)
			draw_rect(Rect2(14, 8, 8, 48), Color("95624b"))
			draw_rect(Rect2(28, 23, 18, 4), ink)
			draw_rect(Rect2(28, 33, 14, 4), ink)
		"reed_lantern":
			draw_rect(Rect2(28, 6, 8, 10), tint)
			draw_rect(Rect2(16, 16, 32, 8), ink)
			draw_rect(Rect2(20, 24, 24, 24), tint)
			draw_rect(Rect2(28, 28, 8, 16), paper)
			draw_rect(Rect2(16, 48, 32, 8), ink)
		"seed_label_set":
			draw_rect(Rect2(28, 22, 6, 32), tint)
			draw_rect(Rect2(14, 20, 16, 8), tint)
			draw_rect(Rect2(34, 12, 16, 8), tint)
			draw_rect(Rect2(38, 36, 18, 12), paper)
			draw_rect(Rect2(44, 48, 4, 10), tint)
		"moonpost_board":
			draw_rect(Rect2(12, 12, 40, 36), ink)
			draw_rect(Rect2(16, 16, 32, 28), tint)
			draw_rect(Rect2(20, 48, 4, 10), tint)
			draw_rect(Rect2(40, 48, 4, 10), tint)
			draw_rect(Rect2(28, 22, 12, 16), paper)
			draw_rect(Rect2(34, 20, 8, 12), tint)
		"threadlight_set":
			draw_polyline(PackedVector2Array([Vector2(8, 42), Vector2(20, 18), Vector2(32, 42), Vector2(44, 18), Vector2(56, 42)]), tint, 4)
			for x in [16, 40]:
				draw_rect(Rect2(x, 14, 8, 8), paper)
