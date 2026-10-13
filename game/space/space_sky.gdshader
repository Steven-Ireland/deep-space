// The sky of a star system (GDD §14): pixel-sized stars in three depths, an fbm nebula in the
// system's two tints, and the local star as a glaring disc where the scene's sun light points
// from. Drawn at the 3D's few pixels and dithered with everything else.
shader_type sky;

#include "res://game/space/noise.gdshaderinc"

uniform float seed = 0.0;
uniform float star_density : hint_range(0.0, 0.2) = 0.05;
uniform float star_brightness = 1.4;
uniform vec3 nebula_a : source_color = vec3(0.25, 0.08, 0.35);
uniform vec3 nebula_b : source_color = vec3(0.05, 0.2, 0.35);
uniform float nebula_strength = 0.5;
uniform float sun_size = 0.012; // radius, radians
uniform float sun_glare = 0.25;

vec3 stars(vec3 dir, float scale, float density, float brightness, float layer) {
	vec3 p = dir * scale + vec3(seed * 13.7 + layer * 91.3);
	vec3 cell = floor(p);
	float h = ds_hash13(cell);
	if (h < 1.0 - density) {
		return vec3(0.0);
	}
	vec3 at = cell + 0.15 + 0.7 * ds_hash33(cell);
	float d = length(p - at);
	float b = smoothstep(0.6, 0.05, d) * (0.25 + 0.75 * pow(ds_hash13(cell + 7.0), 3.0)) * brightness;
	vec3 tint = mix(vec3(1.0, 0.82, 0.66), vec3(0.72, 0.84, 1.0), ds_hash13(cell + 3.0));
	return tint * b;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 colour = vec3(0.0);
	// A few bright stars, more dim ones, a haze of faint ones: depth, not snow.
	colour += stars(dir, 120.0, star_density * 0.25, star_brightness * 1.8, 1.0);
	colour += stars(dir, 230.0, star_density * 0.45, star_brightness * 0.8, 0.0);
	colour += stars(dir, 420.0, star_density * 0.7, star_brightness * 0.3, 2.0);

	// Nebula: soft clouds in two tints, with darker dust lanes cutting through.
	vec3 q = dir * 2.2 + vec3(seed * 3.1);
	float cloud = ds_fbm(q, 5);
	float tint_mix = ds_fbm(dir * 4.5 + vec3(seed * 5.3 + 4.0), 4);
	float dust = smoothstep(0.45, 0.65, ds_fbm(dir * 6.0 + vec3(seed * 1.7 + 9.0), 4));
	float density = pow(smoothstep(0.3, 0.8, cloud), 1.3) * (1.0 - 0.75 * dust);
	colour += mix(nebula_a, nebula_b, tint_mix) * density * nebula_strength;
	colour *= 1.0 - 0.5 * dust * smoothstep(0.3, 0.7, cloud);

	if (LIGHT0_ENABLED) {
		float c = dot(dir, LIGHT0_DIRECTION);
		float angle = acos(clamp(c, -1.0, 1.0));
		vec3 sun = LIGHT0_COLOR;
		colour += sun * 6.0 * smoothstep(sun_size, sun_size * 0.6, angle);
		colour += sun * sun_glare * (pow(max(c, 0.0), 300.0) * 2.0 + pow(max(c, 0.0), 24.0) * 0.4);
	}
	COLOR = colour;
}
