extends GutTest

# SteamP2PGuard.is_lobby_member() dépend du singleton Steam réel (hors de
# portée d'un test unitaire, voir CLAUDE.md « Tests automatisés ») — seule sa
# partie purement algorithmique (extract_remote_id, qui ne parse qu'un
# Dictionary) est testable ici sans Steam.

func test_extract_remote_id_from_raw_steam_id() -> void:
	var connection := {"identity": 76561198000000001}
	assert_eq(SteamP2PGuard.extract_remote_id(connection), 76561198000000001)

func test_extract_remote_id_from_dictionary_identity_steam_id_key() -> void:
	var connection := {"identity": {"steam_id": 76561198000000002}}
	assert_eq(SteamP2PGuard.extract_remote_id(connection), 76561198000000002)

func test_extract_remote_id_from_dictionary_identity_steamid_key() -> void:
	# Selon la version de GodotSteam, la clé peut être "steamid" (sans
	# underscore) plutôt que "steam_id" — les deux formes doivent être gérées.
	var connection := {"identity": {"steamid": 76561198000000003}}
	assert_eq(SteamP2PGuard.extract_remote_id(connection), 76561198000000003)

func test_extract_remote_id_defaults_to_zero_when_missing() -> void:
	assert_eq(SteamP2PGuard.extract_remote_id({}), 0)
