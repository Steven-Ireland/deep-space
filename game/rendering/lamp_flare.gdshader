// The glare off a teammate's helmet lamp lens (LampBeam). Whenever the lens faces you it's a small
// hot point with a little halo, so a light that's on looks on. Pointed into your eyes, it flares
// across the view: a wide halo, a long level streak, a six-point star and a faint veil. It's drawn
// over everything at a size fixed on screen, as bright as the share of the lens itself that's in
// sight: what's drawn there (the depth buffer, sampled across the lens) is checked against how far
// away the lens is. So it hides behind exactly what you see, a door frame's trim included.
shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 colour : source_color = vec3(1.0, 0.95, 0.86);
// How far it reaches at full glare, in screen half-heights from the lens (twice that sideways).
uniform float size = 0.9;
// The lens's radius in metres, and how much nearer than it something must be to hide it.
uniform float lens = 0.03;
uniform float hide_margin = 0.03;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

instance uniform float glow = 0.0; // 0..1: the lens lit and facing this way
instance uniform float glare = 0.0; // 0..1: the beam pointed into this eye

varying vec2 offset; // from the lens, in screen half-heights
varying float extent;
varying vec2 lens_at; // the lens on screen, 0..1
varying float lens_distance; // metres in front of the eye
varying float lens_pixels; // its radius on screen

void vertex() {
	vec4 view = MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0);
	vec4 centre = PROJECTION_MATRIX * view;
	extent = mix(0.08, size, glare);
	offset = VERTEX.xy * 2.0 * extent * vec2(2.0, 1.0);
	lens_at = centre.xy / centre.w * 0.5 + 0.5;
	lens_distance = -view.z;
	lens_pixels = lens * PROJECTION_MATRIX[1][1] / max(-view.z, 0.01) * VIEWPORT_SIZE.y * 0.5;
	vec2 aspect = vec2(VIEWPORT_SIZE.y / VIEWPORT_SIZE.x, 1.0);
	// Behind the eye, it's off the screen.
	POSITION = centre.w > 0.0 ? centre + vec4(offset * aspect * centre.w, 0.0, 0.0) : vec4(10.0, 10.0, 0.0, 1.0);
}

// How much of the lens is in sight, 0..1: a 3x3 spread of points across it on screen, each in
// sight if nothing drawn there is nearer than the lens. Off the screen counts as out of sight.
float in_sight(vec2 at, vec2 spread, mat4 inv_projection) {
	float seen = 0.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			vec2 uv = at + vec2(float(x), float(y)) * spread;
			if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
				continue;
			}
			vec4 drawn = inv_projection * vec4(uv * 2.0 - 1.0, texture(depth_texture, uv).r, 1.0);
			seen += -drawn.z / drawn.w > lens_distance - hide_margin ? 1.0 : 0.0;
		}
	}
	return seen / 9.0;
}

void fragment() {
	float sight = in_sight(lens_at, vec2(max(lens_pixels, 1.0)) / VIEWPORT_SIZE, INV_PROJECTION_MATRIX);
	if (sight <= 0.0) {
		discard;
	}
	float r = length(offset);
	float core = glow * smoothstep(0.03, 0.01, r);
	float halo = (0.3 * glow + glare) * exp(-r * r / (0.0015 + 0.05 * glare));
	float streak = glare * exp(-abs(offset.y) / 0.007) * exp(-abs(offset.x) / (0.04 + 0.5 * glare));
	float star = glare * pow(abs(cos(atan(offset.y, offset.x) * 3.0)), 48.0) * exp(-r / (0.02 + 0.2 * glare));
	float veil = glare * glare * 0.12 * max(0.0, 1.0 - r / extent);
	// Nothing reaches the quad's edge.
	float edge = 1.0 - smoothstep(0.75, 1.0, max(abs(offset.x) * 0.5, abs(offset.y)) / extent);
	ALBEDO = colour * (core * 1.5 + halo + streak * 0.9 + star * 0.6 + veil) * edge * sight;
	ALPHA = 1.0;
}
