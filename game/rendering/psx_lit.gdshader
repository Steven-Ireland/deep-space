// The lit PSX material every model uses (assets/materials/*.tres, assigned on import): its
// texture unfiltered, corners snapped to pixels (psx.gdshaderinc), tinted by
// the vertex colours the Blender pipeline bakes ambient occlusion into.
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx, cull_back;

#include "res://game/rendering/psx.gdshaderinc"

uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable, hint_default_white;
uniform vec4 albedo : source_color = vec4(1.0);
// How much the vertex colours (baked AO and tint) darken the texture.
uniform float vertex_color_amount : hint_range(0.0, 1.0) = 1.0;
// 1 for full PlayStation swim, when psx_affine_amount is on; lower for big triangles that warp too far.
uniform float affine_amount : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D emission_texture : source_color, filter_nearest, repeat_enable, hint_default_black;
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 1.0;
// Tints what glows (the LANTERN's ceiling fixtures go red for a jump).
uniform vec3 emission_tint : source_color = vec3(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.85;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float specular : hint_range(0.0, 1.0) = 0.3;
uniform float alpha_scissor : hint_range(0.0, 1.0) = 0.0;

varying vec4 affine_uv;
varying vec4 psx_xy;
varying float psx_w;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	affine_uv = psx_affine(vec3(UV, 0.0), clip);
	POSITION = IN_SHADOW_PASS ? clip : psx_snap(clip, VIEWPORT_SIZE);
	psx_xy = vec4(clip.xy, POSITION.xy);
	psx_w = clip.w;
}

void fragment() {
	DEPTH = IN_SHADOW_PASS ? FRAGCOORD.z : psx_true_depth(VERTEX, psx_xy, psx_w, PROJECTION_MATRIX);
	vec2 uv = mix(UV, affine_uv.xy / affine_uv.w, affine_amount * psx_affine_amount);
	vec4 tex = texture(albedo_texture, uv);
	vec3 tint = mix(vec3(1.0), COLOR.rgb, vertex_color_amount);
	ALBEDO = albedo.rgb * tex.rgb * tint;
	if (alpha_scissor > 0.0 && tex.a * albedo.a < alpha_scissor) {
		discard;
	}
	EMISSION = (emission.rgb + texture(emission_texture, uv).rgb) * emission_energy * emission_tint;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = specular;
}
