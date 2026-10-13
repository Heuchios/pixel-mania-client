shader_type canvas_item;

// Local atlas pixels keep the reflection crisp and stable at every zoom level.
uniform vec4 atlas_region_px = vec4(0.0, 0.0, 32.0, 32.0);
varying vec4 lock_tint;

void vertex() {
	lock_tint = COLOR;
}

void fragment() {
	vec4 art = texture(TEXTURE, UV);
	vec2 pixel = floor(UV / TEXTURE_PIXEL_SIZE - atlas_region_px.xy);
	float shade = dot(art.rgb, vec3(0.299, 0.587, 0.114));
	// Keep the dark outline and keyhole; brighten only the painted surface.
	float painted = smoothstep(0.23, 0.46, shade);
	vec3 original = art.rgb * lock_tint.rgb;
	vec3 enamel = lock_tint.rgb * (0.52 + shade * 0.70);
	vec3 colour = mix(original, enamel, painted);
	float diagonal = abs(pixel.y + pixel.x * 0.65 - 24.0);
	float reflection = (1.0 - smoothstep(0.75, 3.0, diagonal)) * 0.48;
	// A second, fine reflection gives the face a polished edge.
	float fine_reflection = (1.0 - smoothstep(0.3, 0.9, abs(pixel.y + pixel.x * 0.65 - 28.0))) * 0.16;
	colour = mix(colour, vec3(1.0), (reflection + fine_reflection) * painted);
	COLOR = vec4(clamp(colour, vec3(0.0), vec3(1.0)), art.a * lock_tint.a);
}
