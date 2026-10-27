## Ce que voit le joueur pour un passager (ARCHITECTURE §5.3).
##
## Transporté par `EventBus.case_presented`. Ne contient **jamais** la réponse
## attendue : elle est dans `CaseKey`, détenue par DayController/ScoringService.
## Hypothèse M2 : au plus un document par type dans un cas
## (`FieldRef.document_id` = `DocumentTypeDef.id`).
class_name Case
extends RefCounted

var case_id: StringName = &""
## Index 0-based dans la file du jour.
var index: int = 0
## Graine du cas (`SeededRng.case_seed`) ; `seed` masquerait la fonction globale.
var case_seed: int = 0
var passenger_presented: Passenger = null
var documents: Array[DocumentInstance] = []
var dialogue_tags: Array[StringName] = []


func get_document(document_id: StringName) -> DocumentInstance:
	for doc: DocumentInstance in documents:
		if doc.get_document_id() == document_id:
			return doc
	return null


func has_document(document_id: StringName) -> bool:
	return get_document(document_id) != null


func get_document_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for doc: DocumentInstance in documents:
		ids.append(doc.get_document_id())
	return ids


## Définition du champ désigné par `ref` (null pour les pseudo-documents).
func get_field_def(ref: FieldRef) -> FieldDef:
	if ref == null or not ref.is_document_field():
		return null
	var doc: DocumentInstance = get_document(ref.document_id)
	return doc.get_field(ref.field_id) if doc != null else null


## Vrai si `ref` désigne un champ d'un document présent dans le cas.
func has_field(ref: FieldRef) -> bool:
	return get_field_def(ref) != null


## Valeur affichée du champ désigné (null si absent).
func get_value(ref: FieldRef) -> Variant:
	if not has_field(ref):
		return null
	return get_document(ref.document_id).get_value(ref.field_id)


## Toutes les références de champs portant ce `truth_path`, dans l'ordre des documents.
func find_refs_by_truth_path(path: StringName) -> Array[FieldRef]:
	var refs: Array[FieldRef] = []
	for doc: DocumentInstance in documents:
		for field: FieldDef in doc.type_def.fields:
			if field.truth_path == path:
				refs.append(FieldRef.new(doc.get_document_id(), field.id))
	return refs


## Toutes les références de champs d'un type donné (ex. tous les portraits).
func find_refs_by_kind(kind: FieldDef.FieldKind) -> Array[FieldRef]:
	var refs: Array[FieldRef] = []
	for doc: DocumentInstance in documents:
		for field: FieldDef in doc.type_def.fields:
			if field.kind == kind:
				refs.append(FieldRef.new(doc.get_document_id(), field.id))
	return refs
