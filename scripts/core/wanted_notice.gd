## Avis de recherche résolu d'un jour (M7) : nom et portrait de la personne
## recherchée, publié par `EventBus.wanted_notices_published` et lu par la
## règle R22 (`WantedRule`) via `RuleContext.wanted`.
## Pseudo-référence sélectionnable en mode Inspection : `FieldRef.wanted(id)`.
class_name WantedNotice
extends RefCounted

var id: StringName = &""
var given_name: String = ""
var family_name: String = ""
## Photo de l'avis (apparence officielle, sans coiffe).
var appearance: PassengerAppearance = null
var reason_key: String = ""
## Index du passager concerné dans la file du jour (diagnostic, tests).
var case_index: int = -1


func full_name() -> String:
	return "%s %s" % [given_name, family_name]


func get_ref() -> FieldRef:
	return FieldRef.wanted(id)
