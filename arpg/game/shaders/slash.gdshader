shader_type spatial;
// Melee swing arc (on a flat arc mesh). progress 0->1 sweeps then fades.
// Hot white leading edge, element-tinted body, soft inner falloff.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.85, 0.5, 1.0);
uniform float progress = 0.0;
uniform float intensity = 1.1;
uniform float opacity = 0.7;

void fragment() {
	float along = UV.x;
	float across = UV.y;       // 0 inner .. 1 outer
	float head = progress * 1.35;
	float behind = head - along;
	float trail = smoothstep(0.65, 0.0, behind) * step(0.0, behind + 0.03);
	float band = smoothstep(0.05, 0.7, across) * (1.0 - smoothstep(0.9, 1.0, across));
	float fade = 1.0 - smoothstep(0.65, 1.0, progress);
	float hot = smoothstep(0.12, 0.0, abs(behind)) * smoothstep(0.55, 0.95, across);
	vec3 c = color.rgb * intensity * (0.6 + 0.6 * across) + color.rgb * hot * 0.5 + vec3(0.25) * hot;
	ALBEDO = c;
	ALPHA = clamp((trail * band + hot * 0.6) * fade * opacity, 0.0, 1.0);
}
