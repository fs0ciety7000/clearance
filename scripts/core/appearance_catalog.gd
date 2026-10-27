## Catalogue des apparences (ARCHITECTURE §5.2, §9.3 ; BOOTH_SCENE §12) :
## `res://data/appearance/appearance_catalog.tres`, une seule instance.
##
## M3 : catalogue **placeholder** (identifiants seulement, aucune référence
## visuelle), produit par `tools/build_data.gd`. Définition en lecture seule.
class_name AppearanceCatalog
extends Resource

@export var slots: Array[AppearanceSlotDef] = []
## Anti-répétition : nombre minimal de slots différents entre deux passagers
## d'une même fenêtre (D-012, §9.3).
@export var min_distance: int = 5
## Taille de la fenêtre glissante (passagers précédents comparés).
@export var window_size: int = 15
## Essais avant repli sur le candidat le plus éloigné.
@export var max_attempts: int = 12
## Poids des tranches d'âge apparent 0 jeune (18–29), 1 adulte (30–54), 2 âgé (55+).
@export var age_band_weights: PackedFloat32Array = PackedFloat32Array([0.35, 0.45, 0.20])
## Bornes de `PassengerAppearance.height_step`.
@export var height_step_range: Vector2i = Vector2i(-2, 2)


func get_slot(slot_id: StringName) -> AppearanceSlotDef:
	for slot: AppearanceSlotDef in slots:
		if slot != null and slot.id == slot_id:
			return slot
	return null


## Identifiants des slots, dans l'ordre du catalogue (distance anti-répétition).
func get_slot_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for slot: AppearanceSlotDef in slots:
		if slot != null:
			ids.append(slot.id)
	return ids


## Slots comparés par `FaceComparator` (`identity && visible_in_portrait`).
func get_identity_slots() -> Array[StringName]:
	var ids: Array[StringName] = []
	for slot: AppearanceSlotDef in slots:
		if slot != null and slot.is_compared():
			ids.append(slot.id)
	return ids


func has_option(slot_id: StringName, option_id: StringName) -> bool:
	var slot: AppearanceSlotDef = get_slot(slot_id)
	return slot != null and slot.has_option(option_id)
