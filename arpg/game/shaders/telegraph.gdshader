shader_type spatial;
// Threat telegraph (Art Bible 6): solid edge + diagonal hatched fill that grows from the centre
// outwards as `fill` goes 0 -> 1, flashing brighter right before impact. Threat red only.
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.17, 0.17, 1.0);
uniform float fill = 0.0;
uniform float alpha = 1.0;
uniform float hatch_scale = 9.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) discard;
	float edge = smoothstep(0.9, 0.95, r);
	float hatch = step(0.5, fract((p.x + p.y) * hatch_scale * 0.5 - TIME * 0.8));
	float inside = 1.0 - smoothstep(fill - 0.02, fill, r);
	float front = smoothstep(fill - 0.08, fill, r) * inside;            // bright growing front
	float late = smoothstep(0.85, 1.0, fill);
	float a = edge * 0.95 + inside * (0.18 + 0.22 * hatch) + front * 0.6 + late * 0.25 * (1.0 - r);
	vec3 c = mix(color.rgb * 0.8, vec3(1.0, 0.75, 0.7), front * 0.5 + late * 0.3);
	ALBEDO = c;
	ALPHA = clamp(a * 0.4 / 0.4 * alpha, 0.0, 1.0) * mix(0.55, 1.0, edge);
}
