## État partagé par les injecteurs d'un cas (ARCHITECTURE §9.2 étape 5).
##
## Porte le cas en cours de corruption, la vérité terrain, le contexte de
## règles et la mémoire des champs déjà touchés : jamais deux anomalies sur le
## même champ, anomalies de visage mutuellement exclusives (GDD §6).
class_name InjectionState
extends RefCounted

## Clé « document entier » dans `used` (document retiré ou remplacé).
const WHOLE_DOCUMENT: String = "*"

var case: Case = null
## Identité réelle (`CaseKey.truth`) ; seul `IMPOSTOR_LOOKALIKE` la change.
var truth: Passenger = null
var rng: SeededRng = null
var ctx: RuleContext = null
var data: DataCatalog = null
var appearance_gen: AppearanceGenerator = null
## Paramètres imposés (cas scénarisés : `ScriptedCaseDef.injection_params`).
var params: Dictionary = {}
## Clés `document/champ` (ou `document/*`) déjà touchées.
var used: Dictionary[String, bool] = {}
var face_anomaly: bool = false


func get_rule_set() -> RuleSet:
	return ctx.rule_set


func get_day_number() -> int:
	return ctx.day_def.day_number if ctx.day_def != null else 0


func get_faction(faction_id: StringName) -> FactionDef:
	return data.factions.get(faction_id, null)


## Paramètre imposé ou valeur par défaut.
func param(key: StringName, default: Variant) -> Variant:
	return params.get(key, default)


## Paramètre entier imposé, sinon `default`.
func param_int(key: StringName, default: int) -> int:
	var value: Variant = params.get(key, default)
	if value is int:
		var result: int = value
		return result
	return default


## Paramètre booléen imposé, sinon `default`.
func param_bool(key: StringName, default: bool) -> bool:
	var value: Variant = params.get(key, default)
	if value is bool:
		var result: bool = value
		return result
	return default


## Vrai si le champ (et son document) est encore libre.
func is_free(document_id: StringName, field_id: StringName) -> bool:
	return not used.has(_key(document_id, field_id)) and not used.has(_key(document_id, &""))


## Vrai si aucun champ du document n'a encore été touché.
func is_document_untouched(document_id: StringName) -> bool:
	var prefix: String = "%s/" % document_id
	for key: String in used:
		if key.begins_with(prefix):
			return false
	return true


func mark(document_id: StringName, field_id: StringName) -> void:
	used[_key(document_id, field_id)] = true


## Documents présents imposés par `param("document_id")` (sinon tous).
func filter_documents(document_ids: Array[StringName]) -> Array[StringName]:
	var forced: StringName = StringName(str(param(&"document_id", "")))
	if forced == &"":
		return document_ids
	var result: Array[StringName] = []
	if document_ids.has(forced):
		result.append(forced)
	return result


func _key(document_id: StringName, field_id: StringName) -> String:
	return "%s/%s" % [document_id, field_id if field_id != &"" else StringName(WHOLE_DOCUMENT)]
