shader_type spatial;
// Enemy projectile (Art Bible 6): round blob, dark core, threat-red rim. Never bright inside.
render_mode blend_mix, unshaded, cull_back, shadows_disabled, fog_disabled;

uniform vec4 rim_color : source_color = vec4(1.0, 0.17, 0.17, 1.0);
uniform vec4 core_color : source_color = vec4(0.08, 0.02, 0.04, 1.0);

void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.6);
	float flick = 0.85 + 0.15 * sin(TIME * 20.0);
	ALBEDO = mix(core_color.rgb, rim_color.rgb * 1.6 * flick, f);
}
