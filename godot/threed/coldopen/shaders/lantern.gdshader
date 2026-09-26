// The Luminarae sky-lanterns: hundreds of paper lanterns hanging motionless in the air because the
// Song holds them there. One MultiMesh, all of it on the GPU.
//
// When the Silence ring passes under a lantern it stops being held: it drops, tumbling, its glow
// dying to an ember and then to nothing, and lies dark on the terrace it lands on. The ring's own
// radius and speed (global uniforms) say when — no script has to touch the lanterns at all.
//
// INSTANCE_CUSTOM: r = bob phase, g = height above the ground it will fall to, b = fall jitter (s).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley;

global uniform vec3 silence_center;
global uniform float silence_radius;
global uniform float silence_speed;
global uniform float silence_fade;

uniform vec4 paper : source_color = vec4(1.0, 0.72, 0.38, 1.0);
uniform vec4 glow : source_color = vec4(1.0, 0.62, 0.25, 1.0);
uniform float energy = 3.2;

varying float v_dead;
varying float v_ember;

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float phase = INSTANCE_CUSTOM.r * 6.2831;
	float drop_h = INSTANCE_CUSTOM.g;
	float t = -1.0;
	if (silence_radius >= 0.0) {
		float d = length(origin.xz - silence_center.xz);
		t = (silence_radius - d) / max(silence_speed, 1.0) - INSTANCE_CUSTOM.b;
	}
	vec3 v = VERTEX;
	float fall = 0.0;
	if (t > 0.0) {
		// a paper lantern falls slowly at first and then like a stone
		fall = min(0.5 * 9.8 * 0.55 * t * t, drop_h);
		float spin = t * (1.5 + INSTANCE_CUSTOM.r * 2.0);
		float landed = step(drop_h - 0.01, fall);
		float a = spin * (1.0 - landed) + landed * 1.4;
		v = vec3(v.x, v.y * cos(a) - v.z * sin(a), v.y * sin(a) + v.z * cos(a));
		v_dead = clamp(t / 2.2, 0.0, 1.0);
		v_ember = clamp(t / 0.7, 0.0, 1.0);
	} else {
		v.y += sin(TIME * 0.5 + phase) * 0.35;
		v.x += sin(TIME * 0.31 + phase * 1.7) * 0.15;
		v_dead = 0.0;
		v_ember = 0.0;
	}
	v_dead = max(v_dead, silence_fade);
	// fall in world space, whatever the instance's scale
	vec3 world_drop = vec3(0.0, -fall, 0.0);
	mat3 inv = inverse(mat3(MODEL_MATRIX[0].xyz, MODEL_MATRIX[1].xyz, MODEL_MATRIX[2].xyz));
	VERTEX = v + inv * world_drop;
}

void fragment() {
	vec3 lit = paper.rgb;
	vec3 dead = vec3(0.32, 0.31, 0.33);
	ALBEDO = mix(lit, dead, v_dead);
	ROUGHNESS = 0.9;
	// the lower half glows brighter — the flame is inside at the bottom
	float bottom = 1.0 - clamp(UV.y, 0.0, 1.0) * 0.5;
	vec3 e = glow.rgb * energy * bottom;
	vec3 ember = vec3(1.0, 0.3, 0.05) * 0.6;
	EMISSION = mix(e, ember, v_ember) * (1.0 - v_dead);
}
