// How the PlayStation drew, shared by every PSX material (approach from ultraskeletal's psx-look):
// each triangle corner lands on a whole pixel, so geometry wobbles as it moves. The PlayStation
// also laid textures across a triangle as it lay on screen (affine), so they swam as the camera
// turned. That's here but off (psx_affine_amount): on the kit's big wall and floor triangles it
// slid textures out of their atlas islands, into dark wedges.

// Whether the screen is dithered (Psx.set_dithered(), a player setting), for psx_dither().
global uniform bool psx_dithered;
// How much of the PlayStation's affine texture swim to show, 0..1, scaling each material's
// affine_amount (Psx.set_affine()). Off by default.
global uniform float psx_affine_amount;

// A clip-space position moved to the middle of the pixel it falls in, on a screen `size` pixels.
// A shader that writes POSITION must write it in every pass, shadow passes too, or Godot sends
// that pass's vertices to one point: callers pass the unsnapped clip position when IN_SHADOW_PASS.
vec4 psx_snap(vec4 clip, vec2 size) {
	if (clip.w <= 0.0) {
		return clip; // behind the camera
	}
	vec2 half_size = size * 0.5;
	vec2 at = (floor(clip.xy / clip.w * half_size) + 0.5) / half_size;
	return vec4(at * clip.w, clip.zw);
}

// The depth of the unsnapped surface at the pixel a snapped triangle drew, for DEPTH. Snapping moves
// each corner up to half a pixel on its own, and at a glancing angle half a pixel is centimetres
// of depth: a panel standing proud of its wall would lose to the wall behind it in wedges, and a
// screen to the housing it's set in. So the picture wobbles but depth testing sees the true shape.
// In vertex(): `xy = vec4(clip.xy, POSITION.xy)` and `w = clip.w`, as varyings (interpolated,
// times w, so they divide back to positions laid linearly across the screen). In fragment(): the
// view-space VERTEX and PROJECTION_MATRIX. (Shadow passes don't snap: use FRAGCOORD.z there.)
float psx_true_depth(vec3 vertex, vec4 xy, float w, mat4 projection) {
	vec2 at = xy.xy / w; // where this point of the true surface projects
	vec2 drawn = xy.zw / w; // where it was drawn
	mat2 rate = mat2(dFdx(at), dFdy(at));
	vec2 move = abs(determinant(rate)) > 1e-12 ? inverse(rate) * (drawn - at) : vec2(0.0);
	vec4 clip = projection * vec4(vertex + dFdx(vertex) * move.x + dFdy(vertex) * move.y, 1.0);
	return clip.z / clip.w;
}

// A value to lay across a triangle without perspective. Interpolated as it comes from here,
// psx_affine(...).xyz / .w in the fragment shader gives the value interpolated across the screen.
vec4 psx_affine(vec3 value, vec4 clip) {
	return vec4(value * clip.w, clip.w);
}

// A colour cut to 15 bits (32 shades per channel) after a nudge by the pixel's place in a 4x4
// Bayer pattern, as the PlayStation dithered.
vec3 psx_dither(vec3 color, vec2 pixel) {
	const float BAYER[16] = {0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0};
	int k = int(mod(pixel.x, 4.0)) + int(mod(pixel.y, 4.0)) * 4;
	float nudge = psx_dithered ? (BAYER[k] + 0.5) / 16.0 - 0.5 : 0.0;
	return clamp(floor(color * 31.0 + 0.5 + nudge) / 31.0, 0.0, 1.0);
}
