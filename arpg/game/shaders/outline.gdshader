shader_type spatial;
// Inverted-hull outline for characters and loot.
render_mode unshaded, cull_front, depth_draw_opaque;

uniform vec4 outline_color : source_color = vec4(0.04, 0.03, 0.06, 1.0);
uniform float thickness = 0.018;

void vertex() {
	VERTEX += NORMAL * thickness;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
