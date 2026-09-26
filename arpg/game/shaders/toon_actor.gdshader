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

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb * albedo.rgb;
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
