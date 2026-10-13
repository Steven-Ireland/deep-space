// Small hash and value-noise helpers shared by the space shaders (sky, planets).

float ds_hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

vec3 ds_hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

float ds_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = ds_hash13(i), n100 = ds_hash13(i + vec3(1, 0, 0));
	float n010 = ds_hash13(i + vec3(0, 1, 0)), n110 = ds_hash13(i + vec3(1, 1, 0));
	float n001 = ds_hash13(i + vec3(0, 0, 1)), n101 = ds_hash13(i + vec3(1, 0, 1));
	float n011 = ds_hash13(i + vec3(0, 1, 1)), n111 = ds_hash13(i + vec3(1, 1, 1));
	return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
			mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

float ds_fbm(vec3 p, int octaves) {
	float sum = 0.0;
	float amp = 0.5;
	for (int i = 0; i < octaves; i++) {
		sum += amp * ds_noise(p);
		p = p * 2.03 + vec3(17.1, 9.2, 3.7);
		amp *= 0.5;
	}
	return sum;
}
