extends GutTest

# Couvre SteamTransport._parse_steam_id (scripts/net/SteamTransport.gd), la
# porte d'entrée de l'identité de rendez-vous depuis le 2026-09-28 : la file
# backend ne renvoie plus un id de lobby à rejoindre mais le SteamID64 de
# l'adversaire, auquel on se connecte directement en P2P.
#
# Un SteamID64 occupe 57 bits significatifs : il ne survit PAS à un double (53
# bits de mantisse, arrondi à ±8 près). Le même piège a déjà cassé le
# matchmaking deux fois avec les ids de lobby (voir test_backend_lobby_id.gd),
# et la conséquence est ici pire : un id arrondi ne désigne pas « rien », il
# désigne QUELQU'UN D'AUTRE. D'où la règle verrouillée par ces tests — une
# identité arrive en chaîne de chiffres, et tout le reste vaut 0 (refus net)
# plutôt qu'une connexion vers un inconnu.
#
# La fonction est statique : on charge le script sans l'instancier (le runner
# GUT en mode -s n'initialise pas les autoloads de façon fiable, et un
# SteamTransport vivant tenterait de parler au singleton Steam).

const SteamTransportScript = preload("res://scripts/net/SteamTransport.gd")

func test_parses_a_64_bit_steam_id_from_a_string_without_losing_precision() -> void:
	assert_eq(SteamTransportScript._parse_steam_id("76561198012345678"), 76561198012345678,
		"un SteamID64 doit être restitué à l'unité près")

func test_parses_steam_ids_whose_last_digits_would_be_rounded_by_a_double() -> void:
	# Ces valeurs ne sont PAS représentables exactement en double : si un maillon
	# du chemin les lisait comme des nombres, elles désigneraient un autre compte.
	for raw in ["76561198000000001", "76561199123456789", "76561197960287931"]:
		assert_eq(str(SteamTransportScript._parse_steam_id(raw)), raw,
			"le SteamID %s doit survivre au parsing" % raw)

func test_accepts_an_int_as_is() -> void:
	# Toléré pour un appelant interne (reconnexion, test) : un int Godot est déjà
	# exact sur 64 bits. Ce qui est interdit, c'est un nombre venu du JSON.
	assert_eq(SteamTransportScript._parse_steam_id(76561198012345678), 76561198012345678,
		"un int Godot est déjà exact sur 64 bits")

func test_refuses_a_float_rather_than_connecting_to_the_wrong_account() -> void:
	# Cas d'un backend qui sérialiserait l'identité en nombre : la précision est
	# déjà perdue à ce stade, rien ne peut la récupérer. On refuse (0) au lieu de
	# se connecter à un compte voisin.
	assert_eq(SteamTransportScript._parse_steam_id(76561198012345678.0), 0,
		"une identité reçue en nombre flottant est refusée, jamais devinée")

func test_returns_zero_when_the_identity_is_missing_or_malformed() -> void:
	assert_eq(SteamTransportScript._parse_steam_id(""), 0, "chaîne vide : aucune identité")
	assert_eq(SteamTransportScript._parse_steam_id(null), 0, "champ absent : aucune identité")
	assert_eq(SteamTransportScript._parse_steam_id("76561198012345678abc"), 0,
		"chaîne non numérique : refusée telle quelle, jamais tronquée")
	assert_eq(SteamTransportScript._parse_steam_id({}), 0, "type inattendu : aucune identité")
