// The solstice night over Astra'Thalas: deep indigo, a lot of stars (the festival-goer's line — "the
// stars are very clear tonight"), and the city's gold breathing up into the air near the horizon.
// When the Silence has settled (`silence_fade`) the gold goes out of the air and the sky goes
// flat and cold — the stars stay. The stars were never the Song's.
shader_type sky;

global uniform float silence_fade;

uniform vec4 zenith : source_color = vec4(0.035, 0.045, 0.16, 1.0);
uniform vec4 horizon : source_color = vec4(0.11, 0.13, 0.33, 1.0);
uniform vec4 festival_glow : source_color = vec4(0.95, 0.62, 0.22, 1.0);
uniform float glow_strength = 0.55;
uniform vec4 dead_zenith : source_color = vec4(0.05, 0.055, 0.08, 1.0);
uniform vec4 dead_horizon : source_color = vec4(0.16, 0.17, 0.2, 1.0);
uniform float star_density = 0.9965;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	float up = clamp(h, 0.0, 1.0);
	vec3 top = mix(zenith.rgb, dead_zenith.rgb, silence_fade);
	vec3 low = mix(horizon.rgb, dead_horizon.rgb, silence_fade);
	vec3 col = mix(low, top, pow(up, 0.55));

	// The festival lives in the air above the city.
	float g = exp(-max(h + 0.02, 0.0) * 11.0);
	col += festival_glow.rgb * g * glow_strength * (1.0 - silence_fade);

	// Stars: one candidate per cell of a direction lattice, jittered, twinkling a little.
	for (int layer = 0; layer < 2; layer++) {
		float scale = layer == 0 ? 180.0 : 420.0;
		vec3 p = d * scale;
		vec3 cell = floor(p);
		float r = hash(cell + float(layer) * 31.0);
		if (r > star_density) {
			vec3 c = cell + vec3(hash(cell + 1.3), hash(cell + 2.9), hash(cell + 4.1));
			float dist = length(p - c);
			float size = layer == 0 ? 0.32 : 0.22;
			float tw = 0.75 + 0.25 * sin(TIME * (1.0 + r * 4.0) + r * 60.0);
			float s = smoothstep(size, 0.0, dist) * tw * smoothstep(-0.02, 0.2, h);
			vec3 tint = mix(vec3(0.8, 0.86, 1.0), vec3(1.0, 0.92, 0.8), hash(cell + 7.7));
			col += tint * s * (layer == 0 ? 2.2 : 1.1);
		}
	}

	// Below the horizon: the dark beyond the city's edge.
	col = mix(col, low * 0.35, smoothstep(0.0, -0.25, h));
	COLOR = col;
}
