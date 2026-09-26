// People in the Cold Open. The generated low-poly cast keeps its painted atlas; this shader only adds
// what the night does to them.
//
// When the Silence passes over a figure it drains like the world does — unless it is one of the
// festival crowd, who become what `03b_after.png` shows: flat, glowing, detail-less gold, like figures
// cut from gold leaf. (`to_gold` 1.) Talindir is never gold: he goes grey with everything else.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

global uniform vec3 silence_center;
global uniform float silence_radius;
global uniform float silence_edge;
global uniform float silence_fade;

uniform sampler2D atlas : source_color, filter_nearest, hint_default_white;
uniform vec4 tint : source_color = vec4(1.0);
uniform float to_gold = 0.0;
// Per-figure: forces the silhouette on regardless of the ring (the cutscene's held tableau).
uniform float gold_now = 0.0;
// The aging: the painted colours go ashen and pale.
uniform float age = 0.0;
// A soft rim so figures separate from marble behind them (the frames' readable silhouettes).
uniform float rim_amount = 0.5;
// Stylised fill: people never sink to black against a lit wall (the frames keep every figure legible).
uniform float lift = 0.22;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 col = texture(atlas, UV).rgb * tint.rgb;
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(luma) * vec3(0.95, 0.93, 0.9) * 1.15, age * 0.6);

	float dr = 0.0;
	if (silence_radius >= 0.0) {
		float d = length(wpos.xz - silence_center.xz);
		dr = max(1.0 - smoothstep(silence_radius - silence_edge, silence_radius, d), silence_fade);
	}
	float gold = clamp(max(dr * to_gold, gold_now), 0.0, 1.0);
	float grey_amt = dr * (1.0 - to_gold);

	vec3 grey = vec3(luma) * vec3(0.78, 0.82, 0.92);
	col = mix(col, grey, grey_amt * 0.92);
	vec3 gold_col = vec3(1.0, 0.66, 0.1);
	ALBEDO = mix(col, gold_col * 0.6, gold);
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
	RIM = rim_amount * (1.0 - gold);
	RIM_TINT = 0.4;
	EMISSION = gold_col * 0.85 * gold + col * lift * (1.0 - gold);
}
