## Textes de l'interface de comparaison : traduction avec repli, affichage des
## valeurs de champs, dates et horloge de shift (UI_FLOW §2.2, §4.8).
##
## Toutes les chaînes visibles passent par `tr()` sur une clé ; si la clé n'a
## pas de traduction, `t()` renvoie le repli fourni (ou la clé elle-même), ce
## qui garde l'UI lisible tant que `data/i18n/fr.csv` est incomplet.
## Classe utilitaire : fonctions statiques uniquement.
class_name UiText
extends RefCounted

## Heure d'ouverture / de fermeture du guichet (minutes depuis minuit) :
## un shift = 8 h in-game (UI_FLOW §1).
const SHIFT_START_MIN: int = 10 * 60
const SHIFT_END_MIN: int = 18 * 60
## Seuil « FIN DE SHIFT PROCHE » : 30 min in-game (UI_FLOW §1).
const SHIFT_WARN_MIN: int = 30
## Jour de la semaine du jour 0 de `GameDate` (01.01.2100 = vendredi, 0 = lundi).
const EPOCH_WEEKDAY: int = 4
## Préfixe des clés de valeurs ENUM (`val_work` → « TRAVAIL »).
const VALUE_KEY_PREFIX: String = "val_"
## Traductions générées par l'import de `res://data/i18n/fr.csv` (fichiers
## `.translation` ignorés par git, régénérés par `godot --import`). Chargées
## à la demande plutôt que déclarées dans `project.godot` : un clone neuf ne
## lève pas d'erreur avant le premier import. Locale de repli : `fr`
## (`internationalization/locale/fallback`).
const TRANSLATION_PATHS: PackedStringArray = ["res://data/i18n/fr.fr.translation"]

static var _translations_loaded: bool = false


## Enregistre les traductions FR auprès du `TranslationServer` (idempotent).
static func ensure_translations() -> void:
	if _translations_loaded:
		return
	_translations_loaded = true
	for path: String in TRANSLATION_PATHS:
		if not ResourceLoader.exists(path):
			push_warning("UiText: traduction absente (%s) — lancer `godot --headless --import`." % path)
			continue
		var translation: Translation = load(path) as Translation
		if translation != null:
			TranslationServer.add_translation(translation)


## Traduction de `key` ; `fallback` (ou la clé) si aucune traduction n'existe.
static func t(key: String, fallback: String = "") -> String:
	ensure_translations()
	if key.is_empty():
		return fallback
	var translated: String = TranslationServer.translate(key)
	if translated == key:
		return fallback if not fallback.is_empty() else key
	return translated


## Vrai si la clé a une traduction chargée.
static func has(key: String) -> bool:
	ensure_translations()
	return not key.is_empty() and TranslationServer.translate(key) != key


## Traduction formatée (`%s`, `%d`…).
static func tf(key: String, args: Array, fallback: String = "") -> String:
	var pattern: String = t(key, fallback)
	if args.is_empty():
		return pattern
	return pattern % args


## Valeur affichée d'un champ (jamais tronquée, capitales pour les codes).
static func value_text(field: FieldDef, value: Variant) -> String:
	if field == null or value == null:
		return "—"
	match field.kind:
		FieldDef.FieldKind.ENUM:
			var code: String = str(value)
			return t(VALUE_KEY_PREFIX + code.to_lower(), code.to_upper())
		FieldDef.FieldKind.BOOL:
			var flag: bool = value
			return t("val_yes" if flag else "val_no", "OUI" if flag else "NON")
		FieldDef.FieldKind.NUMBER:
			if field.id == &"stay_days":
				var days_count: int = value
				return tf("unit_days", [days_count], "%d JOURS")
			return str(value)
		FieldDef.FieldKind.TEXT:
			return str(value).to_upper()
	return FieldValue.to_display(value, field)


## Libellé d'un champ (clé `label_key`, repli : identifiant en capitales).
static func field_label(field: FieldDef) -> String:
	if field == null:
		return ""
	return t(field.label_key, String(field.id).replace("_", " ").to_upper())


## Titre d'un type de document.
static func document_title(def: DocumentTypeDef) -> String:
	if def == null:
		return ""
	return t(def.title_key, String(def.id).replace("_", " ").to_upper())


## Nom de l'émetteur (`issuer_<id>`).
static func issuer_name(issuer_id: StringName) -> String:
	return t("issuer_%s" % issuer_id, String(issuer_id).replace("_", " ").to_upper())


## « 19.03.2187 ».
static func date(days: int) -> String:
	return GameDate.format(days)


## Jour de la semaine (0 = lundi … 6 = dimanche).
static func weekday(days: int) -> int:
	return posmod(days + EPOCH_WEEKDAY, 7)


## « MER. 19.03.2187 ».
static func date_with_weekday(days: int) -> String:
	return "%s %s" % [t("weekday_%d" % weekday(days), "J%d" % (weekday(days) + 1)), date(days)]


## Minutes in-game écoulées depuis l'ouverture, d'après le temps réel restant.
static func shift_minutes(remaining_sec: float, duration_sec: float) -> int:
	if duration_sec <= 0.0:
		return SHIFT_START_MIN
	var progress: float = clampf(1.0 - remaining_sec / duration_sec, 0.0, 1.0)
	return SHIFT_START_MIN + floori(progress * (SHIFT_END_MIN - SHIFT_START_MIN))


## « 14:37 ».
static func clock(minutes: int) -> String:
	@warning_ignore("integer_division")
	var hours: int = minutes / 60
	return "%02d:%02d" % [hours, minutes % 60]


## Désignation d'un passager tant que ses papiers ne sont pas posés
## (« PASSAGÈRE 09 », UI_FLOW §4.2).
static func passenger_number(case: Case) -> String:
	if case == null:
		return ""
	var feminine: bool = case.passenger_presented != null and case.passenger_presented.sex == Passenger.SEX_F
	var noun: String = t("speaker_passenger_f" if feminine else "speaker_passenger", "PASSAGÈRE" if feminine else "PASSAGER")
	return "%s %02d" % [noun, case.index + 1]


## Nom affiché une fois les documents posés (nom tel que présenté).
static func passenger_name(case: Case) -> String:
	if case == null or case.passenger_presented == null:
		return ""
	var p: Passenger = case.passenger_presented
	var initial: String = p.given_name.left(1).to_upper()
	return ("%s. %s" % [initial, p.family_name]).to_upper() if not initial.is_empty() else p.family_name.to_upper()


## Durée d'affichage d'un sous-titre (UI_FLOW §4.8).
static func subtitle_hold(text: String) -> float:
	return maxf(DS.SUBTITLE_MIN_HOLD, DS.SUBTITLE_PER_CHAR * text.length())
