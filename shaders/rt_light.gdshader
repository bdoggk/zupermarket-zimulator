// Ray tracing (Options > Graphics > Ray tracing), the lightmap pass: one
// quad per light, drawn into the lightmap (scripts/ray_tracer.gd). For
// every texel of the floor the light reaches, rays are traced from that
// spot to a few points on the light, cell by cell through the height map
// of everything that stands on the floor (walls, shelves, counters, cars),
// and past the people walking around. What gets through is added up, so
// overlapping lights add up and every light casts its own shadows.
//
//   instance custom:  x, y (the light's spot on the map), radius, height
//   instance color:   rgb = color * energy, a = how big the light is (soft shadows)
shader_type canvas_item;
render_mode blend_add, unshaded;

// R: how tall the cell is (/ 4), G: under a roof (rays from outside can't get in over the walls)
uniform sampler2D heights : filter_nearest, repeat_disable;
uniform ivec2 grid = ivec2(1, 1);
uniform float texels = 8.0;
uniform float ceiling = 1.75;
uniform float encode = 3.0;
uniform int rays = 8;
uniform vec4 people[32];  // x, y, radius, height
uniform int people_count = 0;

varying vec2 v_pos;
varying vec4 v_light;

// Where the rays go on the light: across the way to it (x) and up and down (y).
const vec2 TAPS[8] = {
	vec2(-0.75, -0.4), vec2(-0.25, 0.4), vec2(0.25, -0.4), vec2(0.75, 0.4),
	vec2(-0.75, 0.4), vec2(-0.25, -0.4), vec2(0.25, 0.4), vec2(0.75, -0.4)
};

void vertex() {
	v_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy / texels - 0.5;
	v_light = INSTANCE_CUSTOM;
}

// The cell's height, and whether it has a roof.
vec2 cell_at(ivec2 c) {
	if (c.x < 0 || c.y < 0 || c.x >= grid.x || c.y >= grid.y) {
		return vec2(0.0);
	}
	vec2 d = texelFetch(heights, c, 0).rg;
	return vec2(d.r * 4.0, d.g);
}

// 1 if the ray from p (h0 off the floor) to the point l (lh up) gets
// there, 0 if something is in the way. It steps from cell to cell (a DDA),
// checking the ray's height over each cell against what stands there.
float trace(vec2 p, float h0, vec2 l, float lh, bool light_inside) {
	vec2 d = l - p;
	float len = length(d);
	if (len < 0.0001) {
		return 1.0;
	}
	vec2 dir = d / len;
	ivec2 cell = ivec2(floor(p + 0.5));
	ivec2 end = ivec2(floor(l + 0.5));
	ivec2 stp = ivec2(dir.x > 0.0 ? 1 : -1, dir.y > 0.0 ? 1 : -1);
	vec2 cf = vec2(cell);
	vec2 inv = vec2(1e9);
	vec2 tmax = vec2(1e9);
	if (abs(dir.x) > 1e-6) {
		inv.x = 1.0 / abs(dir.x);
		tmax.x = (cf.x + 0.5 * float(stp.x) - p.x) / dir.x;
	}
	if (abs(dir.y) > 1e-6) {
		inv.y = 1.0 / abs(dir.y);
		tmax.y = (cf.y + 0.5 * float(stp.y) - p.y) / dir.y;
	}
	float slope = (lh - h0) / len;
	for (int i = 0; i < 32; i++) {
		float t1;
		if (tmax.x < tmax.y) {
			t1 = tmax.x;
			tmax.x += inv.x;
			cell.x += stp.x;
		} else {
			t1 = tmax.y;
			tmax.y += inv.y;
			cell.y += stp.y;
		}
		if (t1 >= len || cell == end) {
			return 1.0;
		}
		float t2 = min(min(tmax.x, tmax.y), len);
		float ha = h0 + slope * t1;
		float hb = h0 + slope * t2;
		vec2 c = cell_at(cell);
		if (min(ha, hb) < c.x) {
			return 0.0;  // a wall, a shelf...
		}
		if (!light_inside && c.y > 0.5 && max(ha, hb) > ceiling) {
			return 0.0;  // the roof
		}
	}
	return 1.0;
}

// How much of the light gets past the people (each one a post `radius`
// across and `height` tall). Soft edges: the farther the shadow falls from
// someone, the blurrier it gets.
float past_people(vec2 p, float h0, vec2 l, float lh, float size, float reach) {
	vec2 d = l - p;
	float len = length(d);
	if (len < 0.0001) {
		return 1.0;
	}
	vec2 dir = d / len;
	float vis = 1.0;
	for (int k = 0; k < 32; k++) {
		if (k >= people_count) {
			break;
		}
		vec4 q = people[k];
		vec2 rel = q.xy - p;
		if (dot(rel, rel) < q.z * q.z * 1.6) {
			continue;  // standing right here: that's them, not their shadow
		}
		float t = dot(rel, dir);
		if (t <= 0.0 || t >= len) {
			continue;
		}
		float h = h0 + (lh - h0) * t / len;
		float blur = min(q.z * 0.25 + size * t / max(len - t, 0.15), q.z * 1.5);
		float side = smoothstep(q.z - blur, q.z + blur, length(rel - dir * t));
		float over = smoothstep(q.w - blur * 0.5, q.w + blur * 0.5, h);
		vis = min(vis, max(side, over));
	}
	return vis;
}

void fragment() {
	vec2 p = v_pos;
	vec2 l = v_light.xy;
	float reach = v_light.z;
	float lh = v_light.w;
	float size = COLOR.a;
	float d = distance(p, l);
	if (d >= reach) {
		COLOR = vec4(0.0);
	} else {
		// the same falloff as the glow texture of the normal lights
		float x = d / reach;
		float fall = x < 0.5 ? 1.0 - 1.1 * x : 0.9 * (1.0 - x);
		float h0 = cell_at(ivec2(floor(p + 0.5))).x + 0.03;  // on top of whatever is here
		bool light_inside = cell_at(ivec2(floor(l + 0.5))).y > 0.5;
		vec2 dir = d > 0.0001 ? (l - p) / d : vec2(1.0, 0.0);
		vec2 across = vec2(-dir.y, dir.x);
		float vis = 0.0;
		for (int i = 0; i < 8; i++) {
			if (i >= rays) {
				break;
			}
			vec2 tap = TAPS[i] * size;
			vis += trace(p, h0, l + across * tap.x, lh + tap.y, light_inside);
		}
		vis /= float(max(rays, 1));
		if (vis > 0.0) {
			vis *= past_people(p, h0, l, lh, size, reach);
		}
		COLOR = vec4(COLOR.rgb * (fall * vis / encode), 1.0);
	}
}
