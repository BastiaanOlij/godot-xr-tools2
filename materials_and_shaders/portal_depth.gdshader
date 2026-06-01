shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;

uniform vec4 albedo : source_color;
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;

uniform sampler2D texture_heightmap : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform float heightmap_scale : hint_range(-16.0, 16.0, 0.001);

void vertex() {
	UV2 = UV * vec2(0.5, 1.0) + vec2(0.5, 0.0);
	UV = UV * vec2(0.5, 1.0);
}

void fragment() {
	vec2 base_uv = UV;

	{
		// Height: Enabled
		vec3 view_dir = normalize(normalize(-VERTEX + EYE_OFFSET) * mat3(TANGENT, -BINORMAL, NORMAL));
		vec4 depth_text = texture(texture_albedo, UV2);
		float depth = depth_text.r + (depth_text.b / 256.0);
		ALBEDO = depth_text.rgb;
		vec2 ofs = base_uv - view_dir.xy * depth * heightmap_scale * 0.01;
		base_uv = clamp(ofs, vec2(0.0), vec2(0.5, 1.0));
	}

	vec4 albedo_tex = texture(texture_albedo, base_uv);
	ALBEDO = albedo.rgb * albedo_tex.rgb;
}
