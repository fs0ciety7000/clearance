## Catalogue de la fouille holographique (M13, docs/M13.md §2.2–§2.7 ; B69, B73)
## — `data/search/search_catalog.tres`, produit par `tools/build_data_m13.gd`.
##
## Objets (OL-01 → OL-10, CB-01 → CB-08), zones (Z1 → Z5), indices (IV-1 →
## IV-5 : didascalie, zone visée, probabilité que l'objet du porteur s'y
## trouve, explication légitime d'un innocent), localisation des implants
## dissimulables (`ImplantCatalog.location`), contrebande par origine et taux
## de la fouille de base. Données seulement : lu par `SearchGenerator` et par
## les injecteurs `CONTRABAND`, `CONCEALED_IMPLANT`, `CONCEALED_WEAPON`.
class_name SearchCatalogDef
extends Resource

## Zones et indices : constantes de `SearchLayout` (lot A). IV-6 (réponse
## évasive à `q_cargo`) n'est pas un indice visible : étiquette de dialogue.
const CUE_EVASIVE: StringName = &"evasive"

@export var items: Array[SearchItemDef] = []

@export_group("Indices")
## Indice → probabilité que l'objet d'un porteur soit dans la zone de l'indice.
@export var cue_hit_rates: Dictionary[StringName, float] = {}
## Indice → objet légitime qui l'explique chez un innocent (`satchel` → `ol03`).
@export var cue_explanations: Dictionary[StringName, StringName] = {}
## Indice → libellé court du motif (`srch_cue_glove`).
@export var cue_motive_keys: Dictionary[StringName, String] = {}

@export_group("Implants")
## Code d'implant dissimulable → zone (LORE §8 : `NX-12` → `z1`, `KIN-11` → `z3`…).
## Un code absent est de localisation visible (tête, cou, main).
@export var implant_zones: Dictionary[String, StringName] = {}
## Implants dissimulés **déclarés** (OL-10) par origine (codes civils).
@export var civil_concealed: Dictionary[StringName, PackedStringArray] = {}
## Implants dissimulés non déclarés (`CONCEALED_IMPLANT`) : civils et `MIL-`.
@export var undeclared_civil: PackedStringArray = []
@export var undeclared_military: PackedStringArray = []
## Implant dont le contenu n'est pas lisible au portique (`DER-19`, SC-47).
@export var unreadable_implants: PackedStringArray = []

@export_group("Génération")
## Contrebande par origine (`cer` → [`cb01`, `cb05`]…) ; repli : `default_contraband`.
@export var contraband_by_faction: Dictionary[StringName, PackedStringArray] = {}
@export var default_contraband: PackedStringArray = []
@export var weapons: PackedStringArray = []
## Fouille de base : objet légitime en Z1–Z4 avec cette probabilité ; 1 à 3 objets en Z5.
@export_range(0.0, 1.0) var body_item_rate: float = 0.3
@export var baggage_items: Vector2i = Vector2i(1, 3)
## Part des passagers (J8+) porteurs d'un implant dissimulé **déclaré** (OL-10).
@export_range(0.0, 1.0) var declared_concealed_rate: float = 0.08
## « Quelque chose à déclarer ? » : réponse évasive (IV-6) chez les innocents,
## chez les porteurs dont c'est l'indice principal, et part de ces porteurs.
@export_range(0.0, 1.0) var evasive_innocent_rate: float = 0.05
@export_range(0.0, 1.0) var evasive_carrier_rate: float = 0.70
@export_range(0.0, 1.0) var evasive_carrier_share: float = 0.1667
## Premier jour du portique (avant : aucun implant de localisation dissimulée).
@export var first_day: int = 8


func get_item(item_id: StringName) -> SearchItemDef:
	for item: SearchItemDef in items:
		if item != null and item.id == item_id:
			return item
	return null


## Objets d'une catégorie autorisés dans une zone.
func items_for(kind: SearchItem.Kind, zone: StringName) -> Array[SearchItemDef]:
	var result: Array[SearchItemDef] = []
	for item: SearchItemDef in items:
		if item != null and item.kind == kind and item.can_be_in(zone):
			result.append(item)
	return result


## Zone d'un implant (`&""` si sa localisation est visible).
func implant_zone(code: String) -> StringName:
	return implant_zones.get(code, &"")


## Vrai si l'implant peut être porté dissimulé (localisation non visible).
func is_concealable(code: String) -> bool:
	return implant_zones.has(code)


## Contrebande tirable par un porteur de cette origine.
func contraband_for(faction_id: StringName) -> PackedStringArray:
	return contraband_by_faction.get(faction_id, default_contraband)
