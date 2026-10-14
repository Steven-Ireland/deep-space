// A hologram's light (the chart table, GDD §5): added to what's behind it, never hidden by itself,
// in its vertex colours times `tint`, banded by scanlines that climb slowly through it and unsteady
// as a whole (`strength`, set each frame). With `fade_height`, a mesh that tall, centred on its
// origin, fades out from its foot to its top (the projector's beam).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform float strength = 1.0;
uniform float energy = 1.0;
uniform float scan_density = 60.0;
uniform vec3 tint : source_color = vec3(1.0);
uniform float fade_height = 0.0;

varying vec3 world;
varying float rise;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	rise = fade_height > 0.0 ? clamp(VERTEX.y / fade_height + 0.5, 0.0, 1.0) : 0.0;
}

void fragment() {
	float band = 0.75 + 0.25 * step(0.5, fract(world.y * scan_density - TIME * 0.6));
	ALBEDO = COLOR.rgb * tint * energy * strength * band * (1.0 - rise);
}
