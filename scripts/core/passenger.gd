## Identité d'un passager, vraie (`CaseKey.truth`) ou présentée
## (`Case.passenger_presented`) — ARCHITECTURE §5.1, §5.3.
##
## Les noms de propriétés sont les `truth_path` des `FieldDef` : la
## `DocumentFactory` (M3) recopie `passenger.get(truth_path)` dans les champs.
## Le générateur arrive en M3 ; en M2, les tests construisent les passagers à la
## main (`tests/helpers/case_factory.gd`).
class_name Passenger
extends RefCounted

# Codes de valeurs (champs ENUM) — affichés via des clés de traduction.
const SEX_F: StringName = &"F"
const SEX_M: StringName = &"M"
const SEX_X: StringName = &"X"
const PURPOSE_WORK: StringName = &"work"
const PURPOSE_FAMILY_VISIT: StringName = &"family_visit"
const PURPOSE_RETURN: StringName = &"return"
const PURPOSE_TRADE: StringName = &"trade"
const PURPOSE_TRANSIT: StringName = &"transit"
const PURPOSE_DIPLOMATIC: StringName = &"diplomatic"
const HEALTH_FIT: StringName = &"fit"
const HEALTH_QUARANTINE: StringName = &"quarantine"
const HEALTH_REVIEW: StringName = &"review"

## Propriétés utilisables comme `FieldDef.truth_path` (hors préfixe `document.`).
const TRUTH_PATHS: Array[StringName] = [
	&"given_name", &"family_name", &"birth_date", &"sex", &"faction_id",
	&"origin_sector", &"citizen_id", &"citizen_class", &"appearance",
	&"purpose", &"stay_days", &"employer", &"health_status", &"implants",
]

var id: StringName = &""
var given_name: String = ""
var family_name: String = ""
## Jour de jeu (`GameDate`).
var birth_date: int = 0
var sex: StringName = SEX_X
## Origine = `FactionDef.id` (ex. `&"tyc"`).
var faction_id: StringName = &""
var origin_sector: String = ""
## Format `HG-NNNN-XXXX` ; le 1er chiffre du bloc encode l'origine (LORE §5).
var citizen_id: String = ""
## Classe citoyenne (ex. `&"C-3"`).
var citizen_class: StringName = &""
## Traçabilité de l'apparence (§9.3).
var appearance_seed: int = 0
var appearance: PassengerAppearance = null
var purpose: StringName = &""
var stay_days: int = 0
var employer: String = ""
## Statut sanitaire réel (bio-scan, 🟡 GDD `BIOSCAN_UNFIT`).
var health_status: StringName = HEALTH_FIT
## Implants **visibles** sur le corps (M7, LORE §8 : `OPT-3`, `MIL-9`…). La
## carte d'identité recopie les implants *déclarés* (champ LIST `implants`) ;
## un écart est une discordance (R15). Jamais une donnée d'apparence : les
## injecteurs peuvent la modifier sans toucher `appearance` (invariant §9.3).
var implants: PackedStringArray = []


static func has_truth_path(path: StringName) -> bool:
	return TRUTH_PATHS.has(path)


## Valeur de vérité pour un `truth_path` (null + erreur si inconnu).
func get_truth(path: StringName) -> Variant:
	if not has_truth_path(path):
		push_error("Passenger.get_truth: truth_path inconnu « %s »" % path)
		return null
	return get(path)


## Applique des surcharges (cas scénarisés). Renvoie les clés refusées.
func apply_overrides(overrides: Dictionary) -> PackedStringArray:
	var rejected: PackedStringArray = []
	for key: Variant in overrides:
		var path: StringName = StringName(str(key))
		if not has_truth_path(path) and path != &"id":
			rejected.append(String(path))
			continue
		var value: Variant = overrides[key]
		if typeof(value) != typeof(get(path)) and get(path) != null:
			rejected.append(String(path))
			continue
		if value is PackedStringArray:
			# Copie : un tableau partagé avec la définition (`.tres`) ne doit jamais être muté.
			var list: PackedStringArray = value
			value = list.duplicate()
		set(path, value)
	return rejected


## Copie profonde (l'apparence est dupliquée).
func copy() -> Passenger:
	var result: Passenger = Passenger.new()
	result.id = id
	result.appearance_seed = appearance_seed
	for path: StringName in TRUTH_PATHS:
		result.set(path, get(path))
	result.implants = implants.duplicate()
	result.appearance = appearance.copy() if appearance != null else null
	return result


func full_name() -> String:
	return "%s %s" % [given_name, family_name]


## Désignation courte « M. VASQUEZ-ORLOV » (registre, bilan).
func short_label() -> String:
	var initial: String = given_name.left(1).to_upper()
	return ("%s. %s" % [initial, family_name]).to_upper() if not initial.is_empty() else family_name.to_upper()
