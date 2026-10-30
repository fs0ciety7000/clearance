## Contenu d'une fouille holographique, par zones (M13, D-140, D-145 ; ARCHITECTURE §12.3).
##
## Partie du cas (`Case.search_layout`), générée avec lui (lot B : objets
## légitimes, contrebande, implants dissimulés, explication légitime des
## indices), **cachée jusqu'au scan** et jamais lue dans `CaseKey` : R45 / R46
## la lisent pour le verdict attendu, qui existe donc sans fouille (D-005).
## État de session : `scanned_zones` et `SearchItem.revealed`, posés par
## `InspectionSession` (`scan`).
##
## Constantes partagées par la fouille : zones Z1 → Z5, indices IV-1 → IV-5,
## motifs MF-1 → MF-5 (M13 §2.4).
class_name SearchLayout
extends RefCounted

# Zones (M13 §2.2) — textes `zone_z1` … `zone_z5`.
const ZONE_HEAD: StringName = &"z1"
const ZONE_TORSO: StringName = &"z2"
const ZONE_ARMS: StringName = &"z3"
const ZONE_LEGS: StringName = &"z4"
const ZONE_LUGGAGE: StringName = &"z5"
const ZONES: Array[StringName] = [ZONE_HEAD, ZONE_TORSO, ZONE_ARMS, ZONE_LEGS, ZONE_LUGGAGE]
## Demande « TOUT SCANNER » (`EventBus.search_requested(&"all")`).
const ZONE_ALL: StringName = &"all"

# Indices visibles (`Case.search_cues`, IV-1 → IV-5) — didascalies `cue_<id>[_m|_f]`.
const CUE_SATCHEL: StringName = &"satchel"
const CUE_BULGE: StringName = &"bulge"
const CUE_GLOVE: StringName = &"glove"
const CUE_GAIT: StringName = &"gait"
const CUE_COLLAR: StringName = &"collar"
const CUES: Array[StringName] = [CUE_SATCHEL, CUE_BULGE, CUE_GLOVE, CUE_GAIT, CUE_COLLAR]
## Zone visée par chaque indice (chez un porteur, avec la probabilité de M13 §2.4).
const CUE_ZONES: Dictionary[StringName, StringName] = {
	CUE_SATCHEL: ZONE_LUGGAGE,
	CUE_BULGE: ZONE_TORSO,
	CUE_GLOVE: ZONE_ARMS,
	CUE_GAIT: ZONE_LEGS,
	CUE_COLLAR: ZONE_HEAD,
}
## Indices genrés (`cue_satchel_m` / `cue_satchel_f`).
const GENDERED_CUES: Array[StringName] = [CUE_SATCHEL]

# Motifs de fouille (MF-1 → MF-5), figés à la demande (`Verdict.search_motive`) ;
# `&""` = aucun motif. Textes `srch_motive_<motif>`.
const MOTIVE_NONE: StringName = &""
const MOTIVE_DISCORD: StringName = &"discord"
const MOTIVE_CUE: StringName = &"cue"
const MOTIVE_EVASIVE: StringName = &"evasive"
const MOTIVE_DIRECTIVE: StringName = &"directive"
const MOTIVE_MANDATORY: StringName = &"mandatory"
const MOTIVES: Array[StringName] = [MOTIVE_DISCORD, MOTIVE_CUE, MOTIVE_EVASIVE, MOTIVE_DIRECTIVE, MOTIVE_MANDATORY]

var items: Array[SearchItem] = []
## Zones déjà scannées dans la session (ordre du scan).
var scanned_zones: Array[StringName] = []


## Place `item` dans `zone` (rang = nombre d'objets déjà dans la zone) et
## renvoie l'objet.
func add(zone: StringName, item: SearchItem) -> SearchItem:
	item.zone = zone
	item.index = items_in(zone).size()
	item.id = StringName("%s:%d" % [zone, item.index])
	items.append(item)
	return item


func items_in(zone: StringName) -> Array[SearchItem]:
	var result: Array[SearchItem] = []
	for item: SearchItem in items:
		if item.zone == zone:
			result.append(item)
	return result


func is_empty() -> bool:
	return items.is_empty()


func get_item(zone: StringName, index: int) -> SearchItem:
	for item: SearchItem in items:
		if item.zone == zone and item.index == index:
			return item
	return null


## Objet désigné par une référence `FieldRef.scan` (null sinon).
func get_item_by_ref(ref: FieldRef) -> SearchItem:
	if ref == null or not ref.is_scan():
		return null
	return get_item(ref.get_scan_zone(), ref.get_scan_index())


func is_scanned(zone: StringName) -> bool:
	return scanned_zones.has(zone)


## Scanne une zone : objets révélés (renvoyés, éventuellement vides : « RAS »).
func scan(zone: StringName) -> Array[SearchItem]:
	if not ZONES.has(zone):
		return []
	if not scanned_zones.has(zone):
		scanned_zones.append(zone)
	var found: Array[SearchItem] = items_in(zone)
	for item: SearchItem in found:
		item.revealed = true
	return found


func revealed_items() -> Array[SearchItem]:
	var result: Array[SearchItem] = []
	for item: SearchItem in items:
		if item.revealed:
			result.append(item)
	return result


## Implants dissimulés présents (déclarés ou non), révélés ou non.
func implant_codes() -> PackedStringArray:
	var result: PackedStringArray = []
	for item: SearchItem in items:
		if item.is_implant() and not item.implant_code.is_empty():
			result.append(item.implant_code)
	return result


## Vrai si le scan a **montré** un objet interdit (R45, R46) ou un implant
## absent de `declared` (implants déclarés de la carte, visibles du joueur).
## Sert au relevé du PH-2 (AG-03 : `suspicion +1` à l'approbation) et à la
## réplique de fin de fouille. Un implant illisible (`DER-19`) ne compte pas.
func revealed_forbidden(declared: PackedStringArray) -> bool:
	for item: SearchItem in revealed_items():
		if item.is_forbidden():
			return true
		if item.is_implant() and not item.unreadable and not item.implant_code.is_empty() \
				and not declared.has(item.implant_code):
			return true
	return false


func copy() -> SearchLayout:
	var result: SearchLayout = SearchLayout.new()
	for item: SearchItem in items:
		result.items.append(item.copy())
	result.scanned_zones = scanned_zones.duplicate()
	return result


func serialize() -> Dictionary:
	var list: Array = []
	for item: SearchItem in items:
		list.append(item.serialize())
	return {"items": list}


## Zone visée par un indice (vide si inconnu).
static func zone_of_cue(cue: StringName) -> StringName:
	return CUE_ZONES.get(cue, &"")


## Clé de didascalie d'un indice (`cue_satchel_f`, `cue_glove`).
static func cue_line_key(cue: StringName, sex: StringName = &"") -> String:
	if GENDERED_CUES.has(cue):
		return "cue_%s_%s" % [cue, "f" if sex == Passenger.SEX_F else "m"]
	return "cue_%s" % cue
