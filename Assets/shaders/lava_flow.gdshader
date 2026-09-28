shader_type canvas_item;
render_mode unshaded;

// Animate the existing pixel art inside its atlas cell. The block silhouette
// and collision boundaries remain fixed; neighbouring atlas art is never read.
uniform vec4 atlas_region_px = vec4(0.0, 0.0, 32.0, 32.0);
uniform float flow_speed = 0.65;
varying vec2 world_px;
varying vec4 sprite_modulate;

void vertex() {
	world_px = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	sprite_modulate = COLOR;
}

void fragment() {
	vec2 cell_px = UV / TEXTURE_PIXEL_SIZE - atlas_region_px.xy;
	vec2 edge = min(cell_px, atlas_region_px.zw - cell_px);
	float interior = smoothstep(0.5, 4.0, min(edge.x, edge.y));
	float t = TIME * flow_speed;
	vec2 flow = vec2(
		sin(world_px.y * 0.16 + t) + sin(world_px.x * 0.09 - t * 0.7) * 0.45,
		cos(world_px.x * 0.13 + t * 0.8) * 0.8
	) * interior;
	vec2 sample_px = clamp(floor(cell_px + flow) + vec2(0.5), vec2(0.5), atlas_region_px.zw - vec2(0.5));
	vec4 art = texture(TEXTURE, (atlas_region_px.xy + sample_px) * TEXTURE_PIXEL_SIZE);
	// A world-space heat field keeps adjacent tiles from pulsing in lockstep.
	float heat = sin(world_px.x * 0.085 + world_px.y * 0.11 - t * 1.3) * 0.5
		+ sin(world_px.y * 0.19 + t * 0.6) * 0.5;
	art.rgb *= 1.0 + heat * 0.07;
	art.g = clamp(art.g + heat * 0.035, 0.0, 1.0);
	art.a = texture(TEXTURE, UV).a;
	COLOR = art * sprite_modulate;
}
