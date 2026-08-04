extends Node2D

# PixelMania Reach Indicator Manager v4
#
# Soft rounded blue cells — almost invisible but perceptible.
# Both item and wrench modes use the same blue palette.
# Icons are minimal and clean.

const COLOR_FILL    = Color(0.50, 0.78, 1.00, 0.022)
const COLOR_BORDER  = Color(0.60, 0.88, 1.00, 0.10)
const COLOR_ICON    = Color(0.72, 0.94, 1.00, 0.18)
const SELECT_TEXTURE_PATH = "res://Assets/ui/icons/select.png"
const INTERACT_TEXTURE_PATH = "res://Assets/ui/icons/interact.png"
const SELECT_TEXTURE_COLOR = Color(1.0, 1.0, 1.0, 0.40)
const SELECT_TEXTURE_SHADOW_COLOR = Color(0.0, 0.0, 0.0, 0.08)

const BORDER_W  = 1.2
const INSET     = 1.0
const RADIUS    = 4.0   # corner radius for rounded feel

var world = null
var select_texture: Texture2D = null
var interact_texture: Texture2D = null


func setup(world_ref):
	world = world_ref
	z_index = 5
	z_as_relative = false
	if select_texture == null and ResourceLoader.exists(SELECT_TEXTURE_PATH):
		select_texture = load(SELECT_TEXTURE_PATH) as Texture2D
	if interact_texture == null and ResourceLoader.exists(INTERACT_TEXTURE_PATH):
		interact_texture = load(INTERACT_TEXTURE_PATH) as Texture2D


func _process(_delta):
	queue_redraw()


func _draw():
	if world == null or not world.in_world:
		return
	if world.player == null:
		return
	if _any_ui_open():
		return

	var item_type = world.selected_item_type
	var category  = world.selected_item_category

	if category == "tool" and item_type == "punch":
		return

	var is_wrench  = category == "tool" and item_type == "wrench"
	var player_pos = world.player.global_position
	var bs         = float(world.BLOCK_SIZE)
	var reach      = float(world.INTERACTION_PIXEL_RANGE)
	var cells      = int(ceil(reach / bs)) + 1
	var pgx        = int(round(player_pos.x / bs))
	var pgy        = int(round(player_pos.y / bs))

	for dx in range(-cells, cells + 1):
		for dy in range(-cells, cells + 1):
			var gx = pgx + dx
			var gy = pgy + dy
			var grid_pos = Vector2i(gx, gy)

			if not world.is_grid_inside_world(grid_pos):
				continue

			var block_center = Vector2(gx * bs, gy * bs)
			if player_pos.distance_to(block_center) > reach:
				continue

			if not is_wrench:
				# Placement mode: only empty tiles
				if world.blocks.has(grid_pos):
					continue
				if world.has_planted_seed(grid_pos):
					continue
			else:
				# Wrench mode: only blocks that are actually interactable
				if not _is_interactable_grid(grid_pos):
					continue

			var block_tl = Vector2(gx * bs - bs * 0.5, gy * bs - bs * 0.5)
			var tl  = block_tl + Vector2(INSET, INSET)
			var sz  = bs - INSET * 2.0
			var cnt = tl + Vector2(sz * 0.5, sz * 0.5)

			if is_wrench:
				if interact_texture != null:
					_draw_indicator_texture(interact_texture, block_tl, bs)
				else:
					_draw_rounded_rect(tl, sz, sz, RADIUS, COLOR_FILL, true)
					_draw_rounded_rect(tl, sz, sz, RADIUS, COLOR_BORDER, false)
					_draw_wrench(cnt, sz * 0.24, COLOR_ICON)
			elif select_texture != null:
				_draw_indicator_texture(select_texture, block_tl, bs)
			else:
				_draw_rounded_rect(tl, sz, sz, RADIUS, COLOR_FILL, true)
				_draw_rounded_rect(tl, sz, sz, RADIUS, COLOR_BORDER, false)
				_draw_plus(cnt, sz * 0.20, sz * 0.055, COLOR_ICON)


func _draw_indicator_texture(texture: Texture2D, top_left: Vector2, size: float):
	if texture == null:
		return
	var rect = Rect2(top_left, Vector2(size, size))
	var shadow_rect = Rect2(top_left + Vector2(2.0, 2.0), Vector2(size, size))
	draw_texture_rect(texture, shadow_rect, false, SELECT_TEXTURE_SHADOW_COLOR)
	draw_texture_rect(texture, rect, false, SELECT_TEXTURE_COLOR)


# ── Rounded rectangle ─────────────────────────────────────────

func _draw_rounded_rect(origin: Vector2, w: float, h: float, r: float, color: Color, filled: bool):
	var r2   = min(r, min(w, h) * 0.5)
	var pts  = PackedVector2Array()
	var segs = 6  # segments per corner

	var corners = [
		Vector2(origin.x + r2,     origin.y + r2),
		Vector2(origin.x + w - r2, origin.y + r2),
		Vector2(origin.x + w - r2, origin.y + h - r2),
		Vector2(origin.x + r2,     origin.y + h - r2),
	]
	var start_angles = [PI, PI * 1.5, 0.0, PI * 0.5]

	for ci in range(4):
		for s in range(segs + 1):
			var angle = start_angles[ci] + float(s) / float(segs) * (PI * 0.5)
			pts.append(corners[ci] + Vector2(cos(angle), sin(angle)) * r2)

	if filled:
		var cols = PackedColorArray()
		for i in range(pts.size()):
			cols.append(color)
		draw_polygon(pts, cols)
	else:
		for i in range(pts.size()):
			draw_line(pts[i], pts[(i + 1) % pts.size()], color, BORDER_W, true)


# ── Plus icon ─────────────────────────────────────────────────

func _draw_plus(center: Vector2, half_len: float, half_thick: float, color: Color):
	draw_rect(Rect2(center.x - half_len, center.y - half_thick, half_len * 2.0, half_thick * 2.0), color, true)
	draw_rect(Rect2(center.x - half_thick, center.y - half_len, half_thick * 2.0, half_len * 2.0), color, true)


# ── Wrench icon ───────────────────────────────────────────────

func _draw_wrench(center: Vector2, r: float, color: Color):
	var segs  = 14
	var outer = r
	var inner = r * 0.50
	for i in range(segs):
		var a0 = float(i)       / segs * TAU
		var a1 = float(i + 1)   / segs * TAU
		var p  = PackedVector2Array([
			center + Vector2(cos(a0), sin(a0)) * outer,
			center + Vector2(cos(a1), sin(a1)) * outer,
			center + Vector2(cos(a1), sin(a1)) * inner,
			center + Vector2(cos(a0), sin(a0)) * inner,
		])
		draw_polygon(p, PackedColorArray([color, color, color, color]))

	var angle  = deg_to_rad(40.0)
	var dir    = Vector2(cos(angle), sin(angle))
	var perp   = Vector2(-dir.y, dir.x)
	var hw     = r * 0.30
	var hlen   = r * 1.05
	var origin = center + dir * (inner * 0.5)
	draw_polygon(
		PackedVector2Array([
			origin + perp * hw,
			origin - perp * hw,
			origin + dir * hlen - perp * hw,
			origin + dir * hlen + perp * hw,
		]),
		PackedColorArray([color, color, color, color])
	)


func _is_interactable_grid(grid_pos: Vector2i) -> bool:
	if world.has_method("is_visible_generator_at") and bool(world.is_visible_generator_at(grid_pos)):
		return true

	if world.blocks.has(grid_pos):
		return _is_interactable(str(world.blocks[grid_pos].get("type", "")))

	return false


func _is_interactable(block_type: String) -> bool:
	if world.has_method("is_interactable_block") and world.is_interactable_block(block_type): return true
	if world.has_method("is_area_lock_block_type") and world.is_area_lock_block_type(block_type): return true
	if world.has_method("is_vending_machine_block_type") and world.is_vending_machine_block_type(block_type): return true
	if world.has_method("is_mailbox_block_type") and world.is_mailbox_block_type(block_type): return true
	if world.has_method("is_bulletin_board_block_type") and world.is_bulletin_board_block_type(block_type): return true
	if world.has_method("is_display_block_type") and world.is_display_block_type(block_type): return true
	if world.has_method("is_toggle_block") and world.is_toggle_block(block_type): return true
	if world.has_method("is_anti_punch_block_type") and world.is_anti_punch_block_type(block_type): return true
	if world.has_method("is_anti_talk_block_type") and world.is_anti_talk_block_type(block_type): return true
	if world.has_method("is_anti_gravity_block_type") and world.is_anti_gravity_block_type(block_type): return true
	if world.has_method("is_theme_machine_block_type") and world.is_theme_machine_block_type(block_type): return true
	if world.has_method("is_cctv_block_type") and world.is_cctv_block_type(block_type): return true
	if world.has_method("is_oil_refinery_block_type") and world.is_oil_refinery_block_type(block_type): return true
	if world.has_method("is_world_lock_block_type") and world.is_world_lock_block_type(block_type): return true
	if world.has_method("is_entrance_gate_block") and world.is_entrance_gate_block(block_type): return true
	if world.has_method("is_crafting_station_block") and world.is_crafting_station_block(block_type): return true
	if world.has_method("is_furnace_block") and world.is_furnace_block(block_type): return true
	if world.has_method("is_wooden_entrance_block") and world.is_wooden_entrance_block(block_type): return true
	if world.has_method("is_sign_block") and world.is_sign_block(block_type):       return true
	return false


func _any_ui_open() -> bool:
	if world == null: return false
	if world.has_method("is_crafting_open")      and world.is_crafting_open():      return true
	if world.has_method("is_furnace_open")       and world.is_furnace_open():       return true
	if world.has_method("is_sign_open")          and world.is_sign_open():          return true
	if world.has_method("is_shop_open")          and world.is_shop_open():          return true
	if world.has_method("is_world_lock_ui_open") and world.is_world_lock_ui_open(): return true
	return false
