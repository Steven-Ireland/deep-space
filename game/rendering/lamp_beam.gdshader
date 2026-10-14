// A teammate's helmet lamp beam seen from outside it (LampBeam): a faint cone of lit air from the
// lens to where the light lands. Brightest down its middle and near the lens; its rim, its far end
// and where it meets the room fade out, so it never shows a hard edge. Added onto what's behind.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 colour : source_color = vec3(1.0, 0.95, 0.86);
// How bright the lit air is.
uniform float strength = 0.1;
// The radius the cone gains per metre (the tangent of its half-angle), and its radius at the lens.
uniform float spread = 0.33;
uniform float lens = 0.03;
// Metres the beam shows before it has faded out.
uniform float range = 7.0;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

// Metres from the lens to whatever the light lands on, and the light's power (1 at full strength).
instance uniform float reach = 7.0;
instance uniform float power = 1.0;

varying float along; // metres from the lens
varying vec2 ring; // which way round the cone

void vertex() {
	// The mesh is a unit tube: a ring of directions in xy, z 0 at the lens and -1 at the far end.
	ring = VERTEX.xy;
	along = -VERTEX.z * reach;
	VERTEX = vec3(ring * (lens + spread * along), -along);
}

void fragment() {
	// Looking through the cone's middle crosses the most lit air; its rim, seen edge-on, the least.
	// (The true cone's normal, not the faceted mesh's, so the faces don't show.)
	vec3 normal = normalize(mat3(VIEW_MATRIX) * mat3(MODEL_MATRIX) * vec3(normalize(ring), spread));
	float across = pow(abs(dot(normal, normalize(VIEW))), 2.5);
	float fade = pow(1.0 - clamp(along / range, 0.0, 1.0), 2.0) * smoothstep(0.0, 0.3, along);
	// Soft where it passes into a wall or the floor, and where it passes the eye.
	float depth = texture(depth_texture, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	float gap = VERTEX.z - behind.z / behind.w;
	float soft = clamp(gap / 0.4, 0.0, 1.0) * clamp((-VERTEX.z - 0.2) / 0.8, 0.0, 1.0);
	ALBEDO = colour * strength * power * across * fade * soft;
	ALPHA = 1.0;
}
