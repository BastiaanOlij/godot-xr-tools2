// Simple unshaded color with alpha output

shader_type spatial;
render_mode unshaded;

uniform vec4 albedo : source_color = vec4(1.0);

void fragment() {
	ALBEDO = albedo.rgb;
}
