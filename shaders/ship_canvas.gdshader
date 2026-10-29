shader_type spatial;
// Thin cloth still casts deck shadows; skip receiving its own shadow-map acne.
render_mode cull_disabled, shadows_disabled;
#include "res://shaders/ship_surface_common.gdshaderinc"
