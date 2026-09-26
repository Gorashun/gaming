shader_type spatial;
// Persistent ground zone (consecrate, fire trap, frost field, poison). Same uniforms as
// ground_ring.gdshader so GroundZone's own fade keeps working when Fx swaps the shader in.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.6, 0.2, 1.0);
uniform float fill = 1.0;
uniform float ring_width = 0.12;
uniform float alpha = 1.0;
uniform float pulse = 0.5;
uniform float swirl = 0.4;
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) discard;
	float a = atan(p.y, p.x);
	vec2 q = vec2(a / 6.2831 + TIME * 0.05 * swirl + r * 0.3, r * 0.8 - TIME * 0.12);
	float n = texture(noise_tex, q).r;
	float n2 = texture(noise_tex, p * 0.6 + vec2(TIME * 0.03, -TIME * 0.02)).g;
	float edge = smoothstep(1.0 - ring_width, 1.0 - ring_width * 0.4, r) * (1.0 - smoothstep(0.96, 1.0, r));
	float body = (1.0 - smoothstep(0.2, 1.0, r)) * 0.25 + smoothstep(0.45, 0.8, n * n2 * 1.6) * 0.5 * (1.0 - r * 0.6);
	float p2 = 1.0 + pulse * 0.25 * sin(TIME * 4.0);
	ALBEDO = color.rgb * (edge * 1.6 + body) * p2;
	ALPHA = clamp((edge + body) * alpha, 0.0, 1.0);
}
