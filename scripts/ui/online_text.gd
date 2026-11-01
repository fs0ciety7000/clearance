## Textes de l'interface en ligne (M16) : messages d'erreur (clés
## `OnlineClient.ERR_*` → `online_err_*`), date de dernière synchronisation,
## nom affiché d'un classement, pourcentage d'une fin. Purs, retraduits à
## chaud (recettes `UiText`).
class_name OnlineText
extends RefCounted

const ERROR_FALLBACKS: Dictionary = {
	"network": "Serveur injoignable. Vos données restent sur cet appareil ; nouvel essai plus tard.",
	"session_expired": "Session expirée : reconnectez-vous.",
	"email_invalid": "Adresse e-mail invalide.",
	"otp_invalid": "Code incorrect ou expiré.",
	"otp_locked": "Trop d'essais pour ce code : demandez-en un nouveau.",
	"otp_missing": "Demandez d'abord un code.",
	"rate_limited": "Trop de demandes. Patientez quelques minutes.",
	"api_version": "Le serveur demande une version plus récente du jeu.",
	"quota": "Espace en ligne plein : supprimez des parties.",
	"too_large": "Sauvegarde trop volumineuse pour le cloud : elle reste sur cet appareil.",
	"pseudo_invalid": "Pseudo refusé : 20 caractères au plus, lettres, chiffres, espace, _ . ' -",
	"version_future": "Une sauvegarde du cloud vient d'une version plus récente du jeu : elle n'a pas été chargée.",
	"server": "Le serveur a refusé la demande.",
	"quiet": "Pendant un shift, rien n'est envoyé.",
	"no_account": "Aucun compte connecté.",
}


## Message d'une erreur (`OnlineClient.ERR_*`), vide si aucune.
static func error_text(error: String) -> String:
	if error.is_empty():
		return ""
	return UiText.t("online_err_%s" % error, str(ERROR_FALLBACKS.get(error, ERROR_FALLBACKS["server"])))


## « Dernière synchronisation : 01.11.2026 · 14:32 » (heure locale), « Jamais synchronisé. ».
static func last_sync_text(unix_ms: int) -> String:
	if unix_ms <= 0:
		return UiText.t("acct_last_sync_never", "Jamais synchronisé sur cet appareil.")
	var bias_s: int = SaveService.as_int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	@warning_ignore("integer_division")
	var when: String = SaveSlotCard.format_saved_at(Time.get_datetime_string_from_unix_time(unix_ms / 1000 + bias_s))
	return UiText.tf("acct_last_sync", [when], "Dernière synchronisation : %s")


## Nom affiché d'une ligne de classement (`pseudo`, sinon « Agent·e #TAG »).
static func board_name(entry: Dictionary) -> String:
	return OnlineClient.display_name_of(str(entry.get("pseudo", "")), str(entry.get("tag", "")))


## « 31 % des agents » (arrondi ; « < 1 % » au-dessous de 1).
static func ending_percent_text(percent: float) -> String:
	if percent > 0.0 and percent < 1.0:
		return UiText.remember_call(UiText.t("dos_end_percent_low", "Moins de 1 % des agents"),
				ending_percent_text.bind(percent))
	var value: String = Localization.percent(roundi(percent))
	return UiText.remember_call(UiText.tf("dos_end_percent", [value], "%s des agents"), ending_percent_text.bind(percent))
