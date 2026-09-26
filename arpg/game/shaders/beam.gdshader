shader_type spatial;
// Loot beam / light pillar: vertical additive gradient with shimmer.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.6, 0.2, 1.0);
uniform float intensity = 1.5;

void fragment() {
	float h = UV.y;
	float fade = pow(1.0 - h, 1.6) * smoothstep(0.0, 0.05, h) ;
	float edge = 1.0 - abs(UV.x - 0.5) * 2.0;
	float shimmer = 0.75 + 0.25 * sin(TIME * 6.0 + h * 18.0);
	ALBEDO = color.rgb * intensity * shimmer;
	ALPHA = fade * edge;
}
