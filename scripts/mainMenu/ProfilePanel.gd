extends RefCounted
class_name ProfilePanel

# Vue Profil du menu principal (stats, badge de rang) + récompense de
# connexion quotidienne — extrait de MainMenu.gd. Fonctions statiques
# prenant `menu` (le MainMenu propriétaire) en paramètre, même pattern que
# NewsPanel/QuestsPanel.

static func open(menu) -> void:
	AudioManager.play(AudioManager.OPEN_MENU)
	menu._profile_target_user_id = -1
	menu._profile_target_username = ""
	menu.profile_title_label.text = SettingsManager.t("PROFILE_TITLE")
	if SteamService.ensure_init():
		var persona := SteamService.local_persona_name()
		if persona != "":
			menu.profile_name_label.text = persona
		var tex := SteamService.local_avatar_texture()
		if tex:
			menu.profile_avatar.texture = tex
	menu.profile_match_stats_label.text = SettingsManager.t("MENU_MATCH_STATS") % [SettingsManager.match_wins, SettingsManager.match_losses]
	menu.profile_match_stats_label.visible = true
	_show_placeholders(menu)
	# Revient toujours sur l'onglet Principal à l'ouverture de la vue Profil —
	# un onglet Historique/Communauté resterait sinon sélectionné (et vide,
	# ses sections ayant été libérées en quittant la vue) au prochain retour.
	menu._profile_tab = menu.ProfileTab.MAIN
	menu._update_profile_tab_tints()
	_fetch(menu)
	render(menu)

# Profil d'un AUTRE joueur (bouton "Voir le profil" sur une ligne d'ami, voir
# FriendsPanel._show_context_menu) — même vue/mise en page que open() ci-
# dessus, mais données via GET /api/profile/:userId (restreint aux amis
# acceptés côté backend) et sans onglet Communauté (parrainage/adversaires
# récents n'ont de sens que pour le joueur local). Pas d'avatar Steam
# disponible pour un tiers arbitraire (l'API Steamworks locale ne connaît que
# l'identité du joueur local) : le cadre reste vide plutôt que d'afficher
# l'avatar du joueur local par erreur.
static func open_for_user(menu, user_id: int, username: String) -> void:
	AudioManager.play(AudioManager.OPEN_MENU)
	menu._profile_target_user_id = user_id
	menu._profile_target_username = username
	menu.profile_title_label.text = username
	menu.profile_name_label.text = username
	menu.profile_avatar.texture = null
	menu.profile_match_stats_label.visible = false
	_show_placeholders(menu)
	menu._profile_tab = menu.ProfileTab.MAIN
	menu._update_profile_tab_tints()
	_fetch(menu)
	render(menu)

# Reconstruit les sections dynamiques de profile_body selon l'onglet actif
# (voir MainMenu._select_profile_tab) — les stats/badge de rang (remplies par
# _populate_stats une fois la requête GET /api/profile terminée) ne sont
# affichées que sur l'onglet Principal, jamais refetchées en changeant d'onglet.
static func render(menu) -> void:
	var viewing_friend: bool = menu._profile_target_user_id >= 0
	# Parrainage/adversaires récents n'ont de sens que pour le joueur local —
	# l'onglet Communauté n'existe simplement pas sur le profil d'un ami.
	menu.profile_community_tab_button.visible = not viewing_friend
	if viewing_friend and menu._profile_tab == menu.ProfileTab.COMMUNITY:
		menu._profile_tab = menu.ProfileTab.MAIN
		menu._update_profile_tab_tints()

	var main_visible: bool = menu._profile_tab == menu.ProfileTab.MAIN
	menu.profile_stats_sep.visible = main_visible
	menu.profile_member_since_label.visible = main_visible
	menu.profile_collection_label.visible = main_visible
	menu.profile_solo_stats_label.visible = main_visible
	menu.profile_ranked_stats_label.visible = main_visible
	menu.profile_rank_badge_row.visible = main_visible

	for section_name in ["MatchHistorySection", "SocialSection", "ReferralSection", "SupporterPackSection"]:
		var existing: Node = menu.profile_body.get_node_or_null(section_name)
		if existing:
			existing.queue_free()

	match menu._profile_tab:
		menu.ProfileTab.MAIN:
			# Section "Wyrdane Supporter Pack" retirée sur demande utilisateur
			# (2026-09-25, "pour le moment il ne m'est pas utile") — le script
			# SupporterPackPanel.gd est conservé tel quel (le contenu du pack
			# n'a pas changé, juste plus affiché ici) en vue d'une réactivation
			# future, voir son commentaire d'en-tête.
			pass
		menu.ProfileTab.HISTORY:
			MatchHistoryPanel.open(menu)
		menu.ProfileTab.COMMUNITY:
			RecentOpponentsPanel.open(menu)
			ReferralPanel.open(menu)

# BackendClient.login_with_steam() est lancé de façon asynchrone au démarrage
# du menu (voir MainMenu._start_backend_sync) : si le joueur ouvre cette vue
# avant la fin de la connexion, is_authenticated() est encore faux. Attendre
# login_succeeded sans jamais relancer la requête laisserait les libellés
# bloqués sur "Chargement..." indéfiniment.
static func _request_profile(menu) -> void:
	if menu._profile_target_user_id >= 0:
		BackendClient.get_friend_profile(menu._profile_target_user_id, _on_response.bind(menu))
	else:
		BackendClient.get_profile(_on_response.bind(menu))

static func _fetch(menu) -> void:
	if BackendClient.is_authenticated():
		_request_profile(menu)
		return
	if not BackendClient.login_succeeded.is_connected(_on_login_succeeded.bind(menu)):
		BackendClient.login_succeeded.connect(_on_login_succeeded.bind(menu), CONNECT_ONE_SHOT)
	if not BackendClient.login_failed.is_connected(_on_login_failed.bind(menu)):
		BackendClient.login_failed.connect(_on_login_failed.bind(menu), CONNECT_ONE_SHOT)

static func _on_login_succeeded(_user: Dictionary, menu) -> void:
	if menu._current_info_view != menu.InfoView.PROFILE:
		return
	_request_profile(menu)

static func _on_login_failed(_reason: String, menu) -> void:
	if menu._current_info_view != menu.InfoView.PROFILE:
		return
	_show_unavailable(menu)

static func _on_response(success: bool, data: Dictionary, menu) -> void:
	if menu._current_info_view != menu.InfoView.PROFILE:
		return
	if success:
		_populate_stats(menu, data)
	else:
		_show_unavailable(menu)

static func _show_placeholders(menu) -> void:
	var dash := SettingsManager.t("PROFILE_LOADING")
	menu.profile_place_label.text = dash
	menu.profile_member_since_label.text = dash
	menu.profile_collection_label.text = dash
	menu.profile_solo_stats_label.text = dash
	menu.profile_ranked_stats_label.text = dash
	menu.profile_rank_badge_label.text = dash

static func _show_unavailable(menu) -> void:
	var dash := SettingsManager.t("PROFILE_UNAVAILABLE")
	menu.profile_place_label.text = dash
	menu.profile_member_since_label.text = dash
	menu.profile_collection_label.text = dash
	menu.profile_solo_stats_label.text = dash
	menu.profile_ranked_stats_label.text = dash
	menu.profile_rank_badge_label.text = dash

static func _populate_stats(menu, data: Dictionary) -> void:
	var created_at: String = str(data.get("created_at", ""))
	var date_str := created_at.substr(0, 10) if created_at.length() >= 10 else SettingsManager.t("PROFILE_UNAVAILABLE")
	menu.profile_member_since_label.text = SettingsManager.t("PROFILE_MEMBER_SINCE") % date_str

	var collection_count := int(data.get("collection_count", 0))
	menu.profile_collection_label.text = SettingsManager.t("PROFILE_COLLECTION_COUNT") % collection_count

	var solo: Dictionary = data.get("solo", {})
	menu.profile_solo_stats_label.text = SettingsManager.t("PROFILE_SOLO_STATS") % [int(solo.get("wins", 0)), int(solo.get("losses", 0))]

	var ranked: Dictionary = data.get("ranked", {})
	menu.profile_ranked_stats_label.text = SettingsManager.t("PROFILE_RANKED_STATS") % [
		int(ranked.get("wins", 0)), int(ranked.get("losses", 0)),
		int(ranked.get("mmr", 0)), int(ranked.get("rank", 0)),
	]
	menu.profile_place_label.text = SettingsManager.t("PROFILE_RANK_PLACE") % [
		int(ranked.get("rank", 0)), int(ranked.get("totalPlayers", 0)),
	]
	apply_rank_badge(menu.profile_rank_badge_label, menu.profile_rank_icon, int(ranked.get("mmr", 0)), true)

# Palier dérivé du MMR (voir RankTier) — appliqué au badge du menu principal
# (persistant, avec_progress = false) et à celui de la vue Profil (avec la
# progression vers le palier suivant, plus lisible dans un contexte dédié).
static func apply_rank_badge(label: Label, icon: TextureRect, mmr: int, with_progress: bool) -> void:
	var tier := RankTier.from_mmr(mmr)
	AchievementManager.check_rank_tier(tier)
	label.add_theme_color_override("font_color", RankTier.color(tier))
	icon.texture = RankTier.icon(tier)
	var text := SettingsManager.t("RANK_BADGE_FORMAT") % [SettingsManager.t(RankTier.tier_key(tier)), mmr]
	if with_progress:
		var remaining := RankTier.mmr_to_next_tier(mmr)
		if remaining >= 0:
			var next_tier_name := SettingsManager.t(RankTier.tier_key(tier + 1))
			text += "\n" + SettingsManager.t("RANK_BADGE_PROGRESS") % [remaining, next_tier_name]
		else:
			text += "\n" + SettingsManager.t("RANK_BADGE_MAX_TIER")
	label.text = text

# --- Récompense de connexion quotidienne ---------------------------------
# Popup automatique au chargement du menu (une fois la sync backend faite),
# uniquement si pas déjà réclamée aujourd'hui — voir BackendClient.get_login_reward_status.
# Frise de 5 jours (carte 0 = récompense du jour, cliquable ; 1-4 = aperçu des
# jours suivants en supposant une série ininterrompue) : le montant de chaque
# jour vient de `upcoming` (calculé et renvoyé par le backend), jamais dupliqué
# côté client (voir « Récompense de connexion quotidienne » dans le CLAUDE.md
# de wyrdane-backend) — élimine le risque de dérive qu'un REWARD_BY_DAY local
# aurait posé, tout en permettant d'afficher les jours à venir par avance.
static func fetch_login_reward_status(menu) -> void:
	if not BackendClient.is_authenticated():
		return
	BackendClient.get_login_reward_status(func(success: bool, data: Dictionary):
		if not success or bool(data.get("claimed_today", true)):
			return
		_show_login_reward_popup(menu, data.get("upcoming", []))
	)

static func _show_login_reward_popup(menu, upcoming: Array) -> void:
	menu.login_reward_title_label.text = SettingsManager.t("LOGIN_REWARD_TITLE")
	_populate_strip(menu, upcoming)
	menu.login_reward_claim_button.text = SettingsManager.t("LOGIN_REWARD_CLAIM")
	menu.login_reward_claim_button.disabled = false
	menu.login_reward_popup.visible = true
	menu._fade_in_overlay(menu.login_reward_popup)

static func _populate_strip(menu, upcoming: Array) -> void:
	for i in menu.login_reward_day_panels.size():
		var panel: PanelContainer = menu.login_reward_day_panels[i]
		panel.modulate.a = 1.0
		var day_label: Label = panel.get_node("DayCardMargin/DayCardVBox/DayLabel")
		var amount_label: Label = panel.get_node("DayCardMargin/DayCardVBox/AmountLabel")
		day_label.text = SettingsManager.t("LOGIN_REWARD_TODAY") if i == 0 else SettingsManager.t("LOGIN_REWARD_DAY_OFFSET") % i
		var entry: Dictionary = upcoming[i] if i < upcoming.size() else {}
		amount_label.text = SettingsManager.t("LOGIN_REWARD_AMOUNT_SHORT") % int(entry.get("reward", 0))

static func on_claim_login_reward_pressed(menu) -> void:
	menu.login_reward_claim_button.disabled = true
	BackendClient.claim_login_reward(func(success: bool, _data: Dictionary):
		if not success:
			menu.login_reward_claim_button.disabled = false
			return
		AudioManager.play(AudioManager.CONFIRM)
		CurrencyManager.sync_from_backend()
		# Grise uniquement la carte du jour (index 0) : elle vient d'être
		# réclamée, les jours suivants restent un aperçu, pas encore acquis.
		menu.login_reward_day_panels[0].modulate.a = 0.55
		menu.login_reward_claim_button.text = SettingsManager.t("LOGIN_REWARD_CLAIMED")
		await menu.get_tree().create_timer(1.4).timeout
		menu.login_reward_popup.visible = false
	)
