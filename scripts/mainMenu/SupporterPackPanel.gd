extends RefCounted
class_name SupporterPackPanel

# Section "Wyrdane Supporter Pack", ajoutée dynamiquement en bas de la vue
# Profil (voir doc UX § Supporter Packs) — présente le contenu du pack
# (cosmétique uniquement, aucun avantage compétitif). Le bouton reste
# désactivé : un vrai achat nécessite l'intégration des microtransactions
# Steamworks (produit à créer côté dashboard partenaire) et une route backend
# de vérification de commande, ni l'un ni l'autre disponibles aujourd'hui —
# volontairement PAS simulé (aucun octroi de récompense sans paiement réel).

static func open(menu) -> void:
	var existing: Node = menu.profile_body.get_node_or_null("SupporterPackSection")
	if existing:
		existing.queue_free()

	var section := VBoxContainer.new()
	section.name = "SupporterPackSection"
	section.add_theme_constant_override("separation", 6)
	menu.profile_body.add_child(section)

	section.add_child(HSeparator.new())

	var title := Label.new()
	title.text = SettingsManager.t("SUPPORTER_PACK_TITLE")
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.91, 0.835, 0.639, 1))
	section.add_child(title)

	var desc := Label.new()
	desc.text = SettingsManager.t("SUPPORTER_PACK_DESC")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.add_theme_color_override("font_color", Color(0.85, 0.8, 0.72, 0.9))
	section.add_child(desc)

	var join_button := Button.new()
	join_button.text = SettingsManager.t("SUPPORTER_PACK_BUTTON")
	join_button.tooltip_text = SettingsManager.t("SUPPORTER_PACK_TOOLTIP")
	join_button.disabled = true
	join_button.custom_minimum_size = Vector2(0, 40)
	section.add_child(join_button)
