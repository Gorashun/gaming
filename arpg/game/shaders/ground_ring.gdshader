shader_type spatial;
// Flat ring / disc on the ground: telegraphs, auras, selection, AoE flashes.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.2, 0.1, 1.0);
uniform float fill = 0.0;       // 0..1 telegraph charge
uniform float ring_width = 0.08;
uniform float alpha = 1.0;
uniform float pulse = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) discard;
	float ring = smoothstep(1.0 - ring_width, 1.0 - ring_width * 0.5, r) * (1.0 - smoothstep(0.97, 1.0, r));
	float inner = step(r, fill) * 0.35;
	float glow = (1.0 - r) * 0.15;
	float p2 = 1.0 + pulse * 0.3 * sin(TIME * 8.0);
	ALBEDO = color.rgb * (ring * 1.6 + inner + glow) * p2;
	ALPHA = clamp((ring + inner + glow) * alpha, 0.0, 1.0);
}
