shader_type spatial;
// Overlay on top of actor meshes: rim light (readability on dark ground) + hit flash + tint.
render_mode blend_add, unshaded, cull_back, depth_draw_never;

uniform vec4 rim_color : source_color = vec4(0.55, 0.6, 0.9, 1.0);
uniform float rim_strength = 0.35;
uniform float rim_power = 3.0;
uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power) * rim_strength;
	ALBEDO = rim_color.rgb * rim + flash_color.rgb * flash * 0.45;   // hit flash reads without white-out
	ALPHA = 1.0;
}
