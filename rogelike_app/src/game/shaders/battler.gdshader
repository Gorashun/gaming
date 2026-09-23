shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// Painted battler: linear filtering with mipmaps. See battler.gdshaderinc.
#define BATTLER_FILTER filter_linear_mipmap
#include "res://src/game/shaders/battler.gdshaderinc"
