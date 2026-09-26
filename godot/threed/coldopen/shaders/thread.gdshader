// The Song's threads: the fine gold lines strung through the air from the Tower to every lamp in the
// city, like the strings of an instrument. The Silence goes out along them from the Tower: each thread
// turns black where the ring has passed, and a moment later it is gone — snapped, not dimmed.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded, shadows_disabled, fog_disabled;

global uniform vec3 silence_center;
global uniform float silence_radius;
global uniform float silence_speed;

uniform vec4 color : source_color = vec4(1.0, 0.8, 0.4, 1.0);
uniform float energy = 3.0;
// how long after going black (s) before the thread breaks up and vanishes
uniform float snap_after = 1.2;

varying vec3 wpos;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = -1.0;
	if (silence_radius >= 0.0) {
		float d = length(wpos.xz - silence_center.xz);
		t = (silence_radius - d) / max(silence_speed, 1.0);
	}
	float pulse = 0.85 + 0.15 * sin(TIME * 2.0 - length(wpos.xz - silence_center.xz) * 0.08);
	vec3 lit = color.rgb * energy * pulse;
	if (t > 0.0) {
		// black, then breaking up into pieces, then gone
		float chunk = hash(floor(wpos * 1.2));
		if (t > snap_after + chunk * 1.5) {
			discard;
		}
		lit = mix(vec3(1.0, 0.95, 0.9) * 3.0, vec3(0.02), clamp(t / 0.35, 0.0, 1.0));
	}
	ALBEDO = lit;
}
