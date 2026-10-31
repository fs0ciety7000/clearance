## Textes de l'interface de comparaison : traduction avec repli, affichage des
## valeurs de champs, dates et horloge de shift (UI_FLOW §2.2, §4.8).
##
## Toutes les chaînes visibles passent par `tr()` sur une clé ; si la clé n'a
## pas de traduction, `t()` renvoie le repli fourni (ou la clé elle-même), ce
## qui garde l'UI lisible tant que `data/i18n/fr.csv` est incomplet.
## M15 : chaque texte produit garde sa recette (`remake`) pour la
## retraduction à chaud (`Localization`) ; clé absente en anglais → français.
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
## Champ dont la valeur est un secteur d'origine (`Passenger.origin_sector`).
const ORIGIN_SECTOR_PATH: StringName = &"origin_sector"
## M15 (lot U) : valeurs de champ texte qui ne sont pas des noms (mentions des
## données, en français) → clé d'affichage. La logique compare la donnée brute.
const DATA_TEXT_KEYS: Dictionary = {"SANS EMPLOYEUR": "val_no_employer"}
## Traductions : chargées par `Localization.ensure_loaded()` (FR source, EN
## M15, `Localization.TRANSLATION_PATHS`) ; locale de repli `fr`
## (`internationalization/locale/fallback`).
## M15 : nombre de recettes gardées par génération (deux générations).
const RECIPE_GENERATION: int = 20000

## M15 (retraduction à chaud, `Localization.retranslate_text`) : texte produit
## → recette `[clé, arguments, repli]` (`[&"upper", recette]` pour la même
## chaîne en capitales ; `[&"plural", clé, n, repli singulier, repli
## pluriel]` ; `[&"call", Callable]` pour un texte composé par une fonction,
## `remember_call`). Deux générations bornées : coût d'une insertion par appel.
static var _recipes: Dictionary = {}
static var _old_recipes: Dictionary = {}


## Enregistre les traductions auprès du `TranslationServer` (idempotent).
static func ensure_translations() -> void:
	Localization.ensure_loaded()


## Traduction de `key` ; `fallback` (ou la clé) si aucune traduction n'existe.
## Pseudo-localisation (debug) : le repli est pseudo-localisé lui aussi.
static func t(key: String, fallback: String = "") -> String:
	var out: String = _translate(key, fallback)
	_remember(out, [key, [], fallback])
	return out


static func _translate(key: String, fallback: String) -> String:
	ensure_translations()
	if key.is_empty():
		return fallback
	var translated: String = TranslationServer.translate(key)
	if translated == key:
		var text: String = fallback if not fallback.is_empty() else key
		return Localization.pseudo(text) if Localization.is_pseudo() and not fallback.is_empty() else text
	return Localization.pseudo(translated) if Localization.is_pseudo() else translated


## Accord singulier / pluriel : `<key>_one` si `count` ≤ 1, `<key>` sinon
## (les deux formats reçoivent `count`).
static func plural(key: String, count: int, fallback_one: String, fallback_many: String) -> String:
	var out: String
	if absi(count) <= 1:
		var one: String = _translate(key + "_one", fallback_one)
		out = one % count if one.contains("%d") else one
	else:
		out = _format(_translate(key, fallback_many), [count])
	_remember(out, [&"plural", key, count, fallback_one, fallback_many])
	return out


## Vrai si la clé a une traduction chargée.
static func has(key: String) -> bool:
	ensure_translations()
	# (pseudo-localisation : appliquée au texte, jamais à la clé)
	return not key.is_empty() and TranslationServer.translate(key) != key


## Traduction formatée (`%s`, `%d`…).
static func tf(key: String, args: Array, fallback: String = "") -> String:
	var pattern: String = _translate(key, fallback)
	_remember(pattern, [key, [], fallback])
	if args.is_empty():
		return pattern
	var out: String = _format(pattern, args)
	_remember(out, [key, args.duplicate(), fallback])
	return out


## `pattern % args`, sans planter sur une traduction au nombre de
## spécificateurs différent (repli : motif français).
static func _format(pattern: String, args: Array) -> String:
	var percents: int = pattern.count("%") - 2 * pattern.count("%%")
	if percents != args.size() and Localization.format_specs(pattern).size() != args.size():
		push_warning("UiText: spécificateurs incohérents dans « %s »" % pattern)
		return pattern
	return pattern % args


# ---------------------------------------------------------------------------
# M15 : recettes (retraduction à chaud)
# ---------------------------------------------------------------------------

static func _remember(text: String, recipe: Array) -> void:
	if text.is_empty():
		return
	if _recipes.size() >= RECIPE_GENERATION:
		_old_recipes = _recipes
		_recipes = {}
	_recipes[text] = recipe
	var upper: String = text.to_upper()
	if upper != text and not _recipes.has(upper):
		_recipes[upper] = [&"upper", recipe]


static func _recipe_of(text: String) -> Variant:
	if _recipes.has(text):
		return _recipes[text]
	if _old_recipes.has(text):
		return _old_recipes[text]
	return null


## Oublie toutes les recettes. Appelé à la sortie (`Settings._exit_tree`) :
## des `Callable` (lambdas, objets liés) gardés dans une variable statique
## jusqu'à l'arrêt du moteur corrompent la mémoire à la sortie (Godot 4.7.2).
static func clear_recipes() -> void:
	_recipes = {}
	_old_recipes = {}


## Vrai si `text` a été produit par `t` / `tf` / `plural` (recette connue).
static func has_recipe(text: String) -> bool:
	return _recipe_of(text) != null


## Recompose `text` dans la langue courante d'après sa recette ; null si le
## texte n'a pas été produit par `UiText` (nom propre, code, valeur…).
static func remake(text: String) -> Variant:
	var recipe: Variant = _recipe_of(text)
	if recipe == null:
		return null
	return _remake_recipe(recipe)


## Mémorise un texte composé par `maker` (rappelé tel quel dans la nouvelle
## langue) ; renvoie `text`.
static func remember_call(text: String, maker: Callable) -> String:
	_remember(text, [&"call", maker])
	return text


static func _remake_recipe(recipe: Array) -> String:
	if recipe.size() == 2 and recipe[0] is StringName and recipe[0] == &"call":
		var maker: Callable = recipe[1]
		return str(maker.call()) if maker.is_valid() else ""
	if recipe.size() == 2 and recipe[0] is StringName and recipe[0] == &"upper":
		return _remake_recipe(recipe[1]).to_upper()
	if recipe.size() == 5 and recipe[0] is StringName and recipe[0] == &"plural":
		return plural(recipe[1], recipe[2], recipe[3], recipe[4])
	var args: Array = recipe[1]
	if args.is_empty():
		return t(recipe[0], recipe[2])
	var new_args: Array = []
	for arg: Variant in args:
		new_args.append(Localization.retranslate_text(arg) if arg is String else arg)
	return tf(recipe[0], new_args, recipe[2])


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
			# M15 (lot U) : secteur d'origine traduit comme au Rulebook.
			if field.truth_path == ORIGIN_SECTOR_PATH:
				return RulebookReference.sector_text(str(value)).to_upper()
			# Mentions de procédure écrites en français dans les données (« SANS
			# EMPLOYEUR », comparé tel quel par R09) : traduites à l'affichage.
			var data_text: String = str(value).to_upper()
			if DATA_TEXT_KEYS.has(data_text):
				return t(DATA_TEXT_KEYS[data_text], data_text).to_upper()
			return data_text
	return FieldValue.to_display(value, field)


## M15 (lot U) : réplique ou devise entre guillemets de la langue courante
## (« … » en français, "…" en anglais, clé `ui_quoted`).
static func quoted(text: String) -> String:
	return tf("ui_quoted", [text], "« %s »")


## M15 (lot U) : « LOCUTEUR : « réplique » » selon la langue (`ui_speaker_quoted`).
static func speaker_quoted(speaker: String, text: String) -> String:
	return tf("ui_speaker_quoted", [speaker, text], "%s : « %s »")


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
	var text: String = "%s %s" % [t("weekday_%d" % weekday(days), "J%d" % (weekday(days) + 1)), date(days)]
	return remember_call(text, date_with_weekday.bind(days))


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
	return remember_call("%s %02d" % [noun, case.index + 1], passenger_number.bind(case))


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
