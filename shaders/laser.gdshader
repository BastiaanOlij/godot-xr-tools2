shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 albedo : source_color = vec4(1.0, 0.0, 0.0, 1.0);

void fragment() {
	ALBEDO = albedo.rgb;
	ALPHA = clamp(UV.y, 0.0, 0.5);
}
