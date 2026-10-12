shader_type canvas_item;
render_mode unshaded;

uniform vec4 tint : source_color = vec4(0.65, 0.82, 1.0, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 p = (UV - vec2(0.5, 0.48)) * vec2(2.0, 1.025);
	float radius = length(p);
	float angle = atan(p.y, p.x + 0.00001);
	float rays = pow(max(0.0, cos(angle * 7.0 + TIME * 0.24)), 12.0);
	rays += pow(max(0.0, cos(angle * 11.0 - TIME * 0.14)), 20.0) * 0.35;
	float falloff = 1.0 - smoothstep(0.18, 0.83, radius);
	float edge = smoothstep(0.0, 0.14, UV.y) * (1.0 - smoothstep(0.82, 1.0, UV.y));
	float halo = exp(-radius * radius * 10.0) * 0.20;
	float alpha = (halo + rays * falloff * 0.20) * edge * strength;
	COLOR = vec4(mix(tint.rgb, vec3(1.0), exp(-radius * radius * 28.0) * 0.3), alpha);
}
