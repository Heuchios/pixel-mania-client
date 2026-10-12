shader_type canvas_item;

uniform float brim_y = 0.0;
varying float hair_y;

void vertex() {
	hair_y = VERTEX.y;
}

void fragment() {
	// Local coordinates work for atlas frames, different hair canvas sizes,
	// both facing directions, and the head's movement animation.
	COLOR.a *= step(brim_y, hair_y);
}
