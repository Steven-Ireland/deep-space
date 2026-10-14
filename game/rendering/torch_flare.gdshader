// The glare off a teammate's flashlight lens (TorchBeam). Whenever the lens faces you it's a small
// hot point with a little halo, so a light that's on looks on. Pointed into your eyes, it flares
// across the view: a wide halo, a long level streak, a six-point star and a faint veil. It's drawn
// over everything at a size fixed on screen; whether the lens is in sight is TorchBeam's to say.
shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 colour : source_color = vec3(1.0, 0.95, 0.86);
// How far it reaches at full glare, in screen half-heights from the lens (twice that sideways).
uniform float size = 0.9;

instance uniform float glow = 0.0; // 0..1: the lens lit and facing this way
instance uniform float glare = 0.0; // 0..1: the beam pointed into this eye

varying vec2 offset; // from the lens, in screen half-heights
varying float extent;

void vertex() {
	vec4 centre = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0);
	extent = mix(0.08, size, glare);
	offset = VERTEX.xy * 2.0 * extent * vec2(2.0, 1.0);
	vec2 aspect = vec2(VIEWPORT_SIZE.y / VIEWPORT_SIZE.x, 1.0);
	// Behind the eye, it's off the screen.
	POSITION = centre.w > 0.0 ? centre + vec4(offset * aspect * centre.w, 0.0, 0.0) : vec4(10.0, 10.0, 0.0, 1.0);
}

void fragment() {
	float r = length(offset);
	float core = glow * smoothstep(0.03, 0.01, r);
	float halo = (0.3 * glow + glare) * exp(-r * r / (0.0015 + 0.05 * glare));
	float streak = glare * exp(-abs(offset.y) / 0.007) * exp(-abs(offset.x) / (0.04 + 0.5 * glare));
	float star = glare * pow(abs(cos(atan(offset.y, offset.x) * 3.0)), 48.0) * exp(-r / (0.02 + 0.2 * glare));
	float veil = glare * glare * 0.12 * max(0.0, 1.0 - r / extent);
	// Nothing reaches the quad's edge.
	float edge = 1.0 - smoothstep(0.75, 1.0, max(abs(offset.x) * 0.5, abs(offset.y)) / extent);
	ALBEDO = colour * (core * 1.5 + halo + streak * 0.9 + star * 0.6 + veil) * edge;
	ALPHA = 1.0;
}
