// The Celestial Invocation made visible: the column of gold the Grand Archmage draws up out of the
// Tower into the sky. Additive, unshaded, fading upward, with slow bright bands climbing it.
// `strength` is the cutscene's to play — it swells, falters, flickers, and goes out.
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.78, 0.36, 1.0);
uniform float strength = 1.0;
uniform float height = 700.0;
uniform float falloff = 1.6;
uniform float band_speed = 0.25;
uniform float flicker = 0.0;

varying float v_h;

void vertex() {
	v_h = VERTEX.y / height + 0.5;   // a centred cylinder: 0 at its base
}

void fragment() {
	float h = clamp(v_h, 0.0, 1.0);
	// fade in over the first metres so the column pours up from above the celebrant's hands
	float up = pow(1.0 - h, falloff) * smoothstep(0.0, 0.03, h);
	// brighter at the core: VIEW-facing fresnel reads as a round beam
	float core = pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.6);
	float bands = 0.75 + 0.25 * sin((h * 40.0 - TIME * band_speed * 10.0));
	float f = 1.0 - flicker * step(0.5, fract(sin(TIME * 43.0) * 43758.5));
	ALBEDO = color.rgb * up * core * bands * strength * f * 3.0;
}
