shader_type spatial;
render_mode depth_draw_opaque, cull_back, unshaded, depth_test_disabled, skip_vertex_transform;
stencil_mode read, compare_equal, 1;

uniform vec4 albedo : source_color;
uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, repeat_enable;

uniform vec2 uv1_scale = vec2(1.0);
uniform vec2 uv1_offset = vec2(0.0);

void vertex() {
	VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	UV.y *= 0.5;
	if (VIEW_INDEX == 1) {
		UV.y += 0.5;
	}

	UV = UV * uv1_scale + uv1_offset;
}

void fragment() {
	vec2 base_uv = UV;

	vec4 albedo_tex = texture(albedo_texture, base_uv);
	ALBEDO = albedo.rgb * albedo_tex.rgb;
	ALPHA *= albedo.a * albedo_tex.a;
}
