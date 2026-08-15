extends MeshInstance2D

## Rippling water surface for PixelMania.
##
## Purely cosmetic. This reads water blocks and draws them prettier; it never
## places, breaks, or mutates a block, never touches the network, and never
## changes what the server is authoritative for. Turning it off restores the
## existing tile-based water exactly, because the tile path is not modified at
## all — the water TileMapLayer is simply hidden while this is drawing.
##
## Responsibilities, kept narrow so this sits BESIDE block_manager rather than
## inside it (block_manager still owns water tile visuals):
##   1. find contiguous water surface runs near the camera  -> bands
##   2. run a damped wave simulation on those bands          -> ripples
##   3. rebuild one 2D mesh from the bands                   -> one draw call
##
## Set up from world.gd via setup_water_surface_manager(), matching the pattern
## used by every other manager.

const WorldTileMapRenderer = preload("res://Scripts/world_tilemap_renderer.gd")

const WATER_BLOCK_ID := "water"
const SAMPLES_PER_TILE_MIN := 1
const SAMPLES_PER_TILE_MAX := 8

## Surface tuning. ripple_speed is in world pixels per second and the spring
## coupling is derived from it using the actual spring spacing, so dropping
## samples_per_tile for mobile changes only how finely the surface is sampled,
## not how the water behaves.
@export var stiffness: float = 1.0
@export var damping: float = 0.0
@export var ripple_speed: float = 105.0
@export var smoothing: float = 0.12
@export var propagation_passes: int = 2
@export var max_splash_impulse: float = 605.0

## Amplitude the surface keeps forever, in world pixels. With damping at zero
## the surface is lossless, which is what makes it look alive — but lossless
## also means energy only accumulates, and a busy public world would drive the
## waves up without limit. Below calm_amplitude there is no damping at all;
## above it the excess bleeds off. Evaluated per spring, so one violent crest
## does not flatten the gentle ripples at the far end of a lake.
@export var calm_amplitude: float = 10.0
@export var overdrive_damping: float = 6.0

## Ceiling on simulated springs. Bands past the budget still render, they just
## stop moving, so a flooded world degrades instead of stuttering.
@export var max_simulated_springs: int = 3000

## Springs per 32px tile. Lower on mobile purely as a cost saving.
@export var samples_per_tile_desktop: int = 7
@export var samples_per_tile_mobile: int = 4

## How often the visible area is rescanned for water changes, in seconds.
## Bands are only rebuilt when the water actually changed or the camera moved,
## so this is a change-detection budget, not a rebuild cost.
@export var rescan_interval: float = 0.12
## Tiles of margin around the camera view to scan and simulate.
@export var view_margin_tiles: int = 6

var world = null
var enabled := true

var bands: Array = []
var _samples_per_tile: int = 7
var _immediate_mesh: ImmediateMesh
var _material: ShaderMaterial
var _surface_frames: Array = []
var _surface_frame_index: int = 0
var _surface_frame_timer: float = 0.0
var _rescan_timer: float = 0.0
var _last_signature: int = 0
var _last_scan_rect := Rect2i()
var _view_rect := Rect2()


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func setup(world_controller) -> void:
	world = world_controller
	name = "WaterSurfaceManager"
	z_index = WorldTileMapRenderer.WATER_Z_INDEX
	z_as_relative = false
	position = Vector2.ZERO
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

	_samples_per_tile = samples_per_tile_mobile if _is_mobile() else samples_per_tile_desktop

	if _immediate_mesh == null:
		_immediate_mesh = ImmediateMesh.new()
		mesh = _immediate_mesh

	_build_material()
	force_rescan()


func _is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


func _build_material() -> void:
	if _material != null:
		return
	var shader = load("res://Assets/shaders/water_body.gdshader")
	if shader == null:
		push_warning("WaterSurfaceManager: water_body.gdshader missing, staying disabled")
		enabled = false
		return

	_material = ShaderMaterial.new()
	_material.shader = shader
	material = _material

	_surface_frames.clear()
	for path in [
		"res://Assets/blocks/Tier_1/basic blocks/water_0.png",
		"res://Assets/blocks/Tier_1/basic blocks/water_1.png",
		"res://Assets/blocks/Tier_1/basic blocks/water_2.png",
		"res://Assets/blocks/Tier_1/basic blocks/water_3.png",
	]:
		var frame = load(path)
		if frame != null:
			_surface_frames.append(frame)

	var body = load("res://Assets/blocks/Tier_1/basic blocks/water_block_2.png")
	if body != null:
		_material.set_shader_parameter("body_tex", body)
	if not _surface_frames.is_empty():
		_material.set_shader_parameter("surface_tex", _surface_frames[0])


## Turn the effect on or off at runtime. Off restores the shipped tile water.
func set_enabled(value: bool) -> void:
	if enabled == value:
		return
	enabled = value
	if not enabled:
		bands.clear()
		if _immediate_mesh != null:
			_immediate_mesh.clear_surfaces()
	_apply_water_layer_visibility()
	force_rescan()


func force_rescan() -> void:
	_last_signature = 0
	_last_scan_rect = Rect2i()
	_rescan_timer = 0.0


# ---------------------------------------------------------------------------
# Frame loop
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not enabled or world == null or not is_instance_valid(world):
		return
	if not _is_tile_water_active():
		_go_dormant()
		return
	_apply_water_layer_visibility()

	_rescan_timer -= delta
	if _rescan_timer <= 0.0:
		_rescan_timer = maxf(0.02, rescan_interval)
		_rescan()

	_simulate(delta)


func _process(delta: float) -> void:
	if not enabled or world == null or not is_instance_valid(world):
		return
	_advance_surface_frame(delta)
	_rebuild_mesh()


## The tile water layer and this mesh would otherwise double-draw, and the art
## is translucent so the overlap is obvious. Hiding the layer leaves every
## existing per-cell code path in block_manager running untouched, which is what
## makes the rollback exact.
func _apply_water_layer_visibility() -> void:
	var layer := _get_water_layer()
	if layer == null:
		return
	# Re-asserted every frame on purpose: the renderer rebuilds its layers when
	# the world changes, which would otherwise bring the tile water back.
	var wants_layer_visible := not enabled
	if layer.visible == wants_layer_visible:
		return
	layer.visible = wants_layer_visible


## This effect replaces the water TileMapLayer, so it may only run when that
## layer is the thing actually drawing water. If tilemap rendering is off the
## client falls back to per-block sprite nodes, which this cannot hide — drawing
## over those would double up the translucent art. In that case stay out of the
## way entirely and let the shipped path render.
func _is_tile_water_active() -> bool:
	if world == null or not is_instance_valid(world):
		return false
	var renderer = world.get_node_or_null("WorldTileMapRenderer")
	if renderer == null:
		return false
	if ("enabled" in renderer) and not bool(renderer.enabled):
		return false
	return _get_water_layer() != null


func _go_dormant() -> void:
	if bands.is_empty() and (_immediate_mesh == null or _immediate_mesh.get_surface_count() == 0):
		return
	bands.clear()
	if _immediate_mesh != null:
		_immediate_mesh.clear_surfaces()
	force_rescan()


func _get_water_layer() -> CanvasItem:
	if world == null or not is_instance_valid(world):
		return null
	var renderer = world.get_node_or_null("WorldTileMapRenderer")
	if renderer == null:
		return null
	if not ("water_layer" in renderer):
		return null
	var layer = renderer.water_layer
	if layer == null or not is_instance_valid(layer):
		return null
	return layer


func _advance_surface_frame(delta: float) -> void:
	if _material == null or _surface_frames.size() < 2:
		return
	var interval := 0.32
	if world != null and "WATER_ANIMATION_SPEED" in world:
		interval = maxf(0.01, float(world.WATER_ANIMATION_SPEED))
	_surface_frame_timer += delta
	if _surface_frame_timer < interval:
		return
	_surface_frame_timer = 0.0
	_surface_frame_index = (_surface_frame_index + 1) % _surface_frames.size()
	_material.set_shader_parameter("surface_tex", _surface_frames[_surface_frame_index])


# ---------------------------------------------------------------------------
# Scanning
# ---------------------------------------------------------------------------

func _update_view_rect() -> bool:
	if world == null or not world.has_method("get_player_camera"):
		return false
	var camera = world.get_player_camera()
	if camera == null or not is_instance_valid(camera) or not (camera is Camera2D):
		return false

	var viewport := get_viewport()
	if viewport == null:
		return false
	var zoom: Vector2 = camera.zoom
	if zoom.x <= 0.001 or zoom.y <= 0.001:
		return false
	var view_size: Vector2 = viewport.get_visible_rect().size / zoom
	var centre: Vector2 = camera.get_screen_center_position()
	_view_rect = Rect2(centre - view_size * 0.5, view_size)
	return true


func _scan_grid_rect() -> Rect2i:
	var block_size := _block_size()
	var margin := float(maxi(1, view_margin_tiles)) * block_size
	var grown := _view_rect.grow(margin)
	var first := _world_to_grid(grown.position)
	var last := _world_to_grid(grown.end)
	return Rect2i(first, last - first + Vector2i.ONE)


func _rescan() -> void:
	if not _update_view_rect():
		return
	var rect := _scan_grid_rect()
	if rect.size.x <= 0 or rect.size.y <= 0:
		return

	var blocks = world.get("blocks")
	if not (blocks is Dictionary):
		return

	# Collect surface cells and hash them in the same pass, so an unchanged
	# scene costs one cheap sweep of the visible area and nothing else.
	var surface_cells: Dictionary = {}
	var signature: int = 17
	for grid_x in range(rect.position.x, rect.position.x + rect.size.x):
		for grid_y in range(rect.position.y, rect.position.y + rect.size.y):
			var cell := Vector2i(grid_x, grid_y)
			if not _is_water_cell(blocks, cell):
				continue
			if _is_water_cell(blocks, Vector2i(grid_x, grid_y - 1)):
				continue
			surface_cells[cell] = true
			signature = (signature * 31 + grid_x * 92837111 + grid_y * 689287499) & 0x3FFFFFFF

	if signature == _last_signature and rect == _last_scan_rect:
		return
	_last_signature = signature
	_last_scan_rect = rect
	_rebuild_bands(blocks, surface_cells)


func _is_water_cell(blocks: Dictionary, cell: Vector2i) -> bool:
	var entry = blocks.get(cell)
	if not (entry is Dictionary):
		return false
	return str(entry.get("type", "")).strip_edges().to_lower() == WATER_BLOCK_ID


# ---------------------------------------------------------------------------
# Bands
# ---------------------------------------------------------------------------

## A chain may drift at most this many tile-rows from its own top-to-bottom
## before it is cut into a fresh band. _linked_neighbour lets the chain step
## one row per tile so a gently sloped beach stays one continuous wave, but
## nothing stops that from repeating tile after tile — a near-vertical run of
## water (a waterfall down a cliff face, a long diagonal channel) satisfies the
## same one-row-per-tile rule and was getting stitched into a single enormous
## band. Simulating that as one spring chain is physically nonsensical (real
## water at wildly different heights isn't one free surface), and in practice
## it let the low-frequency wave mode balloon far past any block boundary —
## reported as the water surface floating above the terrain, arcing across the
## whole screen. Capped here instead of by damping harder, so calm, gently
## sloped shorelines keep exactly the "living water" look already tuned.
const MAX_BAND_ROW_SPAN_TILES := 4

func _rebuild_bands(blocks: Dictionary, surface_cells: Dictionary) -> void:
	var previous_bands := bands
	bands = []

	var visited: Dictionary = {}
	var chains: Array = []

	for grid_pos in surface_cells.keys():
		if visited.has(grid_pos):
			continue
		if _linked_neighbour(surface_cells, grid_pos, -1) != null:
			continue
		_walk_chain_from(surface_cells, grid_pos, visited, chains)

	# Anything the leftmost-start rule missed becomes its own chain.
	for grid_pos in surface_cells.keys():
		if visited.has(grid_pos):
			continue
		visited[grid_pos] = true
		chains.append([grid_pos])

	for chain in chains:
		var band := _build_band(blocks, chain)
		if band != null:
			_inherit_motion(band, previous_bands)
			bands.append(band)


## Walks surface cells rightward from `start`, appending one or more chains to
## `chains`. A chain is closed off — and a fresh one begun at the very next
## cell — as soon as continuing would stretch it past MAX_BAND_ROW_SPAN_TILES
## of total vertical rise. `_is_shore_end()` still checks the real world data,
## so a cut made here for span reasons (rather than a true wall) correctly
## comes out unpinned, same as an end that is merely clipped by the camera.
func _walk_chain_from(surface_cells: Dictionary, start: Vector2i, visited: Dictionary, chains: Array) -> void:
	var chain: Array = []
	var min_row := start.y
	var max_row := start.y
	var cursor = start

	while cursor != null and not visited.has(cursor):
		visited[cursor] = true
		chain.append(cursor)
		min_row = mini(min_row, cursor.y)
		max_row = maxi(max_row, cursor.y)

		var next = _linked_neighbour(surface_cells, cursor, 1)
		if next != null and not visited.has(next):
			var span := maxi(max_row, next.y) - mini(min_row, next.y)
			if span > MAX_BAND_ROW_SPAN_TILES:
				next = null

		cursor = next

	if not chain.is_empty():
		chains.append(chain)


## Next surface cell in the given x direction, allowing a one-tile step so a
## sloped shoreline stays one continuous wave instead of shattering into a band
## per row. Same row wins, then up, then down.
func _linked_neighbour(surface_cells: Dictionary, grid_pos: Vector2i, direction: int):
	var next_x := grid_pos.x + direction
	for delta_y in [0, -1, 1]:
		var candidate := Vector2i(next_x, grid_pos.y + delta_y)
		if surface_cells.has(candidate):
			return candidate
	return null


func _build_band(blocks: Dictionary, chain: Array) -> Band:
	if chain.is_empty():
		return null

	var block_size := _block_size()
	var band := Band.new()
	var first: Vector2i = chain[0]
	var last: Vector2i = chain[chain.size() - 1]

	band.x_start = float(first.x) * block_size - block_size * 0.5
	band.x_end = float(last.x) * block_size + block_size * 0.5
	band.shore_at_start = _is_shore_end(blocks, first, -1)
	band.shore_at_end = _is_shore_end(blocks, last, 1)
	band.spacing = block_size / float(clampi(_samples_per_tile, SAMPLES_PER_TILE_MIN, SAMPLES_PER_TILE_MAX))

	var count := int(round((band.x_end - band.x_start) / band.spacing)) + 1
	count = maxi(count, 2)
	band.resize(count)

	for i in count:
		var world_x := band.world_x_at(i)
		var chain_index := int(floor((world_x - band.x_start) / block_size))
		chain_index = clampi(chain_index, 0, chain.size() - 1)
		var cell: Vector2i = chain[chain_index]
		band.base_y[i] = float(cell.y) * block_size - block_size * 0.5
		band.offsets[i] = 0.0
		band.velocities[i] = 0.0

	# Segment floors are sampled at segment midpoints so each segment sits
	# wholly inside one tile column. Interpolating the floor between springs
	# opens a wedge-shaped hole in the mesh at the lip of any shelf.
	for i in count - 1:
		var mid_x := band.world_x_at(i) + band.spacing * 0.5
		var chain_index := int(floor((mid_x - band.x_start) / block_size))
		chain_index = clampi(chain_index, 0, chain.size() - 1)
		band.segment_bottom_y[i] = _column_bottom_y(blocks, chain[chain_index])

	return band


## A band end is a real shoreline only if no water continues past it. Bands here
## are clipped to the camera scan rect, so a cut-off end must NOT be pinned or
## the water would go still at a seam that slides around with the view.
func _is_shore_end(blocks: Dictionary, cell: Vector2i, direction: int) -> bool:
	for delta_y in [-1, 0, 1]:
		if _is_water_cell(blocks, Vector2i(cell.x + direction, cell.y + delta_y)):
			return false
	return true


func _column_bottom_y(blocks: Dictionary, grid_pos: Vector2i) -> float:
	var block_size := _block_size()
	var probe := grid_pos
	var depth := 0
	while depth < 64 and _is_water_cell(blocks, Vector2i(probe.x, probe.y + 1)):
		probe.y += 1
		depth += 1
	return float(probe.y) * block_size + block_size * 0.5


## Carry ripples across a rebuild, PER SPRING rather than per band. Bands merge
## and split constantly as water is placed and broken. Picking one previous
## band for the whole new band means a splashing pool that merges with a larger
## calm body inherits the calm body's zeros, and every wave dies the instant the
## two touch.
func _inherit_motion(band: Band, previous_bands: Array) -> void:
	if previous_bands.is_empty():
		return
	var tolerance := _block_size() * 1.5
	for i in band.spring_count():
		var world_x := band.world_x_at(i)
		var resting_y := band.base_y[i]
		var best = null
		var best_distance := tolerance
		for previous in previous_bands:
			if previous.spring_count() == 0 or not previous.contains_world_x(world_x):
				continue
			var distance := absf(previous.base_y_at_world_x(world_x) - resting_y)
			if distance < best_distance:
				best_distance = distance
				best = previous
		if best == null:
			continue
		band.offsets[i] = best.offset_at_world_x(world_x)
		band.velocities[i] = best.velocity_at_world_x(world_x)


# ---------------------------------------------------------------------------
# Simulation
# ---------------------------------------------------------------------------

func _simulate(delta: float) -> void:
	var used := 0
	for band in bands:
		if band.x_end < _view_rect.position.x or band.x_start > _view_rect.end.x:
			continue
		var count: int = band.spring_count()
		if used + count > max_simulated_springs:
			continue
		band.simulate(delta, stiffness, damping, ripple_speed, smoothing, propagation_passes, calm_amplitude, overdrive_damping)
		used += count


# ---------------------------------------------------------------------------
# Public API — what player.gd and anything else calls
# ---------------------------------------------------------------------------

## Rippled surface y at a world x, or INF if there is no band there. `near_y`
## disambiguates stacked bodies, e.g. a cave lake under a surface lake.
func surface_y_at(world_x: float, near_y: float = INF) -> float:
	var best := INF
	var best_distance := INF
	for band in bands:
		if not band.contains_world_x(world_x):
			continue
		var candidate: float = band.surface_y_at_world_x(world_x)
		if candidate == INF:
			continue
		if near_y == INF:
			if candidate < best:
				best = candidate
			continue
		var distance := absf(candidate - near_y)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best


## Splash. `impulse` is a velocity in px/s; negative throws the surface upward.
func disturb(world_x: float, impulse: float, near_y: float = INF, radius_springs: int = 2) -> void:
	if not enabled:
		return
	var target = null
	var best_distance := INF
	for band in bands:
		if not band.contains_world_x(world_x):
			continue
		if near_y == INF:
			target = band
			break
		var distance := absf(band.surface_y_at_world_x(world_x) - near_y)
		if distance < best_distance:
			best_distance = distance
			target = band
	if target != null:
		target.disturb(world_x, clampf(impulse, -max_splash_impulse, max_splash_impulse), radius_springs)


## Splash across a width, for a body wider than one spring.
func disturb_span(x_from: float, x_to: float, impulse: float, near_y: float = INF) -> void:
	if not enabled:
		return
	var left: float = minf(x_from, x_to)
	var right: float = maxf(x_from, x_to)
	var step: float = maxf(4.0, _block_size() / float(maxi(1, _samples_per_tile)))
	var world_x := left
	while world_x <= right:
		disturb(world_x, impulse, near_y, 1)
		world_x += step


# ---------------------------------------------------------------------------
# Mesh
# ---------------------------------------------------------------------------

func _rebuild_mesh() -> void:
	if _immediate_mesh == null:
		return
	_immediate_mesh.clear_surfaces()
	if bands.is_empty():
		return

	var tile := _block_size()
	var left_bound := _view_rect.position.x - tile
	var right_bound := _view_rect.end.x + tile

	# The surface is opened lazily, on the first vertex that actually survives
	# culling. Bands are built from the scan rect, which is the view plus a
	# margin, so it is completely normal for bands to exist while none of them
	# is on screen — water just off the edge of the view. Opening the surface up
	# front and closing it empty makes Godot log "No vertices were added,
	# surface can't be created" every single frame in that case.
	var surface_open := false
	for band in bands:
		if band.x_end < left_bound or band.x_start > right_bound:
			continue
		var count: int = band.spring_count()
		for i in count - 1:
			var left_x: float = band.world_x_at(i)
			var right_x: float = band.world_x_at(i + 1)
			if right_x < left_bound or left_x > right_bound:
				continue

			var segment_floor: float = band.segment_bottom_y[i]
			var left_top_y: float = band.surface_y_at_index(i)
			var right_top_y: float = band.surface_y_at_index(i + 1)

			# base_y only changes between neighbouring springs where the chain
			# crosses onto a different tile row — an underwater shelf, or the
			# shore meeting a wall. Springs sit a fraction of a tile apart, so
			# interpolating that jump the normal way draws a steep diagonal
			# ramp across a sliver of a tile instead of the crisp vertical
			# face a blocky ledge should have. Hold each half of the segment
			# flat and let them meet at a vertical step instead, so it reads
			# as an edge like the terrain it borders.
			if absf(band.base_y[i + 1] - band.base_y[i]) > 1.0:
				var mid_x: float = (left_x + right_x) * 0.5
				surface_open = _emit_water_segment(left_x, mid_x, left_top_y, left_top_y, segment_floor, tile, left_bound, right_bound, surface_open)
				surface_open = _emit_water_segment(mid_x, right_x, right_top_y, right_top_y, segment_floor, tile, left_bound, right_bound, surface_open)
			else:
				surface_open = _emit_water_segment(left_x, right_x, left_top_y, right_top_y, segment_floor, tile, left_bound, right_bound, surface_open)

	if surface_open:
		_immediate_mesh.surface_end()


## Emits one water quad spanning x0..x1, whose top edge runs from y0 (at x0) to
## y1 (at x1) — equal for a flat segment, different for the smooth interpolated
## slope a rippling wave produces — down to the shared floor_y. Returns whether
## the mesh surface is open, threaded through instead of a member variable so
## _rebuild_mesh can call this repeatedly per segment.
func _emit_water_segment(x0: float, x1: float, y0: float, y1: float, floor_y: float, tile: float, left_bound: float, right_bound: float, surface_open: bool) -> bool:
	if x1 < left_bound or x0 > right_bound:
		return surface_open

	# A wave crest can briefly rise above a very shallow puddle's floor.
	if floor_y <= y0 and floor_y <= y1:
		return surface_open

	var depth0: float = maxf(0.0, floor_y - y0) / tile
	var depth1: float = maxf(0.0, floor_y - y1) / tile

	if not surface_open:
		_immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		surface_open = true

	var top_left := Vector2(x0, y0)
	var top_right := Vector2(x1, y1)
	var bottom_left := Vector2(x0, floor_y)
	var bottom_right := Vector2(x1, floor_y)

	_emit_vertex(top_left, 0.0, depth0, tile)
	_emit_vertex(top_right, 0.0, depth1, tile)
	_emit_vertex(bottom_right, depth1, depth1, tile)
	_emit_vertex(top_left, 0.0, depth0, tile)
	_emit_vertex(bottom_right, depth1, depth1, tile)
	_emit_vertex(bottom_left, depth0, depth0, tile)

	return surface_open


## UV carries the geometry data the shader needs:
##   x = depth of THIS vertex below the surface, in tiles (0 at the surface)
##   y = total depth of the water column here, in tiles
##
## Deliberately UV and not COLOR. Mesh vertex colours are RGBA8, so a depth in
## tiles passed through COLOR is clamped to 1.0 — every pool deeper than one
## tile reported a depth of exactly one tile, which made the waterline four
## times too thick and flattened every depth-driven effect. UV is float.
##
## The shader reads world position from VERTEX instead, which is valid only
## because this node sits at the origin with no scale or rotation.
func _emit_vertex(point: Vector2, vertex_depth: float, column_depth: float, _tile: float) -> void:
	_immediate_mesh.surface_set_uv(Vector2(vertex_depth, column_depth))
	_immediate_mesh.surface_add_vertex_2d(point)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _block_size() -> float:
	if world != null and "BLOCK_SIZE" in world:
		return float(world.BLOCK_SIZE)
	return 32.0


## Matches player.gd::world_point_to_centered_water_grid(): tiles are centred on
## grid_pos * BLOCK_SIZE, so the top edge is y * BLOCK_SIZE - BLOCK_SIZE / 2.
func _world_to_grid(world_position: Vector2) -> Vector2i:
	var block_size := maxf(1.0, _block_size())
	var half := block_size * 0.5
	return Vector2i(
		int(floor((world_position.x + half) / block_size)),
		int(floor((world_position.y + half) / block_size))
	)


# ---------------------------------------------------------------------------
# One continuous stretch of water surface, simulated as a chain of springs
# ---------------------------------------------------------------------------

class Band extends RefCounted:
	## Courant number for the wave coupling, and the smoothing bound that goes
	## with it. These are not independent: the smoothing pass moves position
	## without touching velocity, so at the textbook c*dt/dx = 1 even modest
	## smoothing pushes the highest spatial mode past unity gain and the surface
	## explodes into NaN. 0.8 with smoothing <= 0.12 keeps the worst-case mode
	## at about 0.72.
	const CFL_LIMIT := 0.8
	const MAX_SMOOTHING := 0.12
	## Hard bounds on the visual state, in world pixels and px/s. The stability
	## bounds above are the real fix; this is the backstop that stops one bad
	## frame becoming a permanently broken surface.
	const MAX_OFFSET := 96.0
	const MAX_VELOCITY := 2400.0

	var x_start: float = 0.0
	var x_end: float = 0.0
	var spacing: float = 8.0

	var base_y := PackedFloat32Array()
	var segment_bottom_y := PackedFloat32Array()
	var offsets := PackedFloat32Array()
	var velocities := PackedFloat32Array()

	## True when this end of the band is a real shoreline — water meeting a wall
	## — rather than the band simply being cut off because more water continues
	## past it. Bands here are clipped to the camera, so only real shorelines are
	## pinned; flattening the wave at an arbitrary cut would make the water go
	## still at a seam that slides around with the view.
	var shore_at_start := true
	var shore_at_end := true

	func spring_count() -> int:
		return offsets.size()

	func resize(count: int) -> void:
		base_y.resize(count)
		segment_bottom_y.resize(maxi(0, count - 1))
		offsets.resize(count)
		velocities.resize(count)

	func world_x_at(index: int) -> float:
		return x_start + float(index) * spacing

	func surface_y_at_index(index: int) -> float:
		return base_y[index] + offsets[index]

	func index_at_world_x(world_x: float) -> int:
		if spring_count() <= 0:
			return -1
		var index := int(round((world_x - x_start) / maxf(0.001, spacing)))
		return clampi(index, 0, spring_count() - 1)

	func contains_world_x(world_x: float) -> bool:
		return world_x >= x_start - spacing and world_x <= x_end + spacing

	## Resting (undisplaced) line at a world x. Matching bands across a rebuild
	## must compare resting lines, not displaced ones, or a band carrying a big
	## wave fails to match its own successor.
	func base_y_at_world_x(world_x: float) -> float:
		var index := index_at_world_x(world_x)
		return base_y[index] if index >= 0 else INF

	func offset_at_world_x(world_x: float) -> float:
		var index := index_at_world_x(world_x)
		return offsets[index] if index >= 0 else 0.0

	func velocity_at_world_x(world_x: float) -> float:
		var index := index_at_world_x(world_x)
		return velocities[index] if index >= 0 else 0.0

	func surface_y_at_world_x(world_x: float) -> float:
		var count := spring_count()
		if count <= 0:
			return INF
		var raw := (world_x - x_start) / maxf(0.001, spacing)
		var low := clampi(int(floor(raw)), 0, count - 1)
		var high := clampi(low + 1, 0, count - 1)
		var blend := clampf(raw - float(low), 0.0, 1.0)
		return lerpf(surface_y_at_index(low), surface_y_at_index(high), blend)

	## Kick a spring. Negative velocity throws the surface upward.
	func disturb(world_x: float, impulse: float, radius_springs: int = 2) -> void:
		var count := spring_count()
		if count <= 0:
			return
		var centre := index_at_world_x(world_x)
		if centre < 0:
			return
		var radius: int = maxi(0, radius_springs)
		for offset_index in range(-radius, radius + 1):
			var index := centre + offset_index
			if index < 0 or index >= count:
				continue
			var falloff := 1.0
			if radius > 0:
				falloff = 0.5 + 0.5 * cos(PI * float(offset_index) / float(radius + 1))
			velocities[index] += impulse * falloff

	## Damped wave equation along the band, integrated semi-implicitly.
	##   stiffness   1/s^2, pulls the surface back to its resting line
	##   damping     1/s,   constant energy loss
	##   wave_speed  px/s,  how fast a ripple travels sideways
	##   smoothing   0..0.12, dimensionless, kills single-spring jitter
	##   calm_amplitude / overdrive_damping — amplitude-dependent damping, so a
	##   lossless surface still cannot accumulate energy without bound.
	func simulate(delta: float, stiffness: float, damping: float, wave_speed: float, smoothing: float, passes: int, calm_amplitude: float = 0.0, overdrive_damping: float = 0.0) -> void:
		var count := spring_count()
		if count <= 0 or delta <= 0.0:
			return

		var ceiling_active := calm_amplitude > 0.0 and overdrive_damping > 0.0
		var pass_count: int = maxi(1, passes)
		var sub_delta := delta / float(pass_count)
		var damping_limit := 1.8 / maxf(0.0001, sub_delta)

		var coupling := pow(wave_speed / maxf(0.001, spacing), 2.0)
		var stability_limit := pow(CFL_LIMIT / maxf(0.0001, sub_delta), 2.0)
		coupling = minf(coupling, stability_limit)
		var smooth: float = clampf(smoothing, 0.0, MAX_SMOOTHING)

		var laplacian := PackedFloat32Array()
		laplacian.resize(count)

		# A pinned shoreline spring is simply never integrated — it stays on the
		# resting line and the wave reflects off it. Zeroing it AFTER integrating
		# it looks the same for one frame but bleeds energy out of the band every
		# frame, and the interior wave visibly shrinks.
		var first_moving := 1 if shore_at_start else 0
		var last_moving := count - 2 if shore_at_end else count - 1
		if first_moving > last_moving:
			return

		for _pass_index in pass_count:
			# An end that is merely a cut mirrors its neighbour, so nothing
			# visibly happens at a seam that slides around with the view.
			for i in count:
				var left: float = offsets[i - 1] if i > 0 else offsets[i]
				var right: float = offsets[i + 1] if i < count - 1 else offsets[i]
				laplacian[i] = left - 2.0 * offsets[i] + right

			for i in range(first_moving, last_moving + 1):
				var local_damping := damping
				if ceiling_active:
					var excess: float = maxf(0.0, absf(offsets[i]) / calm_amplitude - 1.0)
					local_damping = minf(local_damping + overdrive_damping * excess, damping_limit)
				var acceleration := -stiffness * offsets[i] - local_damping * velocities[i] + coupling * laplacian[i]
				velocities[i] += acceleration * sub_delta

			for i in range(first_moving, last_moving + 1):
				offsets[i] += velocities[i] * sub_delta + smooth * laplacian[i]

		_conserve_volume()
		_pin_shorelines()
		_clamp_to_sane_range()

	## Hold the surface on its resting line where the water meets a wall.
	##
	## This is an ART DECISION that overrides the physics, and worth being honest
	## about. The physically correct boundary for water in a container is zero
	## flux — a free surface that sloshes UP the wall — which puts the tallest
	## crest in the whole band exactly where the water touches the block that is
	## supposed to be containing it. Real water does that. In blocky pixel art it
	## reads as the water climbing out of its own container.
	##
	## Applied after volume conservation, which would otherwise lift the pinned
	## springs straight back off the resting line.
	func _pin_shorelines() -> void:
		var count := offsets.size()
		if count <= 0:
			return
		if shore_at_start:
			offsets[0] = 0.0
			velocities[0] = 0.0
		if shore_at_end and count > 1:
			offsets[count - 1] = 0.0
			velocities[count - 1] = 0.0

	## Water is incompressible and the pool's volume is fixed by the block data,
	## so the surface as a whole cannot rise — a splash lifts water here by
	## pushing it down there.
	##
	## This is load-bearing, not a nicety. Every splash impulse is upward, and at
	## the shipped near-zero stiffness there is almost nothing pulling the mean
	## back to the resting line. Without this, each jump into a pool leaves a
	## little net upward displacement behind and the whole water body climbs,
	## jump by jump, until it hits the hard clamp. Damping cannot fix it either:
	## damping removes velocity, and only stiffness pulls offsets home.
	##
	## Removing the mean of both offset and velocity enforces zero net
	## displacement and zero net momentum. A standing wave already has both, so
	## the look is untouched.
	func _conserve_volume() -> void:
		var count := offsets.size()
		if count <= 0:
			return
		var mean_offset := 0.0
		var mean_velocity := 0.0
		for i in count:
			mean_offset += offsets[i]
			mean_velocity += velocities[i]
		mean_offset /= float(count)
		mean_velocity /= float(count)
		if is_zero_approx(mean_offset) and is_zero_approx(mean_velocity):
			return
		for i in count:
			offsets[i] -= mean_offset
			velocities[i] -= mean_velocity

	func _clamp_to_sane_range() -> void:
		for i in offsets.size():
			var offset := offsets[i]
			var velocity := velocities[i]
			if not is_finite(offset) or not is_finite(velocity):
				offsets[i] = 0.0
				velocities[i] = 0.0
				continue
			offsets[i] = clampf(offset, -MAX_OFFSET, MAX_OFFSET)
			velocities[i] = clampf(velocity, -MAX_VELOCITY, MAX_VELOCITY)
