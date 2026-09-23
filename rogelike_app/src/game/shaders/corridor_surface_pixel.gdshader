shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

// Pixel corridor texture (the M5 tiles): nearest with mipmaps.
#define SURFACE_FILTER filter_nearest_mipmap
#include "res://src/game/shaders/corridor_surface.gdshaderinc"
