// A CRT's face (GDD §10): the terminal's SubViewport shown unfiltered, with scanlines, a soft
// vignette toward the curved edges, and phosphor glow; snapped to pixels like everything else.
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

#include "res://game/rendering/psx.gdshaderinc"

uniform sampler2D screen : source_color, filter_nearest;
uniform float brightness = 1.6;
uniform float scanlines = 0.35;
uniform float lines = 240.0;
uniform vec3 glass : source_color = vec3(0.03, 0.045, 0.04);
uniform float power : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	POSITION = IN_SHADOW_PASS ? clip : psx_snap(clip, VIEWPORT_SIZE);
}

void fragment() {
	vec3 c = texture(screen, UV).rgb;
	float row = fract(UV.y * lines);
	c *= 1.0 - scanlines * smoothstep(0.35, 0.5, abs(row - 0.5));
	vec2 edge = UV * (1.0 - UV);
	float vignette = clamp(pow(edge.x * edge.y * 16.0, 0.25), 0.0, 1.0);
	ALBEDO = glass + c * brightness * vignette * power;
}
