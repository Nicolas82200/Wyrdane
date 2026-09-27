extends GutTest

# Couvre BackendClient.parse_lobby_id (scripts/net/BackendClient.gd) : les ids
# de lobby Steam sont des CSteamID 64 bits (57 bits significatifs) qui ne
# survivent pas à un double (53 bits de mantisse, arrondi à ±8 près). Le bug
# corrigé : l'id passait par un Number JavaScript côté backend, l'hôte créait
# le lobby 109775243137628014 mais l'invité tentait de rejoindre
# 109775243137628016 — refusé par Steam en code 2
# (k_EChatRoomEnterResponseDoesntExist), les deux joueurs repartant en boucle
# de matchmaking. L'id transite donc en chaîne de chiffres de bout en bout.
# parse_lobby_id est statique : on charge le script sans passer par l'autoload
# (le runner GUT en mode -s ne les initialise pas de façon fiable).

const BackendClientScript = preload("res://scripts/net/BackendClient.gd")

func test_parses_a_64_bit_lobby_id_from_a_string_without_losing_precision() -> void:
	assert_eq(BackendClientScript.parse_lobby_id("109775243137628014"), 109775243137628014,
		"un CSteamID 64 bits doit être restitué à l'unité près")

func test_parses_the_other_lobby_ids_seen_in_the_failing_logs() -> void:
	# Ids réels relevés dans les logs des deux joueurs : chacun était arrondi
	# au multiple de 16 le plus proche quand il passait par un double.
	for raw in ["109775243137758522", "109775243137760521", "109775243137913097"]:
		var parsed: int = BackendClientScript.parse_lobby_id(raw)
		assert_eq(str(parsed), raw, "l'id %s doit survivre au parsing" % raw)

func test_accepts_an_int_as_is() -> void:
	assert_eq(BackendClientScript.parse_lobby_id(109775243137628014), 109775243137628014,
		"un int Godot est déjà exact sur 64 bits")

func test_returns_zero_when_the_field_is_absent() -> void:
	# L'invité poll tant que l'hôte n'a pas rapporté son lobby : le champ est
	# alors absent et 0 signale « pas encore disponible » (voir
	# MatchmakingOverlay._on_queue_matched).
	assert_eq(BackendClientScript.parse_lobby_id(null), 0,
		"champ absent : 0, l'invité continue de repoller")

func test_returns_zero_on_an_unexpected_type() -> void:
	assert_eq(BackendClientScript.parse_lobby_id({}), 0, "type inattendu : 0, jamais une entrée en lobby hasardeuse")
