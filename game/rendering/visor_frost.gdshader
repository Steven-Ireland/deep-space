shader_type canvas_item;
// The visor's glass (GDD §10): frost creeping in from its edges while a breach leaks O2, and fog over
// it as the suit's air runs out. Drawn on the HUD's own pixel grid, under its readouts.
//   frost  0 clear .. 1 iced well in from the edges, thickest in the corners
//   fog    0 clear .. 1 a pale haze, thicker toward the edges

uniform float frost : hint_range(0.0, 1.0) = 0.0;
uniform float fog : hint_range(0.0, 1.0) = 0.0;
uniform vec2 grid = vec2(480.0, 270.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += noise(p) * a;
		p = p * 2.03 + vec2(17.0, 9.0);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	// Whole pixels of the grid, so the ice is as blocky as everything else on the glass.
	vec2 px = floor(UV * grid);
	vec2 uv = (px + 0.5) / grid;
	// How far in from the glass's rim, the short side's units; the corners count as nearer.
	vec2 rim = min(uv, 1.0 - uv) * vec2(grid.x / grid.y, 1.0);
	float edge = min(rim.x, rim.y) * 0.75 + length(rim) * 0.25;
	// Its front breaks up into fronds: big lobes, and fine feathers along them.
	float lobes = fbm(px * 0.035);
	float feathers = fbm(px * 0.3 + lobes * 6.0);
	float front = edge - (lobes - 0.5) * 0.22 - (feathers - 0.5) * 0.07;
	float reach = frost * 0.24;
	float ice = 1.0 - smoothstep(reach - 0.035, reach, front);
	// Older ice, nearer the rim, is whiter and denser.
	float depth = clamp((reach - front) / 0.12, 0.0, 1.0);
	vec3 colour = mix(vec3(0.62, 0.78, 0.9), vec3(0.93, 0.97, 1.0), depth * 0.6 + feathers * 0.4);
	float alpha = ice * (0.12 + 0.36 * depth + 0.14 * step(0.64, feathers));
	// Fog: a haze over the glass, heavier toward the rim.
	float haze = fog * (0.1 + 0.25 * (1.0 - smoothstep(0.0, 0.35, edge)));
	COLOR = vec4(mix(vec3(0.75, 0.78, 0.8), colour, alpha / max(alpha + haze, 0.001)), clamp(alpha + haze, 0.0, 0.85));
}
