## Corruption injectée dans un cas (ARCHITECTURE §5.3).
##
## Produite par les injecteurs du générateur (M3) et conservée dans `CaseKey`.
## Une anomalie ne décide jamais du verdict : elle *provoque* des violations,
## et le verdict attendu est recalculé par le `RuleEngine` (§6, D-005).
class_name Anomaly
extends RefCounted

var type: AnomalyType.Kind = AnomalyType.Kind.EXPIRED_DOCUMENT
## Document ciblé (`DocumentTypeDef.id`), vide si l'anomalie touche le dossier.
var document_id: StringName = &""
## Champ ciblé (`FieldDef.id`), vide si l'anomalie touche le document entier.
var field_id: StringName = &""
var original_value: Variant = null
var injected_value: Variant = null
## Leurre volontaire, non détecté par les règles (bruit légitime, §6).
var cosmetic: bool = false


func _init(p_type: AnomalyType.Kind = AnomalyType.Kind.EXPIRED_DOCUMENT,
		p_document_id: StringName = &"", p_field_id: StringName = &"") -> void:
	type = p_type
	document_id = p_document_id
	field_id = p_field_id


func _to_string() -> String:
	return "Anomaly(%s, %s.%s)" % [AnomalyType.name_of(type), document_id, field_id]
