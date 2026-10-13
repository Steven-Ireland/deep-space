// A planet seen from orbit (GDD §14): a low-poly sphere with a banded or blotched surface in its
// three colours, posterized like a PSX texture, a soft terminator, and an atmosphere rim lit on
// the sun's side. Snapped to pixels like everything else.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_back;

#include "res://game/rendering/psx.gdshaderinc"
#include "res://game/space/noise.gdshaderinc"

uniform vec4 colour_a : source_color = vec4(0.5, 0.35, 0.25, 1.0);
uniform vec4 colour_b : source_color = vec4(0.8, 0.65, 0.45, 1.0);
uniform vec4 colour_c : source_color = vec4(0.95, 0.9, 0.8, 1.0);
uniform float banded : hint_range(0.0, 1.0) = 1.0; // 1 a gas giant's bands, 0 a rocky world's blotches
uniform float bands = 7.0;
uniform float turbulence = 0.5;
uniform float detail = 3.0;
uniform float seed = 0.0;
uniform vec4 atmosphere : source_color = vec4(0.6, 0.75, 1.0, 1.0);
uniform float atmosphere_strength = 0.6;
uniform float levels = 6.0; // colour steps, for the posterized PSX look

varying vec3 surface;

void vertex() {
	surface = normalize(VERTEX);
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	POSITION = IN_SHADOW_PASS ? clip : psx_snap(clip, VIEWPORT_SIZE);
}

void fragment() {
	vec3 p = normalize(surface);
	float n = ds_fbm(p * detail + vec3(seed * 7.1), 5);
	float stripes = sin((p.y + (n - 0.5) * turbulence) * bands * 3.14159) * 0.5 + 0.5;
	float v = mix(n, stripes * 0.75 + n * 0.25, banded);
	v = floor(clamp(v, 0.0, 0.999) * levels) / (levels - 1.0);
	vec3 c = v < 0.5 ? mix(colour_a.rgb, colour_b.rgb, v * 2.0) : mix(colour_b.rgb, colour_c.rgb, (v - 0.5) * 2.0);
	ALBEDO = c;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(-0.12, 0.3, ndl);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * lit;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	SPECULAR_LIGHT += atmosphere.rgb * LIGHT_COLOR * rim * atmosphere_strength * smoothstep(-0.3, 0.4, ndl);
}
