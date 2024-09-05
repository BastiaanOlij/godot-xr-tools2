shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_front, unshaded;

uniform vec4 albedo : source_color = vec4(0.7, 0.7, 0.0, 1.0);
uniform float grow : hint_range(-16.0, 16.0, 0.001) = 0.01;

void vertex() {
	// Standard grow along the normal will create seams
	vec3 scale = vec3(
		grow / length(MODEL_MATRIX[0].xyz),
		grow / length(MODEL_MATRIX[1].xyz),
		grow / length(MODEL_MATRIX[2].xyz)
	);
	VERTEX += NORMAL * scale;
}

void fragment() {
	ALBEDO = albedo.rgb;
}
