## Profil de joueur simulé (M7, équilibrage et tests de campagne) : précision
## des verdicts, usage de la DÉTENTION, pots-de-vin, choix scénarisés et choix
## du soir. Utilisé par `DaySimulator` / `BalanceSimulator` et
## `tools/balance_sim.gd`. Les préréglages (`preset`) servent à mesurer la
## répartition des fins et à prouver que chacune est atteignable.
class_name SimProfile
extends RefCounted

## Préréglages : `default` (choix par défaut sans UI, enveloppes rendues),
## `loyal` (Consortium), `luciole` (aide les Lucioles), `mercenary` (garde
## les enveloppes), `drift` (achète les laissez-passer, ne livre pas Mira),
## `negligent` (ne paie que le loyer : foyer perdu).
## `evicted` (ne paie rien : réaffectation).
const PRESETS: Array[StringName] = [&"default", &"loyal", &"luciole", &"mercenary", &"drift", &"negligent", &"evicted"]

const VK := VerdictKind.Kind
const SD := SlippedItem.Decision

var name: StringName = &"default"
## Probabilité d'un verdict juste (sinon : erreur grossière).
var accuracy: float = 0.8
## Tamponne DÉTENTION quand elle est attendue (sinon REFUS, juste sans prime).
var detain: bool = true
## Probabilité de garder une enveloppe générée.
var keep_bribes: float = 0.0
## Verdicts imposés par étiquette de dialogue de cas scénarisé (`sc22_mira`…).
var verdicts: Dictionary[StringName, VerdictKind.Kind] = {}
## Décisions imposées sur les objets glissés par étiquette (sinon : défaut).
var items: Dictionary[StringName, SlippedItem.Decision] = {}
## Choix du soir imposés `{event_id: option_id}` (sinon : choix par défaut).
var choices: Dictionary[StringName, StringName] = {}
## Répond à la phrase de passe quand c'est possible.
var answer_password: bool = false
## Signale le mot des Lucioles du J3 (sinon il est brûlé).
var report_note: bool = false
## Postes du soir : `reasoned` (politique raisonnable), `rent_only`, `none`.
var spending: StringName = &"reasoned"


static func preset(preset_name: StringName, p_accuracy: float = 0.95) -> SimProfile:
	var p: SimProfile = SimProfile.new()
	p.name = preset_name
	p.accuracy = p_accuracy
	match preset_name:
		&"loyal":
			p.report_note = true
			p.items = {&"sc18_sefa": SD.REPORT}
			p.choices = {&"d08_neighbor": &"denounce", &"d09_okonkwo": &"sign", &"d09_ilan": &"forbid",
					&"d07_school": &"pay"}
		&"luciole":
			p.answer_password = true
			p.verdicts = {&"sc05_luciole_messenger": VK.APPROVE, &"sc08_dmitri": VK.APPROVE, &"sc09_noor": VK.APPROVE,
					&"sc13_lev": VK.APPROVE, &"sc14_kaito": VK.APPROVE, &"sc16_hana": VK.APPROVE, &"sc22_mira": VK.APPROVE,
					&"sc20_arkady": VK.DETAIN, &"sc17_fatou": VK.DENY}
			p.items = {&"sc18_sefa": SD.KEEP}
			p.choices = {&"d05_heat": &"accept", &"d08_neighbor": &"help", &"d09_ilan": &"support",
					&"d09_okonkwo": &"warn"}
		&"mercenary":
			p.keep_bribes = 1.0
			p.items = {&"sc07_valcourt": SD.KEEP, &"sc12_ravel": SD.KEEP, &"sc14_kaito": SD.KEEP, &"sc21_philippa": SD.KEEP}
			p.choices = {&"d08_package": &"accept"}
		&"drift":
			p.verdicts = {&"sc22_mira": VK.DENY}
			p.choices = {&"d09_drift": &"buy"}
		&"negligent":
			p.spending = &"rent_only"
		&"evicted":
			p.spending = &"none"
	return p


## Verdict pour un cas : `chance` (tirage déjà fait) décide juste / faux ;
## un verdict imposé par étiquette l'emporte.
func verdict_for(case: Case, key: CaseKey, correct: bool, detain_enabled: bool) -> VerdictKind.Kind:
	for tag: StringName in case.dialogue_tags:
		if verdicts.has(tag):
			var forced: VerdictKind.Kind = verdicts[tag]
			return VerdictKind.Kind.DENY if forced == VerdictKind.Kind.DETAIN and not detain_enabled else forced
	if correct:
		if key.expected_verdict == VerdictKind.Kind.DETAIN and (not detain or not detain_enabled):
			return VerdictKind.Kind.DENY
		return key.expected_verdict
	return VerdictKind.Kind.DENY if key.expected_verdict == VerdictKind.Kind.APPROVE else VerdictKind.Kind.APPROVE


## Décision sur un objet glissé (`roll` ∈ [0, 1] pour les enveloppes générées).
func decision_for(case: Case, item: SlippedItem, roll: float) -> SlippedItem.Decision:
	for tag: StringName in case.dialogue_tags:
		if items.has(tag) and item.is_allowed(items[tag]):
			return items[tag]
	if item.kind == SlippedItem.Kind.ENVELOPE and roll < keep_bribes and item.is_allowed(SlippedItem.Decision.KEEP):
		return SlippedItem.Decision.KEEP
	return item.default_decision
