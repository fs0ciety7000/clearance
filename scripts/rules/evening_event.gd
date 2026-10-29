## Événement du soir résolu pour un jour (M7) — produit par
## `EveningService.build_events()`, vu par l'UI (écran Soirée).
##
## Textes résolus selon les drapeaux (`text_key`, `extra_keys`), options
## disponibles (condition vraie ; la disponibilité financière est vérifiée au
## choix : `EveningService.can_choose`). Un audit porte son résultat (`audit`).
class_name EveningEvent
extends RefCounted

var def: EveningEventDef = null
var id: StringName = &""
var kind: EveningEventDef.Kind = EveningEventDef.Kind.LETTER
var title_key: String = ""
var text_key: String = ""
var extra_keys: PackedStringArray = []
var options: Array[EveningOptionDef] = []
## Option choisie par défaut sans UI (vide pour une lettre ou un audit).
var default_option: StringName = &""
## Audit (J9) : `EndingService.audit_outcome()` ; Revue (J17) : `review_outcome()`.
var audit: Dictionary = {}
## Acte II : valeurs du gabarit de `text_key` (`%d`), ex. pages du registre.
var text_args: Array = []


func get_option(option_id: StringName) -> EveningOptionDef:
	for option: EveningOptionDef in options:
		if option.id == option_id:
			return option
	return null


## Option disponible qui porte la même intention que `option_id` (QA-036) :
## l'option elle-même si elle est offerte, sinon une variante conditionnelle
## au même libellé (`loyal` → `loyal_paid` quand `montclair_pliable`,
## `pay` → `pay_denounced`, `keep` → `keep_broke`) ; `null` sinon.
func option_for_intent(option_id: StringName) -> EveningOptionDef:
	if option_id == &"":
		return null
	var exact: EveningOptionDef = get_option(option_id)
	if exact != null or def == null:
		return exact
	var wanted: EveningOptionDef = def.get_option(option_id)
	if wanted == null or wanted.label_key == "":
		return null
	for option: EveningOptionDef in options:
		if option.label_key == wanted.label_key:
			return option
	return null


func is_choice() -> bool:
	return kind == EveningEventDef.Kind.CHOICE and not options.is_empty()
