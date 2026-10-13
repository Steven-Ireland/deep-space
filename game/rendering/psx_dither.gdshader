// The window's 3D as the PlayStation showed it (Psx): already drawn at its few pixels and shown
// big, each `pixel` screen pixels square, here cut to 15-bit colour with a 4x4 dither
// (psx_dither()) before anything 2D is drawn over it.
shader_type canvas_item;

#include "res://game/rendering/psx.gdshaderinc"

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float pixel = 1.0;

void fragment() {
	COLOR = vec4(psx_dither(texture(screen, SCREEN_UV).rgb, floor(FRAGCOORD.xy / pixel)), 1.0);
}
