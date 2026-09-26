shader_type spatial;
// Character toon shading (Art Bible 5): 3-step ramp (0.35 / 0.7 / 1.0) with soft AA edges,
// Fresnel rim in the key-light colour. Replaces the KayKit StandardMaterial on actors.
// Hit flash / threat rim stay in actor_overlay (material_overlay) so gameplay code is untouched.
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap;
uniform vec4 albedo : source_color = vec4(1.0);
uniform float ramp_dark = 0.35;
uniform float ramp_mid = 0.7;
uniform float rim_amount = 0.35;
uniform float emission_boost = 0.0;
// Class palette swaps (GDD v2 #8): recolour one hue band of the shared KayKit atlas, keeping
// its value gradient. swap_*.x = hue centre, .y = half width, .z = min saturation.
uniform vec3 swap_a = vec3(0.0, 0.0, 2.0);
uniform vec4 swap_a_color : source_color = vec4(1.0);
uniform vec3 swap_b = vec3(0.0, 0.0, 2.0);
uniform vec4 swap_b_color : source_color = vec4(1.0);

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

vec3 swap(vec3 c, vec3 hsv, vec3 band, vec3 target) {
	float dh = abs(fract(hsv.x - band.x + 0.5) - 0.5);
	float w = (1.0 - smoothstep(band.y * 0.7, band.y, dh)) * smoothstep(band.z - 0.05, band.z + 0.05, hsv.y);
	return mix(c, target * (0.45 + hsv.z * 0.9), w);
}

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb * albedo.rgb;
	if (swap_a.z < 1.5 || swap_b.z < 1.5) {
		vec3 hsv = rgb2hsv(c);
		c = swap(c, hsv, swap_a, swap_a_color.rgb);
		c = swap(c, hsv, swap_b, swap_b_color.rgb);
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	EMISSION = c * emission_boost;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float a = fwidth(ndl) * 1.5 + 0.02;
	float r = mix(ramp_dark, ramp_mid, smoothstep(-0.15 - a, -0.15 + a, ndl));
	r = mix(r, 1.0, smoothstep(0.45 - a, 0.45 + a, ndl));
	DIFFUSE_LIGHT += r * ATTENUATION * LIGHT_COLOR / PI;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * rim_amount;
	DIFFUSE_LIGHT += rim * smoothstep(-0.2, 0.4, ndl) * ATTENUATION * LIGHT_COLOR / PI;
}
