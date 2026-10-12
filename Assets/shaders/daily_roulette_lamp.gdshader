shader_type canvas_item;
render_mode unshaded;

uniform vec4 lamp_color : source_color = vec4(1.0, 0.855, 0.475, 1.0);
varying float strength;
varying vec4 canvas_tint;

void vertex() {
	strength = INSTANCE_CUSTOM.r;
	canvas_tint = COLOR;
}

void fragment() {
	// A rounded glass lens and a soft halo, still using one tiny quad per bulb.
	vec2 pixel = (UV - 0.5) * 16.0;
	float radius = length(pixel);
	float aa = max(fwidth(radius) * 0.65, 0.4);
	float bezel = 1.0 - smoothstep(3.8 - aa, 3.8 + aa, radius);
	float lens = 1.0 - smoothstep(2.9 - aa, 2.9 + aa, radius);
	float glow = (1.0 - smoothstep(2.5, 8.0, radius)) * strength * strength * 0.38;
	float center = 1.0 - smoothstep(0.0, 3.0, radius);
	float shine = 1.0 - smoothstep(0.0, 1.2, length(pixel + vec2(0.7, 0.9)));
	vec3 rim = mix(vec3(0.27, 0.14, 0.08), vec3(0.72, 0.47, 0.22), clamp(0.5 - pixel.y * 0.11, 0.0, 1.0));
	vec3 glass = mix(vec3(0.34, 0.22, 0.13), lamp_color.rgb, 0.12 + strength * 0.88);
	glass = mix(glass, vec3(1.0, 0.98, 0.90), center * strength * strength * 0.85);
	glass = mix(glass, vec3(1.0), shine * (0.15 + strength * 0.65));
	vec3 face = mix(rim, glass, lens);
	float alpha = bezel + glow * (1.0 - bezel);
	vec3 rgb = (face * bezel + lamp_color.rgb * glow * (1.0 - bezel)) / max(alpha, 0.0001);
	COLOR = vec4(rgb, alpha) * canvas_tint;
}
