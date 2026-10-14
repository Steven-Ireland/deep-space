// The docking collar's tractor beam (Collar): a cone of pale lit space from the LANTERN's collar to
// the derelict it's drawing in or pushing off, like a lamp's beam (lamp_beam.gdshader) but the whole
// way, bands of brighter light running along it the way it pulls. Soft at its rim, its ends and
// where it meets a hull. Added onto what's behind.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 colour : source_color = vec3(0.55, 0.85, 1.0);
uniform float strength = 0.2;
// Its radius at the collar, and how much it gains per metre out.
uniform float mouth = 1.1;
uniform float spread = 0.04;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

// Metres to the derelict, how strong the beam is now (0..1), and which way it pulls: +1 drawing the
// derelict in (the bands run toward the collar), -1 pushing it off.
instance uniform float reach = 30.0;
instance uniform float power = 1.0;
instance uniform float flow = 1.0;

varying float along; // metres out from the collar
varying vec2 ring;

void vertex() {
	// The mesh is a unit tube (LampBeam._tube): a ring of directions in xy, z 0 at the collar and
	// -1 at the far end.
	ring = VERTEX.xy;
	along = -VERTEX.z * reach;
	VERTEX = vec3(ring * (mouth + spread * along), -along);
}

void fragment() {
	vec3 normal = normalize(mat3(VIEW_MATRIX) * mat3(MODEL_MATRIX) * vec3(normalize(ring), spread));
	float across = pow(abs(dot(normal, normalize(VIEW))), 1.5);
	float ends = smoothstep(0.0, 1.5, along) * smoothstep(0.0, 3.0, reach - along);
	float bands = 0.55 + 0.45 * sin(along * 1.1 + TIME * 5.0 * flow);
	float depth = texture(depth_texture, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	float gap = VERTEX.z - behind.z / behind.w;
	float soft = clamp(gap / 1.5, 0.0, 1.0) * clamp((-VERTEX.z - 0.3) / 1.0, 0.0, 1.0);
	ALBEDO = colour * strength * power * across * ends * bands * soft;
	ALPHA = 1.0;
}
