// The unlit PSX material: screens, lamps, signage and anything that glows by itself. Drawn at its
// texture's colour regardless of light, still snapped (psx.gdshaderinc).
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

#include "res://game/rendering/psx.gdshaderinc"

uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable, hint_default_white;
uniform vec4 albedo : source_color = vec4(1.0);
uniform float energy = 1.0;
uniform float affine_amount : hint_range(0.0, 1.0) = 1.0;

varying vec4 affine_uv;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	affine_uv = psx_affine(vec3(UV, 0.0), clip);
	POSITION = IN_SHADOW_PASS ? clip : psx_snap(clip, VIEWPORT_SIZE);
}

void fragment() {
	vec2 uv = mix(UV, affine_uv.xy / affine_uv.w, affine_amount * psx_affine_amount);
	ALBEDO = albedo.rgb * texture(albedo_texture, uv).rgb * energy;
}
