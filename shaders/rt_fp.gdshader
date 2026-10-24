// Ray tracing in first person: the floor, walls, shelves and counters take
// their light from the lightmap (scripts/ray_tracer.gd), which already has
// the day/night light in it. The side of something is lit by what reaches
// the floor just in front of it. (FpArt makes a one-sided copy of this by
// swapping cull_disabled for cull_back.)
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform sampler2D albedo_tex : filter_nearest, repeat_disable;
uniform bool use_texture = true;
uniform vec4 tint = vec4(1.0);
uniform sampler2D lightmap : filter_linear, repeat_disable;
uniform vec2 world = vec2(1.0, 1.0);
uniform float encode = 3.0;

varying vec3 v_pos;
varying vec3 v_normal;

void vertex() {
	v_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	vec4 c = tint * COLOR;
	if (use_texture) {
		c *= texture(albedo_tex, UV);
	}
	vec3 n = v_normal;
	if (!FRONT_FACING) {
		n = -n;
	}
	vec2 at = v_pos.xz;
	if (abs(n.y) < 0.5 && length(n.xz) > 0.001) {
		at += normalize(n.xz) * 0.3;
	}
	vec3 light = texture(lightmap, (at + 0.5) / world).rgb * encode;
	ALBEDO = c.rgb * light;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
