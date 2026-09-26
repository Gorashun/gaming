shader_type spatial;
// Portal / hush-tear vortex on a quad: spiral noise arms, bright rim, dark eye.
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(0.55, 0.75, 1.0, 1.0);
uniform vec4 eye_color : source_color = vec4(0.02, 0.02, 0.06, 1.0);
uniform float speed = 1.0;
uniform float alpha = 1.0;
uniform float stretch = 1.0;       // >1 = tall tear shape
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y /= stretch;
	float r = length(p);
	if (r > 1.0) discard;
	float a = atan(p.y, p.x);
	float sp = a / 6.2831 + r * 0.9 - TIME * 0.25 * speed;
	float n = texture(noise_tex, vec2(sp, r * 0.5 - TIME * 0.1 * speed)).r;
	float arms = smoothstep(0.35, 0.75, sin(sp * 6.2831 * 3.0) * 0.5 + 0.5 + (n - 0.5) * 0.8);
	float rim = smoothstep(0.7, 0.95, r) * (1.0 - smoothstep(0.95, 1.0, r));
	float eye = 1.0 - smoothstep(0.0, 0.45, r);
	vec3 c = mix(color.rgb * (0.4 + arms * 1.4), eye_color.rgb, eye * 0.85) + color.rgb * rim * 1.8;
	ALBEDO = c;
	ALPHA = clamp((0.75 + rim) * (1.0 - smoothstep(0.97, 1.0, r)) * alpha, 0.0, 1.0);
}
