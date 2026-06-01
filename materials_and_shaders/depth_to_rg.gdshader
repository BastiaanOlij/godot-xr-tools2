shader_type canvas_item;

uniform sampler2D depth_texture: source_color;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Called for every pixel the material is visible on.
	float depth = texture(depth_texture, UV).r * 65536.0;
	float b = mod(depth, 256.0);
	float r = (depth - b) / 256.0;
	COLOR = vec4(r / 256.0, b / 256.0, 0.0, 1.0);
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
