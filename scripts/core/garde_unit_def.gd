## Unité de directive de la Garde de nuit (M12 §2.3, D-126 ; ARCHITECTURE
## §11.5) : U01 → U20, une page du Rulebook (une ou deux règles).
## `res://data/garde/` (lot B), référencées par `GardeDef.units`.
class_name GardeUnitDef
extends Resource

## `u01`…`u20`.
@export var id: StringName = &""
## Titre de la carte de directive (`garde_unit_u01` ou titre de règle neutre).
@export var title_key: String = ""
## Règles ajoutées (ressources de `data/rules/`, partagées).
@export var rules: Array[Rule] = []
## Palier de difficulté de l'unité : 1, 2 ou 3.
@export_range(1, 3) var tier: int = 1
## Unités qui doivent être actives avant celle-ci (`u01`…).
@export var prerequisites: Array[StringName] = []
## Documents ajoutés (informatif : générateur et carte de directive).
@export var document_ids: Array[StringName] = []
## Onglets du Rulebook ouverts (`origins`, `implants`, `wanted`, `revoked`…).
@export var rulebook_tabs: PackedStringArray = []
## Ouvre le tampon DÉTENTION (U11).
@export var enables_detain: bool = false
## Listes renouvelées à chaque directive (`wanted`, `revoked`) : le générateur
## les régénère dans `CaseBuilder.on_rules_changed` (D-056 : avant les
## passagers qu'elles visent).
@export var renews_lists: PackedStringArray = []


func rule_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for rule: Rule in rules:
		if rule != null:
			ids.append(rule.id)
	return ids
