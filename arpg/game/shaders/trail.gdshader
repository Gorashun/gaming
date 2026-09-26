shader_type spatial;
// Ribbon trail (projectiles, dash, leap, souls). Vertex colour carries per-vertex alpha,
// UV.x = age (0 head .. 1 tail), UV.y = across.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.8, 0.5, 1.0);
uniform float intensity = 1.6;
uniform float core = 0.6;

void fragment() {
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);
	float head = 1.0 - UV.x;
	vec3 c = color.rgb * intensity + vec3(1.0) * core * pow(across, 4.0) * head;
	ALBEDO = c;
	ALPHA = clamp(COLOR.a * pow(across, 1.5) * head, 0.0, 1.0);
}
