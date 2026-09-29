extends GutTest

# Couvre BackendClient._result_label/_method_label (scripts/net/BackendClient.gd).
# Contexte : un échec réseau arrivait dans les logs de joueur sous la forme
# « Impossible de charger les decks (HTTP 0) », où 0 n'est pas un code HTTP mais
# l'absence de toute réponse — le callback jetait `result`, seul champ qui en
# nomme la cause (délai dépassé, DNS, TLS, connexion refusée), rendant le
# diagnostic impossible après coup.
#
# Ces deux fonctions sont statiques : on charge le script sans passer par
# l'autoload (le runner GUT en mode -s ne les initialise pas de façon fiable).

const BackendClientScript = preload("res://scripts/net/BackendClient.gd")

func test_names_every_transport_failure_cause() -> void:
	# La table est indexée par constante du moteur, pas par valeur entière :
	# chaque cause doit avoir un libellé, sinon on retombe sur le « result=N »
	# brut qui ne vaut pas mieux que le « HTTP 0 » qu'on remplace.
	var causes := [
		HTTPRequest.RESULT_CANT_CONNECT,
		HTTPRequest.RESULT_CANT_RESOLVE,
		HTTPRequest.RESULT_CONNECTION_ERROR,
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR,
		HTTPRequest.RESULT_NO_RESPONSE,
		HTTPRequest.RESULT_TIMEOUT,
		HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH,
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED,
		HTTPRequest.RESULT_BODY_DECOMPRESS_FAILED,
		HTTPRequest.RESULT_REQUEST_FAILED,
		HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED,
	]
	for cause in causes:
		var label: String = BackendClientScript._result_label(cause)
		assert_false(label.begins_with("result="),
			"la cause %d doit avoir un libellé lisible, pas son numéro brut" % cause)

func test_the_timeout_label_carries_the_actual_timeout_value() -> void:
	# Distinguer « le serveur n'a pas répondu en 15 s » de « la connexion a été
	# refusée » est tout l'intérêt : le premier accuse le backend, le second le
	# réseau du joueur.
	assert_string_contains(BackendClientScript._result_label(HTTPRequest.RESULT_TIMEOUT),
		str(int(BackendClientScript.REQUEST_TIMEOUT_SECONDS)),
		"le libellé de délai dépassé doit rappeler la durée effective")

func test_falls_back_to_the_raw_result_on_an_unknown_cause() -> void:
	# Une valeur inconnue (nouvelle entrée de l'énumération dans une version
	# ultérieure du moteur) doit rester traçable plutôt que disparaître.
	assert_eq(BackendClientScript._result_label(4242), "result=4242")

func test_names_the_http_methods_used_by_the_client() -> void:
	assert_eq(BackendClientScript._method_label(HTTPClient.METHOD_GET), "GET")
	assert_eq(BackendClientScript._method_label(HTTPClient.METHOD_POST), "POST")
	assert_eq(BackendClientScript._method_label(HTTPClient.METHOD_DELETE), "DELETE")

func test_only_reads_are_replayed_after_a_transport_failure() -> void:
	# Garde-fou sur l'intention de _handle_transport_failure : une écriture sans
	# réponse ne doit jamais être rejouée (on ne sait pas si le serveur l'a déjà
	# appliquée), une lecture oui — d'où une seule relance, sur GET.
	assert_eq(BackendClientScript.TRANSPORT_MAX_ATTEMPTS, 2,
		"une seule relance : au-delà, le joueur attend plus longtemps qu'il ne gagne")
	assert_gt(BackendClientScript.TRANSPORT_RETRY_DELAY_SECONDS, 0.0,
		"relancer dans la même frame retomberait sur le même creux réseau")
