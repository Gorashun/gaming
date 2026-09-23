shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// Pixel battler (manifest "pixel": true, or an old generated sprite): nearest.
#define BATTLER_FILTER filter_nearest
#include "res://src/game/shaders/battler.gdshaderinc"
