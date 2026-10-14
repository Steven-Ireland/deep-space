// PSX glass: windows and viewports. A faint tinted pane with a hard specular glint, snapped like
// everything else (psx.gdshaderinc), so the view beyond reads clearly but the glass is there.
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque, diffuse_lambert, specular_schlick_ggx;

#include "res://game/rendering/psx.gdshaderinc"

uniform vec4 tint : source_color = vec4(0.55, 0.7, 0.78, 0.1);
uniform float roughness : hint_range(0.0, 1.0) = 0.1;

varying vec4 psx_xy;
varying float psx_w;
void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	POSITION = IN_SHADOW_PASS ? clip : psx_snap(clip, VIEWPORT_SIZE);
	psx_xy = vec4(clip.xy, POSITION.xy);
	psx_w = clip.w;
}

void fragment() {
	DEPTH = IN_SHADOW_PASS ? FRAGCOORD.z : psx_true_depth(VERTEX, psx_xy, psx_w, PROJECTION_MATRIX);
	ALBEDO = tint.rgb;
	ALPHA = tint.a;
	ROUGHNESS = roughness;
	SPECULAR = 0.8;
}
