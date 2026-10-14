// Hyperspace (GDD §5): for the length of a jump the viewport looks down a tunnel of light around
// the LANTERN's fore axis (-Z). Streaks run along its walls and rush past toward the stern, out of
// a bright core dead ahead, over a slow churn of deep blue; the tunnel twists a little as it goes.
// `flash` whites it all out at the tunnel's mouth, going in and coming out.
shader_type sky;

#include "res://game/space/noise.gdshaderinc"

uniform float speed = 1.4;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec3 deep : source_color = vec3(0.015, 0.02, 0.07);
uniform vec3 churn : source_color = vec3(0.08, 0.1, 0.32);
uniform vec3 streak_colour : source_color = vec3(0.5, 0.72, 1.0);
uniform vec3 core_colour : source_color = vec3(0.85, 0.92, 1.0);

void sky() {
	vec3 dir = normalize(EYEDIR);
	float ahead = -dir.z;
	float r = max(length(dir.xy), 0.02);
	float angle = atan(dir.y, dir.x);
	// Down the tunnel: a cylinder of radius 1 around the axis, seen from inside it.
	float along = ahead / r;

	// The walls churn, rushing past slower than the streaks.
	vec3 q = vec3(dir.x / r, dir.y / r, along * 0.25 + TIME * speed * 0.35) * 1.6;
	float cloud = ds_fbm(q, 4);
	vec3 colour = deep + churn * smoothstep(0.35, 0.8, cloud) * 1.2;

	// Streaks: lanes around the tunnel, some lit, each carrying dashes of light aft.
	float lanes = 150.0;
	float a = (angle / 6.2831853 + 0.5 + TIME * 0.012) * lanes;
	float lane = floor(a);
	float across = abs(fract(a) - 0.5);
	float h = ds_hash13(vec3(lane, 1.7, 3.1));
	float h2 = ds_hash13(vec3(lane, 9.2, 0.4));
	float travel = along * (0.12 + 0.16 * h) + TIME * speed * (0.6 + 0.8 * h2) + h * 10.0;
	float dash = fract(travel);
	float tail = 0.2 + 0.45 * h2;
	float streak = smoothstep(0.0, 0.02, dash) * (1.0 - smoothstep(0.02, tail, dash));
	// Fewer lanes lit toward the core, where they crowd together.
	streak *= step(mix(0.4, 0.88, smoothstep(0.85, 0.99, ahead)), h) * (1.0 - smoothstep(0.15, 0.45, across));
	// Right at the core the lanes crowd into its glow; behind, they fade as they go.
	streak *= 1.0 - smoothstep(0.985, 0.999, ahead);
	streak *= mix(0.35, 1.0, smoothstep(-0.6, 0.3, ahead));
	colour += mix(streak_colour, vec3(1.0), h2 * 0.6) * streak * 1.6;

	float core = max(ahead, 0.0);
	colour += core_colour * (pow(core, 40.0) * 0.25 + pow(core, 400.0) * 2.0);
	COLOR = mix(colour, vec3(1.0), flash);
}
