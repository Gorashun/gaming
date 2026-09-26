shader_type spatial;
// Loot beam / light pillar on an open cylinder: bright core, soft edges, rising streaks.
// Unshaded, additive, fog-disabled (Art Bible 3). `core` adds a white centre (Mythic),
// `pulse` breathes the whole beam (Mythic / Named).
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.6, 0.2, 1.0);
uniform float intensity = 1.5;
uniform float core = 0.0;
uniform float pulse = 0.0;
uniform float streaks = 1.0;
uniform float alpha = 1.0;

void fragment() {
	float h = UV.y;                         // 0 top .. 1 bottom on CylinderMesh
	float up = 1.0 - h;
	float fade = pow(h, 1.5) * smoothstep(0.0, 0.04, 1.0 - h);
	// Edge-on (silhouette) = thin, facing = core: use view angle for a volumetric look
	float facing = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float body = pow(facing, 2.0);
	float s = 0.65 + 0.35 * sin((up * 10.0 - TIME * 3.0) + sin(UV.x * 6.2831 * 3.0) * 1.5) * streaks;
	float p = 1.0 + pulse * (0.35 * sin(TIME * 5.0));
	vec3 c = color.rgb * intensity * s * p + vec3(1.0) * core * pow(facing, 6.0);
	ALBEDO = c;
	ALPHA = clamp(fade * body * alpha, 0.0, 1.0);
}
