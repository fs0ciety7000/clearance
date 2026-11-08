## Configuration du client en ligne (M16, D-230 → D-235 ; contrat `docs/ONLINE.md`).
##
## - URL de base : `DEFAULT_BASE_URL` (production), surchargée par le réglage
##   **caché** `api_url` du fichier de compte (`OnlineStore`, jamais dans les
##   Options) ou, en debug (`DebugArgs.enabled`), par l'argument
##   `--online-url=http://127.0.0.1:8090`. `--online-fake` : faux serveur en
##   mémoire (`FakeOnlineServer`, captures et démonstrations ; jamais en
##   release sans la fonctionnalité `debug_args`).
## - Délais et nouvelles tentatives : ONLINE.md §1 (connexion 5 s, requête
##   10 s ; 2 s, 8 s, 30 s puis abandon jusqu'à la prochaine occasion,
##   seulement sur erreur réseau, 429 ou 5xx).
## - Libellé d'appareil (`device_label`) : « Deck », « Web », « PC », « Mac »,
##   « Linux » (champ `device` des sauvegardes).
## Pur (aucun autoload, aucun nœud).
class_name OnlineConfig
extends RefCounted

const DEFAULT_BASE_URL: String = "https://clearance-api.cardormedia.com"
## Version de l'API attendue (`GET /api/clearance/status` → `api_version`).
const API_VERSION: int = 1
## Délai d'une requête (s) : connexion + réponse (`HTTPRequest.timeout`).
const REQUEST_TIMEOUT_S: float = 10.0
## Nouvelles tentatives espacées (s) sur erreur réseau, 429 ou 5xx.
const RETRY_DELAYS_S: Array[float] = [2.0, 8.0, 30.0]
## Rafraîchissement du jeton dès qu'il a plus de 24 h (ONLINE.md §2.3).
const TOKEN_REFRESH_AFTER_S: int = 24 * 3600
## Longueur du code reçu par e-mail (ONLINE.md §2 ; `status.otp.length`).
const OTP_LENGTH: int = 6
## Pseudo public (ONLINE.md §2.4).
const PSEUDO_MAX_CHARS: int = 20
## Classement affiché : top N.
const LEADERBOARD_LIMIT: int = 10
## Cache local des statistiques de fins (s) : au plus une requête par 5 min.
const ENDING_STATS_MAX_AGE_S: int = 300
## Profil : nombre d'essais sur `409 rev_conflict` (ONLINE.md §5.5).
const PROFILE_MERGE_ATTEMPTS: int = 3


## URL de base effective : argument de debug, sinon réglage caché `api_url`
## (`stored`), sinon la constante de production. Sans « / » final.
static func base_url(stored: String = "") -> String:
	var url: String = DEFAULT_BASE_URL
	if not stored.strip_edges().is_empty():
		url = stored.strip_edges()
	var arg: String = debug_arg("online-url")
	if not arg.is_empty():
		url = arg
	return url.trim_suffix("/")


## Valeur d'un argument de debug (`--name=value`), vide hors debug ou absent.
static func debug_arg(name: String) -> String:
	if not DebugArgs.enabled():
		return ""
	var args: Dictionary = DebugArgs.parse(OS.get_cmdline_user_args())
	if not args.has(name):
		return ""
	var value: String = str(args[name])
	return value if value != "true" else ""


## Faux serveur demandé (`--online-fake`, debug seulement).
static func fake_requested() -> bool:
	if not DebugArgs.enabled():
		return false
	return DebugArgs.parse(OS.get_cmdline_user_args()).has("online-fake")


## Libellé court de l'appareil (champ `device`, ≤ 32 caractères).
static func device_label() -> String:
	if OS.has_feature("web"):
		return "Web"
	if OS.get_environment("SteamDeck") == "1":
		return "Deck"
	match OS.get_name():
		"Windows":
			return "PC"
		"macOS":
			return "Mac"
		"Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			return "Linux"
	return OS.get_name().left(32)


## Adresse e-mail plausible (contrôle local avant l'envoi ; le serveur reste juge).
static func is_valid_email(email: String) -> bool:
	var text: String = email.strip_edges()
	if text.length() < 5 or text.length() > 254 or text.contains(" "):
		return false
	var at: int = text.find("@")
	if at <= 0 or at != text.rfind("@"):
		return false
	var domain: String = text.substr(at + 1)
	return domain.contains(".") and not domain.begins_with(".") and not domain.ends_with(".")


## Adresse masquée pour l'affichage (« a•••@e•••.org ») ; jamais journalisée.
static func mask_email(email: String) -> String:
	var text: String = email.strip_edges()
	var at: int = text.find("@")
	if at <= 0:
		return "•••"
	var local: String = text.left(at)
	var domain: String = text.substr(at + 1)
	var dot: int = domain.rfind(".")
	var host: String = domain.left(dot) if dot > 0 else domain
	var tld: String = domain.substr(dot) if dot > 0 else ""
	return "%s•••@%s•••%s" % [local.left(1), host.left(1), tld]


## Code saisi réduit à ses chiffres (espaces et tirets retirés, ONLINE.md §2.2).
static func clean_code(text: String) -> String:
	var out: String = ""
	for c: String in text:
		if c >= "0" and c <= "9":
			out += c
	return out


## Pseudo nettoyé (bords) et borné ; vide = anonyme.
static func clean_pseudo(text: String) -> String:
	return text.strip_edges().left(PSEUDO_MAX_CHARS)


## Pseudo admis localement (lettres de toutes écritures, chiffres, espace, `_ . ' -`).
static func is_valid_pseudo(text: String) -> bool:
	var clean: String = text.strip_edges()
	if clean.length() > PSEUDO_MAX_CHARS:
		return false
	var regex: RegEx = RegEx.create_from_string("^[\\p{L}\\p{N} _.'\\-]*$")
	return regex.search(clean) != null
