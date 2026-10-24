// First person's sky (scripts/first_person.gd): a big ball around the
// camera. Gloomy green-gray by day with slow clouds; at night dark, with
// stars and a full moon. Pixelated like the rest of the art.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, fog_disabled, shadows_disabled;

uniform vec3 day_horizon = vec3(0.4, 0.46, 0.46);
uniform vec3 day_zenith = vec3(0.27, 0.34, 0.38);
uniform vec3 night_horizon = vec3(0.1, 0.13, 0.15);
uniform vec3 night_zenith = vec3(0.03, 0.05, 0.08);
uniform float night = 0.0;  // 0 day, 1 night
uniform vec3 moon_dir = vec3(0.4, 0.62, -0.68);

varying vec3 v_dir;

void vertex() {
	v_dir = VERTEX;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float clouds(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec3 d = normalize(v_dir);
	float up = clamp(d.y, 0.0, 1.0);
	vec3 horizon = mix(day_horizon, night_horizon, night);
	vec3 zenith = mix(day_zenith, night_zenith, night);
	vec3 col = mix(horizon, zenith, smoothstep(0.0, 0.55, up));
	if (d.y > 0.0) {
		// a layer of cloud overhead, in chunky steps
		vec2 uv = d.xz / (d.y + 0.12) * 1.6 + vec2(TIME * 0.006, TIME * 0.002);
		uv = floor(uv * 24.0) / 24.0;
		float c = smoothstep(0.48, 0.78, clouds(uv));
		vec3 cloud = mix(day_horizon * 1.12, night_horizon * 1.6, night);
		col = mix(col, cloud, c * 0.75 * smoothstep(0.0, 0.2, d.y));
		// stars, behind the clouds
		vec3 q = floor(d * 180.0);
		float s = hash(q.xz + q.y * 17.0);
		if (s > 0.9965) {
			col += vec3(0.75, 0.8, 0.7) * night * (1.0 - c) * smoothstep(0.02, 0.2, d.y);
		}
		// the moon (a pixelated disc with a few dark seas), with a glow
		vec3 m = normalize(moon_dir);
		float k = dot(d, m);
		col += vec3(0.25, 0.3, 0.26) * pow(max(k, 0.0), 60.0) * night;
		if (k > 0.9985) {
			vec3 side = normalize(cross(m, vec3(0.0, 1.0, 0.0)));
			vec3 top = cross(side, m);
			vec2 mp = floor(vec2(dot(d, side), dot(d, top)) * 600.0);
			float sea = step(0.72, hash(floor(mp / 4.0)));
			vec3 moon = mix(vec3(0.86, 0.9, 0.8), vec3(0.62, 0.66, 0.6), sea);
			col = mix(col, moon, night);
		}
	}
	ALBEDO = col;
}
