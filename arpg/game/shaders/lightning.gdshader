shader_type spatial;
// Chain-lightning ribbon: flickering white core, element-coloured glow edges.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(0.8, 0.9, 1.0, 1.0);
uniform float alpha = 1.0;

void fragment() {
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);
	float flick = step(0.25, fract(sin(floor(TIME * 30.0) * 12.9898) * 43758.5453));
	vec3 c = color.rgb * 1.5 * across + vec3(1.0) * pow(across, 8.0) * 2.0;
	ALBEDO = c;
	ALPHA = clamp(pow(across, 1.2) * alpha * (0.6 + 0.4 * flick), 0.0, 1.0);
}
