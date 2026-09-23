// PIPWRECK corridor surface (M6 track A step 3, ART_DIRECTION_V2 step 0).
//
// Light without lights. The Mobile and Compatibility renderers allow at most
// eight omni lights per mesh and the whole floor is ONE mesh (research 06 §1),
// so the corridor light is split in two parts, neither of which is a Light3D:
//   1. Baked into the vertex colours by CorridorMesh: a cold blue fill
//      everywhere plus warm pools around every wall torch, with distance
//      falloff. Static, costs nothing per frame.
//   2. The hand torch, here: warm light from behind the player's right
//      shoulder (a fixed point in VIEW space), inverse falloff with distance.
//      Near is warm, far falls back to the cold fill. That is the colour
//      temperature contrast the art direction asks for.
// Fog still does the depth. The filter is chosen by the including file.

uniform sampler2D albedo_tex : source_color, SURFACE_FILTER, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 hand_color : source_color = vec4(1.0, 0.56, 0.26, 1.0);
uniform float hand_energy = 1.55;
uniform float hand_range = 6.2;
// View space: +x right, -y down, +z behind the camera.
uniform vec3 hand_offset = vec3(0.7, -0.45, 0.35);
// Set per frame from a visual RNG; 0 with reduced motion.
uniform float hand_flicker = 0.0;
uniform float alpha_scissor = 0.0;

varying vec3 v_view;

void vertex() {
	v_view = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	if (t.a < alpha_scissor) {
		discard;
	}
	vec3 to_light = hand_offset - v_view;
	float d = max(length(to_light), 0.001);
	float fall = clamp(1.0 - d / hand_range, 0.0, 1.0);
	fall *= fall;
	// abs(): the walls are double sided and the normal may face away.
	float facing = abs(dot(normalize(NORMAL), to_light / d)) * 0.65 + 0.35;
	vec3 light = COLOR.rgb + hand_color.rgb * hand_energy * (1.0 + hand_flicker) * fall * facing;
	ALBEDO = t.rgb * tint.rgb * light;
}
