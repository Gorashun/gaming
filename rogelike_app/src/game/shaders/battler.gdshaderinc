// PIPWRECK battler: one painted PNG as a Y-billboard in the corridor.
//
// This is palette_lut.gdshader ported to 3D (M6 track A step 2). The canvas
// version cannot run on a mesh, and SpriteBase3D ignores a custom material's
// texture, so the battler is a QuadMesh with this shader. Same knobs as the 2D
// shader (optional LUT, flash, flash_color, luma_gamma) plus what the corridor
// needs: silhouette (reveal from the dark), light_tint (baked torch light at
// the feet), a warm rim on the edge that faces the torch, tilt (the fall on
// death) and alpha (the fade).
//
// The texture filter is chosen by the including file with BATTLER_FILTER:
// battler.gdshader = linear + mipmaps (painted art, the default),
// battler_pixel.gdshader = nearest (manifest "pixel": true and old sprites).

uniform sampler2D albedo_tex : source_color, BATTLER_FILTER, repeat_disable;
// UV rect of frame 0 inside the texture: (x, y, w, h) in 0..1.
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);

uniform sampler2D palette_lut : filter_nearest, repeat_disable, source_color;
uniform float lut_strength : hint_range(0.0, 1.0) = 0.0;
uniform float luma_gamma : hint_range(0.25, 4.0) = 1.0;

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform float silhouette : hint_range(0.0, 1.0) = 0.0;
uniform vec4 silhouette_color : source_color = vec4(0.055, 0.071, 0.086, 0.92);

uniform vec4 light_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.62, 0.30, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.65;
// Where the torch is, in UV units of one frame: +x = right, -y = up.
uniform vec2 rim_offset = vec2(0.018, -0.012);

// Glow layer (M7, manifest "emissive"): RGB on black, same frame as albedo_tex.
// Added AFTER light_tint and the rim, so eyes and ember cracks glow in the dark
// corridor instead of being dimmed with the body. Hidden by the silhouette
// (beat 1 of the reveal has no colour). Breathes 0.8..1.0 over 2 s;
// emissive_pulse = 0 holds it at 1.0 (reduced motion).
uniform sampler2D emissive_tex : source_color, hint_default_black, BATTLER_FILTER, repeat_disable;
uniform float emissive_strength : hint_range(0.0, 4.0) = 0.0;
uniform float emissive_pulse : hint_range(0.0, 0.5) = 0.1;

uniform float tilt = 0.0;
uniform float alpha : hint_range(0.0, 1.0) = 1.0;

float luma(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

void vertex() {
	// Fall over around the feet, inside the billboard plane.
	float c = cos(tilt);
	float s = sin(tilt);
	VERTEX.xy = mat2(vec2(c, s), vec2(-s, c)) * VERTEX.xy;

	// Y-billboard that keeps the node scale (idle breathing tweens scale.y).
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	UV = region.xy + UV * region.zw;
}

void fragment() {
	vec4 src = texture(albedo_tex, UV);
	if (src.a < 0.01) {
		discard;
	}
	vec3 rgb = src.rgb;
	if (lut_strength > 0.0) {
		float l = clamp(pow(luma(rgb), luma_gamma), 0.0, 1.0);
		float lut_w = float(textureSize(palette_lut, 0).x);
		float u = (floor(l * (lut_w - 1.0)) + 0.5) / lut_w;
		rgb = mix(rgb, texture(palette_lut, vec2(u, 0.5)).rgb, lut_strength);
	}
	rgb *= light_tint.rgb;
	// Rim: opaque here, transparent one step toward the torch = the lit edge.
	float toward = texture(albedo_tex, UV + rim_offset * region.zw).a;
	float edge = clamp(src.a - toward, 0.0, 1.0);
	rgb += rim_color.rgb * edge * rim_strength;
	if (emissive_strength > 0.0) {
		float pulse = (1.0 - emissive_pulse) + emissive_pulse * sin(TIME * 3.14159265);
		rgb += texture(emissive_tex, UV).rgb * emissive_strength * pulse;
	}
	rgb = mix(rgb, silhouette_color.rgb, silhouette);
	rgb = mix(rgb, flash_color.rgb, flash);
	ALBEDO = rgb;
	ALPHA = src.a * alpha * mix(1.0, silhouette_color.a, silhouette);
}
