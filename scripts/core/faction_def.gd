## Origine d'un passager (ARCHITECTURE §5.2, LORE §5) : un `.tres` par origine
## dans `res://data/factions/` (contenu : Lore Master).
##
## Le premier chiffre du bloc du N° ID encode l'origine : `id_prefix` = `"HG-4"`
## pour Tycho. Ajouts M3 (générateur) : réserve de noms (`NamePool`), poids
## des classes citoyennes et des motifs, employeurs typiques (LORE §4–§6).
class_name FactionDef
extends Resource

@export var id: StringName = &""
@export var name_key: String = ""
## Code d'origine à 3 lettres (champ « Origine », MRZ) : `"TYC"`.
@export var code: String = ""
## Préfixe du N° ID : `"HG-"` + chiffre d'origine.
@export var id_prefix: String = ""
## Secteurs d'origine (champ « Zone » de l'Attestation d'asile, onglet
## Origines du Rulebook) : textes **français** des données, tirés par le
## générateur sans dépendre de la langue (D-224) ; affichés traduits par la clé
## `sector_key(i)` (M15, lot U).
@export var origin_sectors: PackedStringArray = []
## Sceau / emblème (asset, M4+) ; null en M2.
@export var seal_texture: Texture2D = null

@export_group("Générateur (M3)")
## Prénoms et noms de cette origine (`res://data/names/namepool_<id>.tres`).
@export var name_pool: NamePool = null
## Classe citoyenne → poids (`&"C-3"`…).
@export var citizen_class_weights: Dictionary[StringName, float] = {}
## Motif de visite (`Passenger.PURPOSE_*`) → poids.
@export var purpose_weights: Dictionary[StringName, float] = {}
## Employeurs typiques (champ « Employeur », LORE §6).
@export var employers: PackedStringArray = []
## M7 (LORE §8) : part des passagers porteurs d'un implant civil visible
## (tiré seulement les jours où la règle R15 est active) et implants tirables.
@export_range(0.0, 1.0) var implant_rate: float = 0.0
@export var implant_weights: Dictionary[StringName, float] = {}
## Part des passagers générés nés à une date « année seule » `00.00.AAAA`
## (Dérivants, NARRATIVE §4.10 : 0.5). Décidé sans tirage (empreinte du N° ID).
@export_range(0.0, 1.0) var year_only_birth_rate: float = 0.0


## Vrai si le N° ID est cohérent avec cette origine (règle R10, GDD §7).
func matches_citizen_id(citizen_id: String) -> bool:
	return not id_prefix.is_empty() and citizen_id.begins_with(id_prefix)


## Chiffre d'origine (4 pour `"HG-4"`), −1 si le préfixe est mal formé.
func get_id_block_digit() -> int:
	var digit: String = id_prefix.right(1)
	return digit.to_int() if digit.is_valid_int() else -1


## M15 (lot U) : clé de traduction du secteur `index` (0…) de `origin_sectors`
## — `faction_<id>_sector_<n>`, n = index + 1. Affichage seulement : la valeur
## stockée dans le passager reste le texte des données.
func sector_key(index: int) -> String:
	return "faction_%s_sector_%d" % [id, index + 1]
