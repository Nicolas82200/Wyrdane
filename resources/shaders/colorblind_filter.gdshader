shader_type canvas_item;

// Filtre d'assistance daltonisme (accessibilité) : ne simule pas un daltonisme,
// écarte au contraire les teintes que les modes rouge-vert (protanopie/
// deutéranopie) ou bleu-jaune (tritanopie) confondent le plus souvent, en
// décalant leur teinte et en accentuant légèrement la saturation dans ces
// zones. Voir SettingsManager.set_colorblind_mode.
// 0 = aucun, 1 = protanopie, 2 = deutéranopie, 3 = tritanopie.
uniform int mode : hint_range(0, 3) = 0;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

vec3 rgb2hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 k = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + k.xyz) * 6.0 - k.www);
	return c.z * mix(k.xxx, clamp(p - k.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec3 col = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
	if (mode != 0) {
		vec3 hsv = rgb2hsv(col);
		float hue_deg = hsv.x * 360.0;
		if (mode == 1 || mode == 2) {
			// Protanopie/Deutéranopie : rouge et vert se confondent.
			if (hue_deg < 20.0 || hue_deg > 345.0) {
				hsv.x = fract((hue_deg + 20.0) / 360.0);
			} else if (hue_deg > 90.0 && hue_deg < 150.0) {
				hsv.x = fract((hue_deg + 30.0) / 360.0);
			}
		} else {
			// Tritanopie : bleu et jaune se confondent.
			if (hue_deg > 40.0 && hue_deg < 70.0) {
				hsv.x = fract((hue_deg + 25.0) / 360.0);
			} else if (hue_deg > 190.0 && hue_deg < 230.0) {
				hsv.x = fract((hue_deg - 20.0 + 360.0) / 360.0);
			}
		}
		hsv.y = clamp(hsv.y * 1.15, 0.0, 1.0);
		col = hsv2rgb(hsv);
	}
	COLOR = vec4(col, 1.0);
}
