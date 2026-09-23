shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

// Painted corridor texture: linear filtering with mipmaps.
#define SURFACE_FILTER filter_linear_mipmap
#include "res://src/game/shaders/corridor_surface.gdshaderinc"
