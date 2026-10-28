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
## Objets glissés avec les papiers (M7 : enveloppe, mot, carte de quai).
var slipped_items: Array[SlippedItem] = []
## Codes Lucioles portés (LORE §7, 1–7) : jamais des discordances. 1 = marque
## sur un document (`DocumentInstance.marks`), 2 = MRZ `07`, 3 = permis en 7,
## 4 = phrase de passe (étiquette `luciole_password`), 5 = trois tapes
## (`presentation`), 6 = fil magenta, 7 = *lumika* dans un bark.
var luciole_codes: PackedInt32Array = []
## Mise en scène de l'arrivée (`&"knock_three"` : code 5), vide sinon.
var presentation: StringName = &""


func get_item(item_id: StringName) -> SlippedItem:
	for item: SlippedItem in slipped_items:
		if item.id == item_id:
			return item
	return null


func has_envelope() -> bool:
	for item: SlippedItem in slipped_items:
		if item.kind == SlippedItem.Kind.ENVELOPE:
			return true
	return false


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


## Geste « Retirez votre visière » (D-021) : le visage présenté devient
## comparable. Renvoie vrai si une visière couvrante a été retirée.
func remove_visor() -> bool:
	if passenger_presented == null or passenger_presented.appearance == null:
		return false
	if not passenger_presented.appearance.is_face_covered():
		return false
	passenger_presented.appearance = passenger_presented.appearance.without_visor()
	return true


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
