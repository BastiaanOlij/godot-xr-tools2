shader_type spatial;
render_mode depth_draw_opaque, cull_back, unshaded;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform float strength : hint_range(0.0, 10.0, 0.1) = 1.0;

uniform vec2 uv1_scale = vec2(1.0);
uniform vec2 uv1_offset = vec2(0.0);

void vertex() {
	UV = UV * uv1_scale + uv1_offset;
}

void fragment() {
	vec4 albedo_tex = texture(texture_albedo, UV);
	ALBEDO = albedo.rgb * albedo_tex.rgb * strength;
}
