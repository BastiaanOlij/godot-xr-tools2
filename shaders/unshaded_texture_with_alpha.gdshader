// Simple unshaded texture with alpha output

shader_type spatial;
render_mode unshaded;

uniform sampler2D texture_albedo : source_color,filter_linear_mipmap,repeat_enable;

void fragment() {
	vec4 albedo_tex = texture(texture_albedo,UV);
	ALBEDO = albedo_tex.rgb;
	ALPHA = albedo_tex.a;
}
