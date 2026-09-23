shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;

// PIPWRECK world grade (M6 track A step 3, ART_DIRECTION_V2 §4 "vinjett +
// smuts, alltid på"). One quad over the corridor, under every UI element.
//
// Premultiplied output does two jobs in one pass:
//   alpha  darkens toward the void colour (vignette, static grain),
//   rgb    adds light (the warm spill of the hand torch from the bottom right,
//          a faint cold cast top left: colour temperature contrast).
// No SCREEN_TEXTURE read: a screen copy is the expensive thing on mobile.

uniform vec4 void_color : source_color = vec4(0.027, 0.035, 0.043, 1.0);
uniform float vignette : hint_range(0.0, 1.0) = 0.82;
uniform float inner : hint_range(0.0, 1.5) = 0.3;
uniform float outer : hint_range(0.5, 2.5) = 1.35;
// Extra dark at the top (the ceiling vanishes) and the bottom edge (the seam
// to the UI below must never read as a line).
uniform float top_dark : hint_range(0.0, 1.0) = 0.35;
uniform float bottom_dark : hint_range(0.0, 1.0) = 0.55;

uniform vec4 glow_color : source_color = vec4(1.0, 0.52, 0.2, 1.0);
uniform vec2 glow_center = vec2(0.80, 1.06);
uniform vec2 glow_radius = vec2(0.85, 0.62);
uniform float glow_strength : hint_range(0.0, 1.0) = 0.2;

uniform vec4 cool_color : source_color = vec4(0.30, 0.42, 0.62, 1.0);
uniform float cool_strength : hint_range(0.0, 1.0) = 0.05;

uniform float grain : hint_range(0.0, 0.3) = 0.07;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float d = length((uv - 0.5) * vec2(2.0, 1.7));
	float a = smoothstep(inner, outer, d) * vignette;
	a = max(a, smoothstep(0.22, 0.0, uv.y) * top_dark);
	a = max(a, smoothstep(0.86, 1.0, uv.y) * bottom_dark);

	// Static grain: 2 px cells, never animated (reduced motion needs nothing).
	float n = hash(floor(FRAGCOORD.xy * 0.5)) * 2.0 - 1.0;
	a = clamp(a + max(n, 0.0) * grain, 0.0, 1.0);

	float g = clamp(1.0 - length((uv - glow_center) / glow_radius), 0.0, 1.0);
	float c = clamp(1.0 - length((uv - vec2(0.08, -0.05)) / vec2(0.9, 0.75)), 0.0, 1.0);
	vec3 add = glow_color.rgb * g * g * glow_strength + cool_color.rgb * c * c * cool_strength;
	add += vec3(max(-n, 0.0) * grain * 0.25);

	COLOR = vec4(void_color.rgb * a + add, a);
}
