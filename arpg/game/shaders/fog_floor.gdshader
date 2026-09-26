shader_type spatial;
// Soft drifting ground mist layer (cheap alternative to volumetric fog on mobile).
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(0.4, 0.45, 0.6, 1.0);
uniform float density = 0.35;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	float a = hash(i), b = hash(i + vec2(1, 0)), c = hash(i + vec2(0, 1)), d = hash(i + vec2(1, 1));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void fragment() {
	vec2 w = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz * 0.08;
	float n = noise(w + vec2(TIME * 0.03, TIME * 0.02)) * 0.6 + noise(w * 2.3 - vec2(TIME * 0.05, 0.0)) * 0.4;
	ALBEDO = color.rgb;
	ALPHA = clamp(n * density, 0.0, 1.0);
}
