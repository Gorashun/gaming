shader_type spatial;
// Procedural crystals / ice shards / glow fungus: faceted, self-lit, fresnel edge glow.
// Emission is bounded so glow stays a halo, never a white-out (Art Bible 1: env <= 60 % sat).
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.55, 0.75, 0.9, 1.0);
uniform vec4 glow_color : source_color = vec4(0.8, 0.95, 1.0, 1.0);
uniform float glow = 1.2;
uniform float pulse = 0.25;
uniform float rim_power = 2.0;

varying float vy;
varying vec3 wp;

void vertex() {
	vy = VERTEX.y;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	float p = 1.0 + pulse * sin(TIME * 1.7 + wp.x * 0.7 + wp.z * 0.9);
	float tipglow = clamp(vy * 0.8, 0.0, 1.0);
	ALBEDO = base_color.rgb * (0.55 + 0.45 * COLOR.r);
	ROUGHNESS = 0.25;
	SPECULAR = 0.6;
	EMISSION = glow_color.rgb * glow * p * (0.25 + 0.55 * tipglow + 0.8 * fres) * COLOR.r;
}
