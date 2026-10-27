## Apparence modulaire d'une personne (ARCHITECTURE §5.3, §9.3, D-012).
##
## **Pure** : uniquement des identifiants (slot → option), aucune ressource
## visuelle. Le générateur d'apparences et le catalogue arrivent en M3 ; M2 n'a
## besoin que de la structure, des copies et de la comparaison (portraits).
class_name PassengerAppearance
extends RefCounted

const SLOT_HEADWEAR: StringName = &"headwear"
## Options de coiffe qui masquent le visage (visière baissée, D-021) :
## le visage devient INCOMPARABLE tant qu'elle n'est pas retirée.
const COVERING_HEADWEAR: Array[StringName] = [&"visor_down"]

## slot → option id (ex. `&"eyes": &"eyes_03"`).
var traits: Dictionary[StringName, StringName] = {}
var palette_id: StringName = &""
## Taille quantifiée, −2..+2.
var height_step: int = 0
## Tranche d'âge apparent (±1 toléré à la comparaison).
var age_band: int = 0


func _init(p_traits: Dictionary[StringName, StringName] = {}, p_age_band: int = 0) -> void:
	traits = p_traits.duplicate()
	age_band = p_age_band


func get_trait(slot: StringName) -> StringName:
	return traits.get(slot, &"")


## Vrai si la coiffe actuelle masque le visage (visière baissée).
func is_face_covered() -> bool:
	return COVERING_HEADWEAR.has(get_trait(SLOT_HEADWEAR))


## Nombre de slots différents parmi `slots` (tous les slots connus si vide).
func distance(other: PassengerAppearance, slots: Array[StringName] = []) -> int:
	var keys: Array[StringName] = slots
	if keys.is_empty():
		keys = _union_slots(other)
	var count: int = 0
	for slot: StringName in keys:
		if get_trait(slot) != other.get_trait(slot):
			count += 1
	return count


## Copie modifiée (sosies, parents, vieillissement, retrait de visière).
func derive(overrides: Dictionary[StringName, StringName]) -> PassengerAppearance:
	var result: PassengerAppearance = copy()
	for slot: StringName in overrides:
		result.traits[slot] = overrides[slot]
	return result


func copy() -> PassengerAppearance:
	var result: PassengerAppearance = PassengerAppearance.new(traits, age_band)
	result.palette_id = palette_id
	result.height_step = height_step
	return result


func equals(other: PassengerAppearance) -> bool:
	return other != null and serialize() == other.serialize()


## Représentation stable (clés triées) pour les tests et les golden files.
func serialize() -> Dictionary:
	var sorted_traits: Dictionary = {}
	var keys: Array[StringName] = []
	keys.assign(traits.keys())
	keys.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for slot: StringName in keys:
		sorted_traits[String(slot)] = String(traits[slot])
	return {
		"traits": sorted_traits,
		"palette_id": String(palette_id),
		"height_step": height_step,
		"age_band": age_band,
	}


func _union_slots(other: PassengerAppearance) -> Array[StringName]:
	var keys: Array[StringName] = []
	keys.assign(traits.keys())
	for slot: StringName in other.traits:
		if not keys.has(slot):
			keys.append(slot)
	return keys
