shader_type canvas_item;
render_mode blend_mix, unshaded;

// PIPWRECK palette LUT.
//
// Two jobs, one shader (research 04, recommendation 5):
//   1. Dice materials: one grayscale die body becomes iron / bone / glass by
//      swapping the 16x1 LUT texture. 1 body + 3 LUTs instead of 3 bodies.
//   2. Style unification: every imported third party sprite is forced through
//      lut_world.png so three different CC0 sources cannot drift apart.
//
// The LUT is a 16x1 PNG sampled at u = luminance(source). filter_nearest on
// both the LUT and the source keeps pixel edges hard.
//
// Used by: assets/sprites/dice/lut_{iron,bone,glass}.png, lut_world.png
// Preview: design/shader_preview_palette.tscn

uniform sampler2D palette_lut : filter_nearest, repeat_disable, source_color;

// 0.0 = original sprite, 1.0 = fully remapped. Tween this for a material
// change (forge, relic pickup) instead of swapping the texture.
uniform float lut_strength : hint_range(0.0, 1.0) = 1.0;

// Material tint, multiplied after the LUT. Keep near white for the base
// materials; this is the knob for "same die, hotter" states.
uniform vec4 material_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Pushes luminance before the lookup. > 1.0 spreads the ramp toward the
// highlights, < 1.0 toward the shadows.
uniform float luma_gamma : hint_range(0.25, 4.0) = 1.0;

// Flat brightening used by the hit flash. Applied last so it never changes
// which LUT step a pixel lands on.
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

float luma(vec3 c) {
	// Rec. 709 weights. The world palette ramp is built on these values, so
	// changing them means regenerating the LUTs in tools/gen_dice_sprites.py.
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);

	// Fully transparent pixels must stay fully transparent: the outline pass
	// in the generators relies on a clean alpha edge.
	if (src.a < 0.004) {
		discard;
	}

	float l = clamp(pow(luma(src.rgb), luma_gamma), 0.0, 1.0);

	// Sample the middle of the LUT texel so filter_nearest is unambiguous.
	float lut_w = float(textureSize(palette_lut, 0).x);
	float u = (floor(l * (lut_w - 1.0)) + 0.5) / lut_w;
	vec3 mapped = texture(palette_lut, vec2(u, 0.5)).rgb;

	vec3 rgb = mix(src.rgb, mapped, lut_strength) * material_tint.rgb;
	rgb = mix(rgb, flash_color.rgb, flash);

	COLOR = vec4(rgb, src.a * material_tint.a) * COLOR;
}
