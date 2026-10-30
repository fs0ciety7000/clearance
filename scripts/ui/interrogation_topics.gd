## Sujets d'interrogatoire proposés par l'UI (GDD §4.3, UI_FLOW §3.1 point 5).
##
## L'UI émet `interrogation_requested(topic)` ; `InspectionSession` (M5)
## répond par `interrogation_answered(topic, line_key)`. Convention des
## identifiants (contrat UI ↔ logique, précisé dans UI_FLOW §3.6) :
## - questions de base : `purpose`, `stay`, `origin` ;
## - `remove_visor` tant que le visage présenté est masqué (D-021) ;
## - une question débloquée par discordance confirmée :
##   `about_<raison>` (`about_expired`, `about_face_mismatch`, `about_mismatch`,
##   `about_rule_violated`), suffixée du document concerné quand il y en a un
##   (`about_expired:entry_permit`).
## Texte de la question : clé `q_<sujet sans suffixe>` (traduction FR).
## Acte II (ARCHITECTURE §7.2) : les discordances des règles de contexte et
## des registres débloquent un sujet **par famille**, sans document :
## `about_quota` (compteur ↔ R23), `about_curfew` (R29), `about_revoked`
## (onglet Révocations, R30), `about_contract` (code employeur, R25) — lus
## par `InspectionSession.find_confirmed`.
## M13 (lot C, ARCHITECTURE §12.5) : sujets de base `cargo` (« Quelque chose à
## déclarer ? », J8+) et `search` (demande de fouille, menu « Portique » : ne
## compte pas comme question) ; confrontations par famille M13 :
## `about_statement[:<doc>]` (déclaration contradictoire), `about_contraband`,
## `about_weapon`, `about_concealed_implant` (implant trouvé au portique).
class_name InterrogationTopics
extends RefCounted

const PURPOSE: StringName = &"purpose"
const STAY: StringName = &"stay"
const ORIGIN: StringName = &"origin"
const REMOVE_VISOR: StringName = &"remove_visor"
## M7 : « Qu'est-ce que c'est que ça ? » (une enveloppe a été glissée).
const ABOUT_ENVELOPE: StringName = &"about_envelope"
## M7 : réponse à la phrase de passe des Lucioles (code 4, `lucioles_trust ≥ 2`).
const LUCIOLE_REPLY: StringName = &"luciole_reply"
const BASE: Array[StringName] = [PURPOSE, STAY, ORIGIN]
## M13 : « Avez-vous quelque chose à déclarer ? » et demande de fouille.
const CARGO: StringName = &"cargo"
const SEARCH: StringName = &"search"
const ABOUT_STATEMENT: StringName = &"about_statement"
const ABOUT_CONTRABAND: StringName = &"about_contraband"
const ABOUT_WEAPON: StringName = &"about_weapon"
const ABOUT_CONCEALED_IMPLANT: StringName = &"about_concealed_implant"
const ABOUT_PREFIX: String = "about_"
const DOC_SEPARATOR: String = ":"
## Acte II : sujets par famille.
const ABOUT_QUOTA: StringName = &"about_quota"
const ABOUT_CURFEW: StringName = &"about_curfew"
const ABOUT_REVOKED: StringName = &"about_revoked"
const ABOUT_CONTRACT: StringName = &"about_contract"
## Acte III (ARCHITECTURE §7.3) : répondant (R34), convocation (R36), lock-out
## (R35).
const ABOUT_SPONSOR: StringName = &"about_sponsor"
const ABOUT_SUMMONS: StringName = &"about_summons"
const ABOUT_LOCKOUT: StringName = &"about_lockout"
## Règle citée → sujet de sa famille (identifiants des `.tres` de `data/rules/`).
const RULE_TOPICS: Dictionary[StringName, StringName] = {
	&"r_air_quota": ABOUT_QUOTA,
	&"r_curfew": ABOUT_CURFEW,
	&"r_revoked_ids": ABOUT_REVOKED,
	&"r_contract_consistent": ABOUT_CONTRACT,
	&"r_sponsor": ABOUT_SPONSOR,
	&"r_summons": ABOUT_SUMMONS,
	&"r_tycho_lockout": ABOUT_LOCKOUT,
	# M13 : déclarations (R43), objets interdits (R45), armes (R46).
	&"r_statements": ABOUT_STATEMENT,
	&"r_contraband": ABOUT_CONTRABAND,
	&"r_weapons_detain": ABOUT_WEAPON,
}


## Sujet débloqué par une discordance confirmée (vide sinon).
static func topic_for(result: Discrepancy) -> StringName:
	if result == null or not result.confirmed:
		return &""
	# Marque ↔ bulletin des symboles (§4.9) : un signalement, pas une question.
	if result.reason_key == Discrepancy.REASON_SYMBOL_MATCH:
		return &""
	var reason: String = result.reason_key.trim_prefix("disc_")
	if reason == "revoked_match":
		return ABOUT_REVOKED
	# M13 : familles de la session (`InspectionSession.find_confirmed`).
	var scan: bool = (result.a != null and result.a.is_scan()) or (result.b != null and result.b.is_scan())
	match reason:
		"contraband":
			return ABOUT_CONTRABAND
		"weapon":
			return ABOUT_WEAPON
		"implant_mismatch":
			if scan:
				return ABOUT_CONCEALED_IMPLANT
		"statement_mismatch":
			for ref: FieldRef in [result.a, result.b]:
				if ref != null and ref.is_document_field():
					return StringName(String(ABOUT_STATEMENT) + DOC_SEPARATOR + String(ref.document_id))
			return ABOUT_STATEMENT
	if reason == "rule_violated":
		for ref: FieldRef in [result.a, result.b]:
			if ref != null and ref.is_rule() and RULE_TOPICS.has(ref.field_id):
				return RULE_TOPICS[ref.field_id]
	var doc: StringName = &""
	for ref: FieldRef in [result.a, result.b]:
		if ref != null and ref.is_document_field():
			doc = ref.document_id
			break
	if doc == &"" or reason == "face_mismatch":
		return StringName(ABOUT_PREFIX + reason)
	return StringName(ABOUT_PREFIX + reason + DOC_SEPARATOR + String(doc))


## Clé du texte de la question (`q_about_expired`).
static func question_key(topic: StringName) -> String:
	return "q_" + String(topic).get_slice(DOC_SEPARATOR, 0)


static func is_unlocked_topic(topic: StringName) -> bool:
	return String(topic).begins_with(ABOUT_PREFIX)


## Document mentionné par le sujet (`entry_permit`), vide sinon.
static func document_of(topic: StringName) -> StringName:
	var text: String = String(topic)
	return StringName(text.get_slice(DOC_SEPARATOR, 1)) if text.contains(DOC_SEPARATOR) else &""


## Texte affiché de la question (« Votre permis d'entrée a expiré… »).
static func question_text(topic: StringName, case: Case) -> String:
	var key: String = question_key(topic)
	var doc_id: StringName = document_of(topic)
	var doc_name: String = ""
	if doc_id != &"" and case != null:
		var doc: DocumentInstance = case.get_document(doc_id)
		if doc != null:
			doc_name = UiText.document_title(doc.type_def).to_lower()
	var fallback: String = String(topic)
	var text: String = UiText.t(key, fallback)
	return text.replace("{doc}", doc_name) if not doc_name.is_empty() else text.replace(" {doc}", "").replace("{doc}", "")
