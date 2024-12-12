// Simple unshaded texture with alpha output

shader_type spatial;
render_mode unshaded;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color,filter_linear,repeat_disable;

uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);

void vertex() {
	UV = UV * uv_scale + uv_offset;
}

void fragment() {
	vec4 albedo_tex = texture(texture_albedo,UV);
	ALBEDO = albedo.rgb * albedo_tex.rgb;
}
