shader_type canvas_item;

// Filtre de contraste élevé (accessibilité) : accentue le contraste et la
// saturation de l'écran entier pour améliorer la lisibilité des joueurs
// malvoyants ou sensibles aux faibles contrastes. Voir
// SettingsManager.set_high_contrast.
uniform bool enabled = false;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

const float CONTRAST = 1.35;
const float SATURATION = 1.2;

void fragment() {
	vec3 col = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
	if (enabled) {
		col = (col - 0.5) * CONTRAST + 0.5;
		float luma = dot(col, vec3(0.299, 0.587, 0.114));
		col = mix(vec3(luma), col, SATURATION);
		col = clamp(col, 0.0, 1.0);
	}
	COLOR = vec4(col, 1.0);
}
