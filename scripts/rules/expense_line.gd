## Un poste de dépense de la soirée (GDD §5.3) — produit par `EveningService`.
class_name ExpenseLine
extends RefCounted

## `rent`, `air_tax`, `food`, `heating`, `oxygen`, `meds_<proche>`.
var id: StringName = &""
## Clé du libellé (`ev_line_<id>` ; `ev_line_meds` + nom du proche).
var label_key: String = ""
## Clé de la note sous le libellé (conséquence si impayé…), vide sinon.
var note_key: String = ""
var cost: int = 0
## Prélevé d'office (taxe d'air) : toujours payé, jamais décochable.
var mandatory: bool = false
## Proche concerné (médicaments), vide sinon.
var member_id: StringName = &""
## Acte II : proche dont c'est la ration d'air (`ration_<proche>`), vide sinon.
## Ration non payée → ESSOUFFLÉ·E (M2).
var ration_of: StringName = &""
var paid: bool = false
## M13 (D-150) : achat de l'Économat (`UpgradeDef.id`, `ag01`…), vide sinon.
## Jamais présélectionné ; un seul par soir (`EveningService.can_toggle_on`).
var upgrade_id: StringName = &""


func _init(p_id: StringName = &"", p_cost: int = 0, p_mandatory: bool = false) -> void:
	id = p_id
	cost = p_cost
	mandatory = p_mandatory
	paid = p_mandatory
	label_key = "ev_line_%s" % p_id
	note_key = "ev_note_%s" % p_id
