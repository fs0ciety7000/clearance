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
## Acte II — répliques conditionnelles résolues à la construction (B25) :
## suffixe (`arrival`, `confront`, `stay`…) → clé (`sc36_lindgren_arrival_refused`),
## prioritaires sur `<dialogue_id>_<suffixe>`. Lues par `scripted_key()`.
var line_overrides: Dictionary[String, String] = {}

# --- M13 « Gameplay » (ARCHITECTURE §12) -------------------------------------
## Déclarations orales (D-139, `Statement`), générées avec le cas (lot B),
## vides avant que R43 ne s'applique et pour un cas scénarisé sans
## `statements` (réponses en prose, aucune puce). `Statement.given` est posé
## par la session quand la réponse est émise.
var statements: Array[Statement] = []
## Cadre de réponse par question (`purpose`, `stay`, `origin` →
## `line_stmt_frame_*`) ; une question sans cadre garde la réplique générique.
## Un passager scénarisé garde sa réplique `<dialogue_id>_<sujet>` (prose) et
## ses puces s'affichent à part (§12.2).
var statement_frames: Dictionary[StringName, String] = {}
## Contenu de la fouille (J8+, null avant) : caché jusqu'au scan (D-140).
var search_layout: SearchLayout = null
## Indices visibles (IV-1 → IV-5 : `SearchLayout.CUE_*`), doublés d'une
## didascalie ; jamais une preuve, seulement un motif de fouille (MF-2).
var search_cues: Array[StringName] = []
## Réponse à « Avez-vous quelque chose à déclarer ? » (`CARGO_*`, J8+) et sa
## réplique (`line_cargo_<type>_<n>`) ; `evasive` = motif MF-3 si la
## question a été posée avant la demande de fouille.
var cargo_reply: StringName = &""
var cargo_line_key: String = ""

const CARGO_NONE: StringName = &"none"
const CARGO_GOODS: StringName = &"goods"
const CARGO_EVASIVE: StringName = &"evasive"


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


## Acte II — document du porteur (jamais un document d'un tiers, SC-27).
func get_own_document(document_id: StringName) -> DocumentInstance:
	for doc: DocumentInstance in documents:
		if doc.get_document_id() == document_id and not doc.is_foreign():
			return doc
	return null


func has_own_document(document_id: StringName) -> bool:
	return get_own_document(document_id) != null


## Clé de réplique d'un passager scénarisé pour un suffixe : variante
## conditionnelle (`line_overrides`), sinon `<dialogue_id>_<suffixe>` si
## `exists` la connaît (callable `func(key: String) -> bool`, ex. `UiText.has`),
## sinon `fallback`.
func scripted_key(suffix: String, fallback: String, exists: Callable) -> String:
	if line_overrides.has(suffix):
		return line_overrides[suffix]
	for tag: StringName in dialogue_tags:
		var key: String = "%s_%s" % [tag, suffix]
		if exists.call(key):
			return key
	return fallback


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


## Toutes les références de champs portant ce `truth_path`, dans l'ordre des
## documents (Acte II : jamais ceux d'un document d'un tiers, SC-27, sauf
## `include_third_party`).
func find_refs_by_truth_path(path: StringName, include_third_party: bool = false) -> Array[FieldRef]:
	var refs: Array[FieldRef] = []
	for doc: DocumentInstance in documents:
		if doc.is_foreign() and not include_third_party:
			continue
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


# --- M13 ----------------------------------------------------------------------

## Déclaration `statement_id` du cas (null si absente).
func get_statement(statement_id: StringName) -> Statement:
	for statement: Statement in statements:
		if statement.id == statement_id:
			return statement
	return null


## Déclaration désignée par une puce `FieldRef.statement` (null sinon).
func get_statement_by_ref(ref: FieldRef) -> Statement:
	if ref == null or not ref.is_statement():
		return null
	return get_statement(ref.get_statement_id())


## Vrai si la puce a été obtenue dans la session (réponse émise) : seule une
## puce obtenue est résoluble au comparateur (lot B, `_is_resolvable`).
func is_statement_given(statement_id: StringName) -> bool:
	var statement: Statement = get_statement(statement_id)
	return statement != null and statement.given


## Déclarations émises par une question (`purpose`, `stay`, `origin`), dans
## l'ordre de `Statement.IDS_BY_QUESTION`.
func statements_for_question(question: StringName) -> Array[Statement]:
	var result: Array[Statement] = []
	for statement_id: StringName in Statement.ids_for_question(question):
		var statement: Statement = get_statement(statement_id)
		if statement != null:
			result.append(statement)
	return result


## Objet de fouille désigné par une référence `FieldRef.scan` (null sinon,
## ou si le cas n'a pas de fouille).
func get_scan_item(ref: FieldRef) -> SearchItem:
	return search_layout.get_item_by_ref(ref) if search_layout != null else null


## Objet de fouille révélé (zone scannée) : seul un objet révélé est résoluble.
func is_scan_item_revealed(ref: FieldRef) -> bool:
	var item: SearchItem = get_scan_item(ref)
	return item != null and item.revealed


## Implants déclarés par la carte d'identité (champ `implants` du porteur,
## valeur affichée : liste ou texte « A, B »), vides sans carte.
func declared_implants() -> PackedStringArray:
	var result: PackedStringArray = []
	for ref: FieldRef in find_refs_by_truth_path(&"implants"):
		var raw: Variant = get_value(ref)
		if raw is PackedStringArray:
			var list: PackedStringArray = raw
			result.append_array(list)
		elif raw is Array:
			var array: Array = raw
			for code: Variant in array:
				result.append(str(code))
		elif raw != null:
			for code: String in str(raw).split(",", false):
				if not code.strip_edges().is_empty():
					result.append(code.strip_edges())
		break
	return result


## La fouille a montré un objet interdit ou un implant non déclaré (AG-03,
## réplique de fin de fouille). Faux sans fouille.
func search_found_forbidden() -> bool:
	return search_layout != null and search_layout.revealed_forbidden(declared_implants())
