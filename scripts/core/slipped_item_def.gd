## Définition d'un objet glissé d'un cas scénarisé (M7, données) — produit un
## `SlippedItem` à la construction du cas. Voir `SlippedItem` pour les effets.
class_name SlippedItemDef
extends Resource

@export var kind: SlippedItem.Kind = SlippedItem.Kind.ENVELOPE
@export var amount: int = 0
@export var label_key: String = ""
@export var text_key: String = ""
## Acte III : variantes du texte principal (première vraie, sinon `text_key`)
## — SC-56 : dessin de Noa « toutes les vitres éteintes » au climat Vitres.
@export var text_variants: Array[ConditionalKey] = []
## Lignes additionnelles conditionnelles (drapeaux vrais au début du jour).
@export var extra_text_keys: Array[ConditionalKey] = []
@export var allowed: Array[SlippedItem.Decision] = [SlippedItem.Decision.KEEP, SlippedItem.Decision.RETURN]
@export var default_decision: SlippedItem.Decision = SlippedItem.Decision.RETURN
@export var report_bonus: int = 0
## Clés `"<verdict>_<décision>"` ou `"<décision>"` → `{drapeau: delta}`.
@export var effects: Dictionary[StringName, Dictionary] = {}


## Instance pour un cas (les effets sont copiés : la définition est partagée).
func instantiate(case_id: StringName, n: int, flags: Dictionary[StringName, Variant]) -> SlippedItem:
	var item: SlippedItem = SlippedItem.new()
	item.id = StringName("%s_item%d" % [case_id, n])
	item.case_id = case_id
	item.kind = kind
	item.amount = amount
	item.label_key = label_key
	item.text_key = ConditionalKey.first_match(text_variants, flags, text_key)
	item.extra_text_keys = ConditionalKey.all_matches(extra_text_keys, flags)
	item.allowed = allowed.duplicate()
	item.default_decision = default_decision
	item.report_bonus = report_bonus
	for key: StringName in effects:
		item.effects[key] = effects[key].duplicate(true)
	return item
