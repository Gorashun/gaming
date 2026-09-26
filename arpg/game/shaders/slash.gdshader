shader_type spatial;
// Melee swing arc (on a flat arc mesh). progress 0->1 sweeps then fades.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.85, 0.5, 1.0);
uniform float progress = 0.0;

void fragment() {
	float along = UV.x;       // 0..1 along arc
	float across = UV.y;      // 0 inner .. 1 outer
	float head = progress * 1.3;
	float trail = smoothstep(head - 0.6, head, along) * (1.0 - smoothstep(head, head + 0.05, along));
	float band = smoothstep(0.0, 0.5, across) * (1.0 - smoothstep(0.85, 1.0, across));
	float fade = 1.0 - smoothstep(0.7, 1.0, progress);
	ALBEDO = color.rgb * 2.0;
	ALPHA = trail * band * fade;
}
