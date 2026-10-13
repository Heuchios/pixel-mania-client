shader_type canvas_item;

uniform bool left_half = true;
varying float collar_x;

void vertex() {
	collar_x = VERTEX.x;
}

void fragment() {
	// Clip geometry at the centered collar canvas, independent of atlas UVs.
	if ((left_half && collar_x >= 0.0) || (!left_half && collar_x < 0.0)) {
		discard;
	}
}
