## Entrée résolue de l'onglet « Convocations » de l'Enquête (Acte III, R36 ;
## docs/ACT3.md §2.4) : N° `ENQ-NNNN` et nom du convoqué. Publiée par
## `EventBus.summons_published`, lue par `SummonsRule` via
## `RuleContext.summons`. Pseudo-référence : `FieldRef.summons(id)`.
class_name SummonsEntry
extends RefCounted

var id: StringName = &""
var number: String = ""
var given_name: String = ""
var family_name: String = ""
## Motif affiché (« Témoin — Incident du quai 3, 2179 »), facultatif.
var reason_key: String = ""
## Index du passager convoqué dans la file du jour (−1 : convocation sans passager).
var case_index: int = -1


func full_name() -> String:
	return "%s %s" % [given_name, family_name]


func get_ref() -> FieldRef:
	return FieldRef.summons(id)
