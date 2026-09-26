shader_type spatial;
// Ground marker under loot / portals / level-up: glow disc + ring + optional star points,
// crown notches or spinning sun rays. Shapes carry rarity meaning without colour (Art Bible 3).
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.6, 0.2, 1.0);
uniform float alpha = 1.0;
uniform float disc = 0.5;
uniform float ring = 1.0;
uniform float star_points = 0.0;   // 5 = Legendary star
uniform float rays = 0.0;          // 12 = Named sun rays
uniform float crown = 0.0;         // 5 = Unique crown notches
uniform float spin = 0.6;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) discard;
	float a = atan(p.y, p.x) + TIME * spin;
	float v = (1.0 - r) * disc * (0.8 + 0.2 * sin(TIME * 3.0));
	v += smoothstep(0.78, 0.86, r) * (1.0 - smoothstep(0.9, 0.97, r)) * ring;
	if (star_points > 0.0) {
		float sr = 0.45 + 0.3 * pow(abs(cos(a * star_points * 0.5)), 6.0);
		v += (1.0 - smoothstep(sr - 0.04, sr, r)) * smoothstep(sr - 0.12, sr - 0.04, r) * 1.2;
	}
	if (rays > 0.0) {
		float ry = pow(abs(cos(a * rays * 0.5)), 12.0) * smoothstep(0.2, 0.35, r) * (1.0 - smoothstep(0.7, 1.0, r));
		v += ry * 0.9;
	}
	if (crown > 0.0) {
		float cr = step(0.5, fract(a / 6.2831 * crown)) * smoothstep(0.62, 0.66, r) * (1.0 - smoothstep(0.72, 0.76, r));
		v += cr * 1.1;
	}
	ALBEDO = color.rgb * v * 1.4;
	ALPHA = clamp(v * alpha, 0.0, 1.0);
}
