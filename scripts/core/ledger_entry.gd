## Entrée de l'onglet « Main courante » (Acte III, R34, M2 « Répondants » ;
## docs/ACT3.md §2.5) : passager **admis aujourd'hui à cette vitre** et
## admissible comme répondant (Né·e-Halcyon de classe C-1 à C-3, lus sur sa
## carte). La liste enregistre les approbations, pas leur justesse (D-087) :
## un répondant approuvé à tort y figure. Tenue par le `CaseBuilder`
## (`RuleContext.ledger`), publiée par `EventBus.ledger_changed`.
## Pseudo-référence sélectionnable : `FieldRef.ledger(id)`.
class_name LedgerEntry
extends RefCounted

var id: StringName = &""
var citizen_id: String = ""
var given_name: String = ""
var family_name: String = ""
var citizen_class: StringName = &""
var faction_id: StringName = &""
## Index du passager dans la file du jour.
var case_index: int = -1


func full_name() -> String:
	return "%s %s" % [given_name, family_name]


func get_ref() -> FieldRef:
	return FieldRef.ledger(id)
