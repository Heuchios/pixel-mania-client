shader_type canvas_item;

uniform sampler2D brim_profile : filter_nearest, repeat_disable;
uniform float brim_left = 0.0;
uniform float brim_width = 1.0;
uniform vec2 hair_to_hat_x = vec2(1.0, 0.0);
uniform vec2 hair_to_hat_y = vec2(0.0, 1.0);
uniform vec2 hair_to_hat_origin = vec2(0.0);
varying vec2 hat_position;

void vertex() {
	hat_position = hair_to_hat_x * VERTEX.x + hair_to_hat_y * VERTEX.y + hair_to_hat_origin;
}

void fragment() {
	// Follow the lower edge in each pixel column, including the cap's raised
	// corners. One flat cut across the deepest brim leaves gaps at the temples.
	float u = clamp((hat_position.x - brim_left) / brim_width, 0.0, 1.0);
	float brim_y = texture(brim_profile, vec2(u, 0.5)).r;
	COLOR.a *= step(brim_y, hat_position.y);
}
