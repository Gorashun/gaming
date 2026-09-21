shader_type canvas_item;
render_mode blend_mix, unshaded;

// PIPWRECK chalk shader - visual direction A "KRITGROPEN".
//
// The whole handmade identity of the UI layer sits in this one shader
// (UI_GUIDE section 1A). Three effects, in this order:
//   1. UV jitter from value noise   -> shaky, hand drawn edges
//   2. grain multiply               -> the tooth of the slate
//   3. alpha erosion                -> broken chalk coverage, dust at the ends
//
// Put this on ChalkUI CanvasLayer nodes only (Line2D, Polygon2D, labels with
// an outline material). Never on the World layer: it would blur pixel art.
//
// Reduced motion (UI_GUIDE section 6.1): set jitter_speed = 0.0. The look is
// preserved, the movement is not.
//
// Preview: design/shader_preview_chalk.tscn

// --- Jitter ---------------------------------------------------------------
// Offset in UV units. 0.006 on a 400 px wide line is about 2.4 px of wobble.
uniform float jitter_amount : hint_range(0.0, 0.05) = 0.006;
uniform float jitter_scale : hint_range(1.0, 64.0) = 14.0;
uniform float jitter_speed : hint_range(0.0, 8.0) = 1.4;

// --- Grain ----------------------------------------------------------------
uniform float grain_amount : hint_range(0.0, 1.0) = 0.35;
uniform float grain_scale : hint_range(8.0, 512.0) = 180.0;

// --- Erosion --------------------------------------------------------------
// How much of the stroke is eaten away. 0 = solid, 1 = barely there.
uniform float erosion : hint_range(0.0, 1.0) = 0.28;
uniform float erosion_scale : hint_range(8.0, 512.0) = 90.0;
// Erosion is stronger near the edges of the stroke, like real chalk.
uniform float edge_bias : hint_range(0.0, 1.0) = 0.6;

// --- Colour ---------------------------------------------------------------
uniform vec4 chalk_color : source_color = vec4(0.949, 0.929, 0.890, 1.0); // chalk/100
uniform float tint_strength : hint_range(0.0, 1.0) = 0.0;

// Wipe used by round_end (UI_GUIDE 5.7): 0 = drawn, 1 = wiped away, sweeping
// left to right and leaving smear at the trailing edge.
uniform float wipe : hint_range(0.0, 1.0) = 0.0;
uniform float wipe_softness : hint_range(0.01, 0.5) = 0.18;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	// 1. jitter: two noise lookups at different phases so x and y wobble
	//    independently, otherwise the whole stroke just slides diagonally.
	float t = TIME * jitter_speed;
	vec2 jitter = vec2(
		value_noise(UV * jitter_scale + vec2(t, 0.0)) - 0.5,
		value_noise(UV * jitter_scale + vec2(0.0, t) + 31.7) - 0.5
	) * 2.0 * jitter_amount;

	vec4 src = texture(TEXTURE, UV + jitter);

	// 2. grain: multiplicative, never additive. Additive grain lifts the black
	//    and kills the 14:1 contrast the direction is built on.
	float grain = value_noise(UV * grain_scale);
	float tooth = mix(1.0, 0.55 + grain * 0.75, grain_amount);

	// 3. erosion: break the coverage, harder near the alpha edge.
	float speck = value_noise(UV * erosion_scale + 7.13);
	float edge = 1.0 - smoothstep(0.0, 0.5, src.a);
	float eat = erosion * mix(1.0, 0.35 + edge, edge_bias);
	float alpha = src.a * smoothstep(eat * 0.9, eat * 0.9 + 0.35, speck * 0.6 + 0.5);

	// squeegee wipe, left to right, with a smeared trailing edge
	float wipe_edge = smoothstep(wipe - wipe_softness, wipe + wipe_softness, UV.x);
	float smear = mix(1.0, 0.25 + speck * 0.5, 1.0 - wipe_edge);
	alpha *= mix(0.0, 1.0, wipe_edge) * smear + (1.0 - wipe_edge) * speck * 0.12;

	vec3 rgb = mix(src.rgb, chalk_color.rgb, tint_strength) * tooth;

	COLOR = vec4(rgb, alpha) * COLOR;
}
