shader_type spatial;
render_mode unshaded, cull_disabled, skip_vertex_transform;

uniform float arc_length = 5.0;
uniform vec4 albedo_color : source_color = vec4(0.0, 1.0, 0.0, 1.0);
uniform sampler2D albedo_texture : source_color;

void vertex() {
	// offset our Z so we're projecting from our origin point
	VERTEX.z -= 0.5;

	// Arch
	float y_offset = sin(-VERTEX.z * PI) * 0.2;

	// Adjust our length
	VERTEX.z *= arc_length;

	// translate to our world vector
	VERTEX = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; 

	VERTEX.y += y_offset;

	// and apply our view matrix
	VERTEX = (VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float offset = (TIME * 2.0);
	vec4 col = texture(albedo_texture, vec2(UV.x, (UV.y * arc_length * 4.0) + offset));
	ALBEDO = col.rgb * albedo_color.rgb;
	ALPHA = col.a * (1.0 - UV.y);
}
