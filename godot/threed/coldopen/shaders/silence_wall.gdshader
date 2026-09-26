// The front of the Silence, as a thing you can see coming: a pale, rippling wall of disturbed air
// expanding out of the Tower's foot. The world shader drains what it has passed; this makes the edge
// itself visible across the whole bowl of the city, low and wide — a wave across the ground, not a
// halo in the sky (see art/style_frames/cold_open/README.md).
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float height = 160.0;
uniform float strength = 1.0;
uniform vec4 tint : source_color = vec4(0.78, 0.84, 1.0, 1.0);

varying float v_h;

void vertex() {
	v_h = VERTEX.y / height + 0.5;
}

void fragment() {
	float h = clamp(v_h, 0.0, 1.0);
	// strongest at the ground, thinning to nothing overhead
	float body = pow(1.0 - h, 2.2);
	float ripple = 0.5 + 0.5 * sin(UV.x * 220.0 + TIME * 3.0 + h * 30.0);
	float edge = pow(1.0 - abs(dot(NORMAL, VIEW)), 1.5);
	vec2 off = vec2(sin(UV.x * 300.0 + TIME * 5.0), cos(h * 60.0 - TIME * 4.0)) * 0.012 * body;
	vec3 behind = textureLod(screen, SCREEN_UV + off, 1.0).rgb;
	float luma = dot(behind, vec3(0.3, 0.59, 0.11));
	vec3 col = mix(behind, vec3(luma) * tint.rgb * 1.3, 0.5 * body) + tint.rgb * (0.25 + 0.35 * ripple) * body * (0.4 + edge);
	ALBEDO = col;
	ALPHA = clamp(body * strength * (0.55 + 0.45 * edge), 0.0, 1.0);
}
