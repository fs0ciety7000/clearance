## Famille « Déclarations conformes » (R43, M13 ; docs/M13.md §1.4, §1.8 ;
## D-142, D-143) — 27ᵉ famille.
##
## Chaque déclaration orale **non vague** d'un sujet actif (`topics`) est
## comparée au champ de document de même donnée (`Statement.truth_path`) :
## motif et durée ↔ Permis d'entrée ; employeur ↔ Employeur (permis) et Code
## (contrat, via la table de R25) ; origine ↔ Origine (carte) ou Vaisseau
## (laissez-passer d'un Dérivant) ; personne visitée ↔ nom du Répondant.
## Discordance → violation de sévérité 2 (REFUS), preuves
## `FieldRef.statement(id)` + champ(s) du document. La violation existe même
## si la question n'est pas posée (D-005) : la règle lit `Case.statements`,
## jamais `Statement.given`. La provenance, les puces vagues et la valeur
## barrée d'une auto-correction ne sont jamais comparées.
##
## Paliers (`rs_dayNN`, même identifiant `r_statements`, texte du Rulebook
## propre) : s1 J4 `[purpose, stay]`, s2 J12 `+ employer`, s3 J13
## `+ origin`, s4 J24 `+ host`. Un palier > 1 est rangé à part par le
## `DataCatalog` (`rule_tiers`).
class_name StatementsConsistentRule
extends Rule

## Contrat de travail (code employeur `CT-XX`, R25).
const CODE_PATH: StringName = &"employer_code"
const CARD_ID: StringName = &"id_card"
const DRIFT_PASS_ID: StringName = &"drift_pass"

## Sujets contrôlés (`Statement.ID_*`), dans l'ordre.
@export var topics: Array[StringName] = [Statement.ID_PURPOSE, Statement.ID_STAY]
## Palier (1 → 4) : 1 = règle de `data/rules/`, les suivants rangés à part.
@export var tier: int = 1
@export var permit_id: StringName = &"entry_permit"
@export var contract_id: StringName = &"work_contract"
## Employeur (nom canonique du permis) → code (`KA`…), recopié de R25.
@export var employer_codes: Dictionary[String, String] = {}


func evaluate(case: Case, _ctx: RuleContext) -> Array[Violation]:
	var violations: Array[Violation] = []
	if case == null:
		return violations
	for statement: Statement in case.statements:
		if statement == null or not topics.has(statement.id) or not statement.is_comparable():
			continue
		var primary: FieldRef = primary_ref(case, statement)
		if primary == null or compare(case, statement, primary) != Discrepancy.Result.DISCORDANT:
			continue
		var refs: Array[FieldRef] = [statement.get_ref(), primary]
		if statement.id == Statement.ID_EMPLOYER:
			var code_ref: FieldRef = Rule.find_ref(case, contract_id, CODE_PATH)
			if code_ref != null and compare(case, statement, code_ref) == Discrepancy.Result.DISCORDANT:
				refs.append(code_ref)
		refs.append(get_ref())
		violations.append(make_violation(refs, "viol_statement_%s" % statement.id))
	return violations


## Champ **de référence** d'une déclaration (celui que lit le générateur des
## déclarations honnêtes, M13 §1.4) : Permis d'entrée pour le motif, la durée,
## l'employeur et la personne visitée ; Carte d'identité pour l'origine
## (Vaisseau du laissez-passer pour un Dérivant). Null s'il est absent : une
## déclaration sans document de référence n'est pas contrôlée (HAL sans permis).
## Un autre document qui porte la même donnée reste comparable au Mode
## Inspection (`comparable_refs`), mais seule la référence fonde la violation :
## une incohérence **entre documents** (autre anomalie) ne rend jamais un
## passager honnête menteur.
func primary_ref(case: Case, statement: Statement) -> FieldRef:
	if statement == null or statement.truth_path == &"":
		return null
	var document_id: StringName = permit_id
	if statement.id == Statement.ID_ORIGIN:
		document_id = DRIFT_PASS_ID if statement.truth_path == Statement.PATH_VESSEL else CARD_ID
	var doc: DocumentInstance = case.get_own_document(document_id)
	if doc == null or doc.retired:
		return null
	var field: FieldDef = doc.type_def.find_field_by_truth_path(statement.truth_path)
	return FieldRef.new(document_id, field.id) if field != null else null


## Champs de document comparables à une déclaration (documents du porteur
## seulement, jamais ceux d'un tiers) : même `truth_path`, plus le Code du
## contrat pour l'employeur.
func comparable_refs(case: Case, statement: Statement) -> Array[FieldRef]:
	var refs: Array[FieldRef] = []
	if statement == null or statement.truth_path == &"":
		return refs
	for ref: FieldRef in case.find_refs_by_truth_path(statement.truth_path):
		if not case.get_document(ref.document_id).retired:
			refs.append(ref)
	if statement.id == Statement.ID_EMPLOYER and case.get_own_document(contract_id) != null:
		var code_ref: FieldRef = Rule.find_ref(case, contract_id, CODE_PATH)
		if code_ref != null:
			refs.append(code_ref)
	return refs


## Puce ↔ champ de document : CONCORDANT, DISCORDANT ou INCOMPARABLE (vague,
## provenance, champ d'une autre donnée, valeur absente).
func compare(case: Case, statement: Statement, ref: FieldRef) -> Discrepancy.Result:
	if statement == null or ref == null or not statement.is_comparable():
		return Discrepancy.Result.INCOMPARABLE
	var field: FieldDef = case.get_field_def(ref)
	if field == null:
		return Discrepancy.Result.INCOMPARABLE
	var doc: DocumentInstance = case.get_document(ref.document_id)
	if doc == null or doc.is_foreign() or doc.retired:
		return Discrepancy.Result.INCOMPARABLE
	var value: Variant = case.get_value(ref)
	if statement.id == Statement.ID_EMPLOYER and field.truth_path == CODE_PATH:
		var expected: String = code_for(str(statement.value))
		if expected.is_empty() or value == null or str(value).is_empty():
			return Discrepancy.Result.INCOMPARABLE
		return Discrepancy.Result.CONCORDANT if FieldValue.equals(value, expected) else Discrepancy.Result.DISCORDANT
	if field.truth_path != statement.truth_path:
		return Discrepancy.Result.INCOMPARABLE
	match statement.compare_to(value):
		Statement.Match.CONCORDANT:
			return Discrepancy.Result.CONCORDANT
		Statement.Match.DISCORDANT:
			return Discrepancy.Result.DISCORDANT
	return Discrepancy.Result.INCOMPARABLE


## Code employeur attendu pour un employeur (nom canonique), vide si inconnu.
func code_for(employer: String) -> String:
	for name: String in employer_codes:
		if Statement.normalize_text(name) == Statement.normalize_text(employer):
			return employer_codes[name]
	return ""


## Vrai si le sujet est contrôlé par ce palier.
func checks_topic(statement_id: StringName) -> bool:
	return topics.has(statement_id)


func get_detectable_anomalies() -> Array[AnomalyType.Kind]:
	return [AnomalyType.Kind.STATEMENT_MISMATCH]


## Une règle se compare aux documents, jamais à une puce (M13 §1.8) : la
## comparaison passe par puce ↔ champ (`DiscrepancyChecker`).
func check_against(_case: Case, _ref: FieldRef, _ctx: RuleContext) -> Discrepancy.Result:
	return Discrepancy.Result.INCOMPARABLE


func get_referenced_truth_paths() -> Dictionary[StringName, Array]:
	var paths: Dictionary[StringName, Array] = {permit_id: [&"purpose", &"stay_days"]}
	if topics.has(Statement.ID_EMPLOYER):
		paths[permit_id].append(&"employer")
		paths[contract_id] = [CODE_PATH]
	if topics.has(Statement.ID_ORIGIN):
		paths[&"id_card"] = [&"faction_id"]
	return paths


## Palier de R43 actif dans un RuleSet (null si R43 est absente).
static func active_in(rule_set: RuleSet) -> StatementsConsistentRule:
	if rule_set == null:
		return null
	for rule: Rule in rule_set.rules:
		if rule is StatementsConsistentRule:
			return rule
	return null
