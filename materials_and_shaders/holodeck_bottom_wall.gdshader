shader_type spatial;
render_mode depth_draw_opaque, cull_back, unshaded;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D texture_floor : source_color, filter_linear_mipmap, repeat_enable;

uniform float strength : hint_range(0.0, 10.0, 0.1) = 1.0;
uniform vec2 uv1_scale = vec2(1.0);
uniform vec2 uv1_offset = vec2(0.0);
uniform vec2 floor_scale = vec2(1.0);

varying vec3 world_vertex;
varying vec3 eye;
varying float fade;

void vertex() {
	world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	eye = (INV_VIEW_MATRIX * vec4(EYE_OFFSET, 1.0)).xyz;
	fade = 1.0 - UV.y;
	UV = UV * uv1_scale + uv1_offset;
}

void fragment() {
	vec4 albedo_tex = texture(texture_albedo, UV);
	ALBEDO = albedo.rgb * albedo_tex.rgb * fade * strength;

	vec3 dir = normalize(world_vertex - eye);
	if (dir.y < 0.0) {
		vec3 floor_vertex = world_vertex + (dir * (world_vertex.y / -dir.y));
		vec2 floor_uv = floor_scale * (floor_vertex.xz / vec2(50.0, 50.0) - vec2(0.5, 0.5));

		float factor = clamp((30.0 - abs(floor_vertex.x)) / 5.0, 0.0, 1.0);
		factor *= clamp((30.0 - abs(floor_vertex.z)) / 5.0, 0.0, 1.0);
		ALBEDO += texture(texture_floor, floor_uv).rgb * factor;
	}
}
