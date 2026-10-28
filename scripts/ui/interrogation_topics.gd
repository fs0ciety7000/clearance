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
const ABOUT_PREFIX: String = "about_"
const DOC_SEPARATOR: String = ":"


## Sujet débloqué par une discordance confirmée (vide sinon).
static func topic_for(result: Discrepancy) -> StringName:
	if result == null or not result.confirmed:
		return &""
	# Marque ↔ bulletin des symboles (§4.9) : un signalement, pas une question.
	if result.reason_key == Discrepancy.REASON_SYMBOL_MATCH:
		return &""
	var reason: String = result.reason_key.trim_prefix("disc_")
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
