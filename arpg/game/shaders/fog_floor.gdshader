shader_type spatial;
// Soft drifting ground mist layer (cheap alternative to volumetric fog on mobile).
// Two scrolling noise fetches; thins out near the hero so the ground under the player reads.
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(0.4, 0.45, 0.6, 1.0);
uniform float density = 0.35;
uniform float scale = 0.05;
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
global uniform vec3 wick_player_pos;

void fragment() {
	vec3 w = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 uv = w.xz * scale;
	float n = texture(noise_tex, uv + vec2(TIME * 0.012, TIME * 0.008)).r * 0.6
		+ texture(noise_tex, uv * 2.3 - vec2(TIME * 0.02, 0.0)).g * 0.4;
	n = smoothstep(0.3, 0.85, n);
	float clear = smoothstep(1.5, 4.5, length(w.xz - wick_player_pos.xz));
	ALBEDO = color.rgb;
	ALPHA = clamp(n * density * (0.35 + 0.65 * clear), 0.0, 1.0);
}
