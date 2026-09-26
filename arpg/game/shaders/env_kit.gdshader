shader_type spatial;
// Shared environment shader for every KayKit kit mesh (MultiMesh material_override).
// One material per (atlas texture, biome) so the same kit reads as different places:
//  - palette remap: saturation / brightness / tint / hue shift (per biome "tint" block)
//  - top layer: snow, moss, ash, dust on up-facing surfaces, broken up by world-space noise
//  - camera occlusion: dithered fade where the mesh sits between camera and hero (Art Bible 7)
// GL Compatibility safe: no screen/depth textures, one texture fetch + one noise fetch.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_disabled;

uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap;
uniform float vertex_color_mix = 0.0;   // 1 for procedural meshes (vertex coloured)
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float saturation = 1.0;
uniform float brightness = 1.0;
uniform float hue_shift = 0.0;          // radians, YIQ rotation
uniform vec4 top_color : source_color = vec4(1.0);
uniform float top_amount = 0.0;         // 0 none .. 1 everything up-facing
uniform float top_scale = 0.12;         // noise frequency in 1/m
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_strength = 0.0;
uniform float ground_darken = 0.0;      // darkens low parts (fake AO at the base of walls)
uniform float occlude = 0.0;            // 1 = dither away when between camera and hero
uniform float occlude_radius = 2.4;

global uniform vec3 wick_player_pos;

varying vec3 wpos;
varying vec3 wnorm;

vec3 hue_rotate(vec3 c, float a) {
	// YIQ rotation (cheap hue shift)
	float y = dot(c, vec3(0.299, 0.587, 0.114));
	float i = dot(c, vec3(0.596, -0.274, -0.322));
	float q = dot(c, vec3(0.211, -0.523, 0.312));
	float ca = cos(a);
	float sa = sin(a);
	float i2 = i * ca - q * sa;
	float q2 = i * sa + q * ca;
	return vec3(y + 0.956 * i2 + 0.621 * q2, y - 0.272 * i2 - 0.647 * q2, y - 1.106 * i2 + 1.703 * q2);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	if (occlude > 0.5) {
		vec3 cam = CAMERA_POSITION_WORLD;
		vec3 p = wick_player_pos + vec3(0.0, 1.0, 0.0);
		vec3 ab = p - cam;
		float t = clamp(dot(wpos - cam, ab) / max(dot(ab, ab), 0.001), 0.0, 1.0);
		float d = length(wpos - (cam + ab * t));
		float fade = (1.0 - smoothstep(occlude_radius * 0.55, occlude_radius, d)) * (1.0 - smoothstep(0.9, 0.99, t));
		fade *= smoothstep(0.4, 1.4, wpos.y);          // keep the wall base: shows where the wall is
		float ign = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
		if (fade * 0.92 > ign) {
			discard;
		}
	}
	vec3 c = texture(albedo_tex, UV).rgb;
	c = mix(c, c * COLOR.rgb, vertex_color_mix);
	if (hue_shift != 0.0) {
		c = max(hue_rotate(c, hue_shift), vec3(0.0));
	}
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation) * tint.rgb * brightness;
	if (top_amount > 0.0) {
		float up = smoothstep(0.45, 0.85, wnorm.y);
		float n = texture(noise_tex, wpos.xz * top_scale).r * 0.7 + texture(noise_tex, wpos.xz * top_scale * 3.1).g * 0.3;
		float cover = smoothstep(1.0 - top_amount - 0.08, 1.0 - top_amount + 0.08, n * 0.85 + up * 0.3) * up;
		c = mix(c, top_color.rgb * (0.85 + 0.15 * n), clamp(cover, 0.0, 1.0));
	}
	if (ground_darken > 0.0) {
		c *= mix(1.0 - ground_darken, 1.0, smoothstep(0.0, 1.2, wpos.y));
	}
	ALBEDO = c;
	ROUGHNESS = 0.9;
	EMISSION = emission_color.rgb * emission_strength;
}
