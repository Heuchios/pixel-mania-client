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
	// One tiny quad replaces the five layered rectangles for each pixel bulb.
	vec2 pixel = UV * 16.0;
	float edge = max(abs(pixel.x - 8.0), abs(pixel.y - 8.0));
	float glow = strength * strength * 0.15;
	if (edge < 5.0) {
		glow = 1.0 - (1.0 - glow) * (1.0 - strength * 0.22);
	}
	vec4 bulb = vec4(lamp_color.rgb, glow);
	if (edge < 4.0) {
		bulb = vec4(0.412, 0.251, 0.176, 1.0);
	}
	if (edge < 3.0) {
		bulb = vec4(mix(vec3(0.447, 0.271, 0.169), lamp_color.rgb, strength), 1.0);
	}
	if (pixel.x >= 7.0 && pixel.x < 10.0 && pixel.y >= 6.0 && pixel.y < 9.0) {
		vec3 highlight = mix(vec3(1.0, 0.902, 0.643), vec3(1.0), strength);
		bulb.rgb = mix(bulb.rgb, highlight, strength * strength);
	}
	COLOR = bulb * canvas_tint;
}
