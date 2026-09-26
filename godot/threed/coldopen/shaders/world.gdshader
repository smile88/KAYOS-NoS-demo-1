// The Cold Open's one surface shader — every wall, floor, roof, prop and lamp in Astra'Thalas.
//
// The look (art/style_frames/cold_open/): stylised low-poly. Flat colour, a soft world-space marble
// vein where asked for, per-facet tone from vertex colour, and lighting doing the rest.
//
// The Silence lives here too. It is a ring expanding across the city from the base of the Tower
// (global uniforms, set by the director). Everything the ring has passed is drained: colour to cold
// grey, and every glow that belongs to the Song goes out. Fire does not belong to the Song (`song` 0)
// and keeps burning — which is exactly what makes the braziers the last warm thing on the balcony.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

global uniform vec3 silence_center;
global uniform float silence_radius;   // metres from the Tower; < 0 = the Song is whole
global uniform float silence_edge;     // width of the drained transition
global uniform float silence_fade;     // 0..1 over the whole world after the ring (the grey settling)

uniform vec4 albedo : source_color = vec4(0.92, 0.90, 0.86, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.78;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float specular : hint_range(0.0, 1.0) = 0.35;
// Marble: 0 = flat colour, 1 = veined. Veins are world-space, so they run on across seams.
uniform float marble = 0.0;
uniform vec4 vein_color : source_color = vec4(0.62, 0.66, 0.74, 1.0);
uniform float vein_scale = 0.35;
// How much the kit's per-facet vertex colour tints the surface (the faceted low-poly read).
uniform float facet = 1.0;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
// 1 = this glow is the Song and dies in the Silence. 0 = real fire.
uniform float song = 1.0;
// The same object in the drained world: how grey it goes (1 = fully).
uniform float drain_amount = 0.92;

varying vec3 wpos;
varying vec3 wnrm;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x),
				   mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			   mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
				   mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return v;
}

// 0 = still singing, 1 = silenced.
float drained_at(vec3 p) {
	if (silence_radius < 0.0) {
		return 0.0;
	}
	float d = length(p.xz - silence_center.xz);
	return max(1.0 - smoothstep(silence_radius - silence_edge, silence_radius, d), silence_fade);
}

// A thin pale shimmer riding the ring's front.
float ring_front(vec3 p) {
	if (silence_radius < 0.0) {
		return 0.0;
	}
	float d = length(p.xz - silence_center.xz);
	float x = (d - silence_radius) / 2.5;
	return exp(-x * x) * (1.0 - silence_fade);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 col = albedo.rgb * mix(vec3(1.0), COLOR.rgb, facet);
	if (marble > 0.0) {
		// Soft veins: a warped sine band through fbm, thin and low contrast, as in the frames.
		float n = fbm(wpos * vein_scale);
		float v = abs(sin((wpos.x * 0.7 + wpos.y * 0.45 + wpos.z * 0.6) * vein_scale * 3.0 + n * 7.0));
		float vein = smoothstep(0.972, 1.0, 1.0 - v) * 0.2 + smoothstep(0.62, 0.95, n) * 0.05;
		col = mix(col, vein_color.rgb * col * 1.1, clamp(vein * marble, 0.0, 1.0));
	}
	float dr = drained_at(wpos) * drain_amount;
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 grey = vec3(luma) * vec3(0.78, 0.82, 0.92);
	ALBEDO = mix(col, grey, dr);
	ROUGHNESS = mix(roughness, 0.9, dr);
	METALLIC = metallic * (1.0 - dr);
	SPECULAR = specular;
	vec3 glow = emission_color.rgb * emission_energy;
	glow *= 1.0 - dr * song;
	glow += vec3(0.75, 0.82, 1.0) * ring_front(wpos) * 0.9;
	EMISSION = glow;
}
