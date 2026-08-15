shader_type canvas_item;
render_mode blend_mix, unshaded;

// PixelMania water body shader.
//
// The base colour is the GAME'S OWN ART, not an invented palette. The shipped
// sprites are sampled directly:
//
//   surface_tex  water_0..3.png  — the top 32px: a fully opaque crest line at
//                                  (35,151,203), a highlight row under it, then
//                                  a translucent body whose alpha ramps from 50
//                                  to 64 with depth. The four frames scroll that
//                                  crest sideways 2px at a time on an 8px period,
//                                  which is why the loop is seamless.
//   body_tex     water_block_2.png — flat (0,206,255) at alpha 64, continuing
//                                  exactly where the surface tile's ramp ends.
//
// Fed by Scripts/water_surface_manager.gd, which packs geometry into the mesh:
//   UV.x = this vertex's depth below the water surface, in 32px tiles
//   UV.y = total depth of the water column here, in tiles
//   world position comes from VERTEX, which is local space == world space
//   because the mesh node sits at the origin unscaled.
//
// Depth travels through UV and NOT through COLOR on purpose. Mesh vertex
// colours are stored as RGBA8, so anything passed through COLOR is quantised to
// 1/255 AND CLAMPED TO 1.0 — which silently capped depth at a single tile and
// made a 2px waterline render 8px thick in a 4-tile-deep pool, while every
// depth-driven effect saturated the moment the water was deeper than one tile.
// UV is float, so it carries real depths.
//
// The important trick: the surface sprite is sampled with v = depth-below-the-
// rippling-surface, not v = position-in-the-tile. So the artist's crest rides
// the wave instead of staying pinned to the tile grid, and the art is preserved
// pixel for pixel.
//
// Everything else is an OPTIONAL layer on top, and every one of them can be
// taken to zero to get back to the untouched sprite.

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;

group_uniforms game_art;
uniform sampler2D surface_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D body_tex : source_color, filter_nearest, repeat_enable;
// Scales the sprite's own alpha. 1.0 is exactly the shipped art.
uniform float art_alpha_scale : hint_range(0.0, 3.0) = 1.0;
// 0 = the whole body is the flat block texture and the only shape at the
// waterline is the rippling mesh edge itself.
// 1 = the animated water_0..3 crest is laid over the top tile, as the game
// does today. The crest is a 4px-on/4px-off dashed pattern, which reads as
// texture when it is pinned to a flat tile grid but competes with the wave
// once the surface is actually moving.
uniform float crest_frames_blend : hint_range(0.0, 1.0) = 0.0;
// A clean solid waterline, in world pixels. This is the middle ground: flat
// body, but the top edge still reads as an edge rather than fading out.
uniform vec4 edge_colour : source_color = vec4(0.137, 0.592, 0.796, 1.0);
uniform float edge_line_px : hint_range(0.0, 6.0) = 2.0;

group_uniforms depth;
uniform vec4 deep_colour : source_color = vec4(0.05, 0.42, 0.62, 1.0);
// 0.0 keeps the flat sprite colour at any depth, like the game does today.
uniform float depth_tint_strength : hint_range(0.0, 1.0) = 0.25;
uniform float depth_falloff : hint_range(0.0, 3.0) = 0.45;
// How much more opaque deep water gets than the sprite's own alpha.
uniform float depth_opacity_gain : hint_range(0.0, 1.0) = 0.18;

group_uniforms refraction;
uniform float refraction_strength : hint_range(0.0, 12.0) = 2.0;
uniform float refraction_scale : hint_range(0.1, 8.0) = 1.6;
uniform float refraction_depth_fade : hint_range(0.0, 4.0) = 0.6;

group_uniforms caustics;
uniform vec4 caustic_colour : source_color = vec4(0.65, 0.95, 1.0, 1.0);
uniform float caustic_strength : hint_range(0.0, 1.5) = 0.15;
uniform float caustic_scale : hint_range(0.2, 8.0) = 2.2;
uniform float caustic_depth_fade : hint_range(0.0, 3.0) = 0.9;

group_uniforms extra_foam;
// The sprite already draws its own crest, so this defaults off. Turn it up only
// if you want a thicker waterline than the art provides.
uniform vec4 foam_colour : source_color = vec4(0.86, 0.96, 1.0, 1.0);
uniform float foam_strength : hint_range(0.0, 1.0) = 0.0;
uniform float foam_thickness : hint_range(0.0, 16.0) = 3.0;
uniform float foam_wobble : hint_range(0.0, 4.0) = 1.2;

group_uniforms motion;
uniform float wave_speed : hint_range(0.0, 4.0) = 0.55;

group_uniforms pixel_art;
// Virtual pixel size in world pixels. 1.0 matches the 32px block art. This also
// snaps the sprite sampling, so the crest stays on whole pixels even though the
// surface it rides is a smooth curve.
uniform float pixel_size : hint_range(0.0, 8.0) = 1.0;
uniform float colour_steps : hint_range(0.0, 32.0) = 6.0;

varying vec2 v_world_px;
varying vec2 v_depth_data;

const float TILE = 32.0;

float snap(float value, float grid) {
	if (grid <= 0.001) {
		return value;
	}
	return floor(value / grid) * grid;
}

float quantise_scalar(float value, float steps) {
	if (steps <= 0.001) {
		return value;
	}
	return floor(value * steps) / steps;
}

// Cheap two-axis wave field. Deliberately sin-based rather than a noise
// texture: no extra sampler, and it stays readable at pixel-art scale.
float wave_field(vec2 p, float t) {
	float a = sin(p.x * 3.1 + t * 1.7) * 0.5;
	float b = sin(p.x * 1.7 - p.y * 2.3 - t * 1.1) * 0.3;
	float c = sin(p.y * 4.3 + t * 0.9) * 0.2;
	return a + b + c;
}

void vertex() {
	v_world_px = VERTEX;
	v_depth_data = UV;
}

void fragment() {
	float depth_tiles = max(v_depth_data.x, 0.0);
	float column_tiles = max(v_depth_data.y, 0.0);
	float t = TIME * wave_speed;

	vec2 world_px = v_world_px;
	float grid = max(pixel_size, 0.0);
	float u = snap(world_px.x, grid) / TILE;
	float depth_px = snap(depth_tiles * TILE, grid);

	vec2 p = vec2(u, snap(world_px.y, grid) / TILE);

	// ---- the shipped art --------------------------------------------------
	// The body tile carries the whole column by default. Optionally the
	// animated crest frame is blended over the top tile, indexed by depth below
	// the rippling waterline rather than by position in the tile, so it rides
	// the wave instead of staying pinned to the grid.
	vec4 art = texture(body_tex, p);
	if (crest_frames_blend > 0.001 && depth_px < TILE) {
		vec4 crest = texture(surface_tex, vec2(u, depth_px / TILE));
		art = mix(art, crest, crest_frames_blend);
	}
	art.a = clamp(art.a * art_alpha_scale, 0.0, 1.0);

	// A solid waterline so the top edge still reads as an edge when the crest
	// frames are off. Uses the art's own crest colour.
	if (edge_line_px > 0.001 && depth_px < edge_line_px && art.a > 0.0001) {
		art = vec4(edge_colour.rgb, max(art.a, edge_colour.a));
	}

	// ---- refraction of whatever sits behind the water ---------------------
	float refraction_fade = 1.0 - exp(-depth_tiles * refraction_depth_fade);
	vec2 screen_offset = vec2(
		wave_field(p * refraction_scale, t),
		wave_field(p.yx * refraction_scale, t * 0.8)
	);
	screen_offset *= refraction_strength * refraction_fade * SCREEN_PIXEL_SIZE;
	if (grid > 0.001) {
		vec2 pixel_step = SCREEN_PIXEL_SIZE * grid;
		screen_offset = floor(screen_offset / pixel_step) * pixel_step;
	}
	vec3 behind = texture(screen_tex, SCREEN_UV + screen_offset).rgb;

	// ---- optional depth grading on top of the sprite colour ---------------
	float tint = quantise_scalar(1.0 - exp(-depth_tiles * depth_falloff), colour_steps);
	vec3 water_rgb = mix(art.rgb, deep_colour.rgb, tint * depth_tint_strength);
	float alpha = clamp(art.a + tint * depth_opacity_gain * step(0.001, art.a), 0.0, 1.0);

	vec3 rgb = mix(behind, water_rgb, alpha);

	// ---- caustics ---------------------------------------------------------
	if (caustic_strength > 0.001) {
		float caustic = max(wave_field(p * caustic_scale + vec2(0.0, t * 0.4), t * 1.3), 0.0);
		caustic = pow(caustic, 3.0) * exp(-depth_tiles * caustic_depth_fade);
		caustic = quantise_scalar(caustic, colour_steps) * step(0.001, art.a);
		rgb += caustic_colour.rgb * caustic * caustic_strength;
	}

	// ---- optional extra foam ----------------------------------------------
	if (foam_strength > 0.001) {
		float wobble = wave_field(p * 2.6, t * 1.9) * foam_wobble;
		float foam = step(depth_px, foam_thickness + wobble) * step(0.0, depth_px);
		rgb = mix(rgb, foam_colour.rgb, foam * foam_strength * foam_colour.a);
		alpha = max(alpha, foam * foam_strength);
	}

	// A puddle a couple of pixels deep should not read as a solid slab.
	float thinness = clamp(column_tiles * 4.0, 0.0, 1.0);

	// `rgb` is already composited against what is behind the water, so the
	// sprite's translucency is already baked into it. The output alpha is only
	// a mask: where the art is fully transparent — the rows above the crest —
	// write nothing at all, so the refraction offset does not smear a visible
	// band into the air above the waterline.
	COLOR = vec4(rgb, step(0.0005, alpha) * thinness);
}
