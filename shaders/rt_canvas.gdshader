// Ray tracing in the normal view: the floor and everything standing on it
// take their light from the lightmap (scripts/ray_tracer.gd) instead of
// the 2D lights, so they're dark where a light is blocked.
//   mode 0  the floor (and blood, the delivery zone): the light at each pixel
//   mode 1  a box (a wall, a shelf): the light on the floor just in front of
//           the side you see, so a side that faces away from a light is dark
//   mode 2  something upright (people, signs, lamps): the light where it stands
// The store's day/night tint (a CanvasModulate) is applied after this, so
// the light is divided by it here.
shader_type canvas_item;

uniform sampler2D lightmap : filter_linear, repeat_disable;
uniform vec2 world = vec2(1.0, 1.0);
uniform vec2 origin = vec2(0.0, 0.0);
uniform vec3 ambient = vec3(1.0);
uniform float encode = 3.0;
uniform int mode = 0;

varying vec2 v_px;
varying vec2 v_foot;

void vertex() {
	v_px = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy - origin;
	v_foot = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy - origin;
}

vec2 to_grid(vec2 iso) {
	float a = iso.x / 32.0;
	float b = iso.y / 16.0;
	return vec2((a + b) * 0.5, (b - a) * 0.5);
}

void fragment() {
	vec2 at;
	if (mode == 0) {
		at = to_grid(v_px);
	} else if (mode == 1) {
		float dx = clamp(v_px.x - v_foot.x, -31.0, 31.0);
		vec2 base = v_foot + vec2(dx, 16.0 - abs(dx) * 0.5);  // the bottom edge of that side
		vec2 out_of = dx < 0.0 ? vec2(-32.0, 16.0) : vec2(32.0, 16.0);
		at = to_grid(base + out_of * 0.3);
	} else {
		at = to_grid(v_foot);
	}
	vec3 light = texture(lightmap, (at + 0.5) / world).rgb * encode;
	COLOR.rgb *= light / max(ambient, vec3(0.05));
}
