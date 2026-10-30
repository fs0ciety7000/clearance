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
## Acte II (docs/ACT2.md §6.4) : `drift10` (embarque au J10), `archiviste`
## (garde pages et formulaires, écrit les noms, recopie le dossier, envoie le
## registre), `solidaire` (pétition, caisse, refus de la liste, épargne Sato,
## Okonkwo, Ravel, vote la grève), `overrun` (approuve au-delà du quota),
## `mercenary2` (enveloppes gardées à partir du J10 : Revue du J17). Les
## préréglages de l'Acte I sont prolongés (choix et verdicts du J10 au J20).
## Acte III (docs/ACT3.md §6.5) : `passeur` (approuve les répondants et le
## réseau, garde la liste de Tycho, rapide au J30 : F10), `temoin` (Dire à
## chaque question, Dora témoigne, garde rapports et registre, Tout dire :
## F8), `accusateur` (Accuser, Dire ce qu'on attend), `mercenary3` (garde les
## enveloppes à partir du J21 : Déposition) ; `luciole`, `loyal`, `drift`,
## `solidaire` prolongés du J20 au J30.
## M11 (D-102) : `story_mode` (mode Récit : amendes à 0 ₵, citations comptées ;
## la file est toujours traitée en entier) — `SimProfile.story(preset)` ou
## préfixe `story_` (`story_luciole`…) dans `preset` / `balance_sim --presets=`.
## M13 (docs/M13.md §4.5) : `presse` (interroge peu, ne fouille jamais),
## `curieux` (interroge toujours, fouille complète sur indice), `zele` (fouille
## tout le monde : coût de FOUILLE SANS MOTIF), `economiste` (achète à
## l'Économat dès que possible).
const PRESETS: Array[StringName] = [&"default", &"loyal", &"luciole", &"mercenary", &"drift", &"negligent", &"evicted",
		&"drift10", &"archiviste", &"solidaire", &"overrun", &"mercenary2", &"passeur", &"temoin", &"accusateur",
		&"mercenary3", &"presse", &"curieux", &"zele", &"economiste"]
## M13 : politiques de fouille et d'achat.
const SEARCH_NEVER: StringName = &"never"
const SEARCH_CUE: StringName = &"cue"
const SEARCH_CUE_DISCORD: StringName = &"cue_discord"
const SEARCH_ALWAYS: StringName = &"always"
const ZONES_TARGETED: StringName = &"targeted"
const ZONES_FULL: StringName = &"full"
const UPGRADES_NEVER: StringName = &"never"
const UPGRADES_SMART: StringName = &"smart"
const UPGRADES_EAGER: StringName = &"eager"
const UPGRADES_LIST: StringName = &"list"

const VK := VerdictKind.Kind
const SD := SlippedItem.Decision

var name: StringName = &"default"
## Probabilité d'un verdict juste (sinon : erreur grossière).
var accuracy: float = 0.8
## Tamponne DÉTENTION quand elle est attendue (sinon REFUS, juste sans prime).
var detain: bool = true
## Probabilité de garder une enveloppe générée.
var keep_bribes: float = 0.0
## Acte II : premier jour où les enveloppes générées sont gardées.
var bribes_from_day: int = 1
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
## Acte II : au-delà du quota, approuve les passagers en règle (entrées
## imputées, 0 ₵) au lieu de les refuser.
var overrun: bool = false
## Acte II : rythme de la file (1 = un passager toutes les 8 h / N ; < 1 : plus
## rapide, la file finit avant 18:00) — heure de présentation simulée.
var pace: float = 1.0
## M11 (D-102) : joueur en mode Récit (amendes à 0 ₵).
var story_mode: bool = false
## M12 (Garde de nuit, docs/M12.md §6.1) : précision « dégressive » — 95 % au
## palier 0, −4 points par palier, −0,5 point par unité active au-delà de 6
## (sinon `accuracy` constante).
var garde_decay: bool = false
## M12 (B58) : campagne avec le calendrier des événements de station
## (`StationEventService.schedule`) appliqué par le `DaySimulator`
## (`balance_sim --events=on|compare`).
var station_events: bool = false

## M13 (docs/M13.md §4.5) : probabilité de poser la question de motif (hors
## Tycho, toujours interrogés : R08) ; 3 s, 2 s avec AG-01.
var ask_rate: float = 0.85
## Probabilité de relever une fausse déclaration **si** la question est
## posée ; < 0 = `accuracy`.
var statement_catch: float = -1.0
## Quand fouiller : `never`, `cue` (indice remarqué), `cue_discord` (indice ou
## discordance), `always` (tout le monde : FOUILLE SANS MOTIF sur les innocents).
var search_policy: StringName = SEARCH_CUE
## Zones : `targeted` (zone de l'indice, puis une autre à 50 %) ou `full` (TOUT SCANNER).
var search_zones: StringName = ZONES_TARGETED
## Probabilité de remarquer un indice visible (IV-1 → IV-5).
var cue_spot: float = 0.8
## Achats du soir : `never`, `smart` (§4.4), `eager`, `list` (`upgrade_list`).
var upgrade_policy: StringName = UPGRADES_SMART
var upgrade_list: Array[StringName] = []
## Améliorations jamais achetées par ce profil (`luciole` : ni le PH-2 qui
## transmet ses relevés, ni le moniteur de Valcourt-Hsu).
var avoid_upgrades: Array[StringName] = []
## Faux : campagne « 0.12 » (règles R43 → R47, anomalies, cas SC-104 → SC-111,
## compensation de temps et avertissements de M13 retirés, aucun achat) —
## `balance_sim --m13=off|compare`.
var m13: bool = true
## Modèle de temps (`balance_sim --m13=compare`, `--timed`) : chaque cas
## coûte `seconds_per_case` (± 20 %) + questions et fouille ; la file s'arrête
## quand la durée du shift est épuisée (Dur seulement : le Récit traite tout).
var timed: bool = false
var seconds_per_case: float = 48.0

const GARDE_DECAY_START: float = 0.95
const GARDE_DECAY_PER_TIER: float = 0.04
const GARDE_DECAY_PER_UNIT: float = 0.005
const GARDE_DECAY_FREE_UNITS: int = 6

## Préfixe d'un préréglage en mode Récit (`story_default`, `story_luciole`…).
const STORY_PREFIX: String = "story_"


static func preset(preset_name: StringName, p_accuracy: float = 0.95) -> SimProfile:
	var text: String = String(preset_name)
	if text.begins_with(STORY_PREFIX):
		var story_profile: SimProfile = preset(StringName(text.trim_prefix(STORY_PREFIX)), p_accuracy)
		story_profile.name = preset_name
		story_profile.story_mode = true
		return story_profile
	var p: SimProfile = SimProfile.new()
	p.name = preset_name
	p.accuracy = p_accuracy
	match preset_name:
		&"loyal":
			p.report_note = true
			p.items = {&"sc18_sefa": SD.REPORT, &"sc45_ravel": SD.REPORT}
			p.verdicts = {&"sc43_mateus": VK.DETAIN, &"sc47_kasimir": VK.DETAIN}
			p.choices = {&"d08_neighbor": &"denounce", &"d09_okonkwo": &"sign", &"d09_ilan": &"forbid",
					&"d07_school": &"pay", &"d12_job": &"accept", &"d12_page": &"report", &"d14_lease": &"take",
					&"d15_fund": &"report", &"d17_list": &"sign", &"d19_registre": &"surrender",
					# Acte III.
					&"d21_amnesty": &"sign", &"d25_tycho_fund": &"report", &"d29_deposition": &"loyal"}
			p.items.merge({&"sc65_yara": SD.REPORT, &"sc79_adeyemi": SD.REPORT})
			p.verdicts.merge({&"sc82_dora": VK.DETAIN, &"sc82_mira": VK.DETAIN})
		&"luciole":
			p.answer_password = true
			p.overrun = true
			p.verdicts = {&"sc05_luciole_messenger": VK.APPROVE, &"sc08_dmitri": VK.APPROVE, &"sc09_noor": VK.APPROVE,
					&"sc13_lev": VK.APPROVE, &"sc14_kaito": VK.APPROVE, &"sc16_hana": VK.APPROVE, &"sc22_mira": VK.APPROVE,
					&"sc20_arkady": VK.DETAIN, &"sc17_fatou": VK.DENY,
					&"sc35_okonkwo_veilleur": VK.APPROVE, &"sc40_valentin": VK.APPROVE, &"sc50_ilan": VK.APPROVE,
					&"sc50_mira": VK.APPROVE, &"sc47_kasimir": VK.DENY,
					# Acte III : la technicienne, le messager, la Commissaire témoin, la figure finale.
					&"sc53_anouk": VK.APPROVE, &"sc66_lev": VK.APPROVE, &"sc59_beaumont": VK.APPROVE,
					&"sc71_kasimir": VK.DENY, &"sc82_dora": VK.APPROVE, &"sc82_mira": VK.APPROVE}
			p.items = {&"sc18_sefa": SD.KEEP, &"sc65_yara": SD.KEEP}
			p.avoid_upgrades = [&"ag03", &"ag06"]
			p.choices = {&"d05_heat": &"accept", &"d08_neighbor": &"help", &"d09_ilan": &"support",
					&"d09_okonkwo": &"warn", &"d12_job": &"refuse", &"d13_scanner": &"install", &"d16_call": &"go",
					&"d16_unplug": &"unplug",
					&"d21_amnesty": &"refuse", &"d23_job": &"tycho", &"d25_tycho_fund": &"give"}
		&"mercenary":
			p.keep_bribes = 1.0
			p.items = {&"sc07_valcourt": SD.KEEP, &"sc12_ravel": SD.KEEP, &"sc14_kaito": SD.KEEP, &"sc21_philippa": SD.KEEP}
			p.choices = {&"d08_package": &"accept"}
		&"mercenary2":
			# Acte II : honnête jusqu'au J9, enveloppes gardées ensuite (Revue du J17).
			p.keep_bribes = 1.0
			p.bribes_from_day = 10
			p.items = {&"sc21_philippa": SD.KEEP, &"sc45_ravel": SD.RETURN}
			p.choices = {&"d13_scanner": &"install", &"d16_unplug": &"keep"}
		&"drift":
			p.verdicts = {&"sc22_mira": VK.DENY, &"sc50_ilan": VK.DENY, &"sc50_mira": VK.DENY}
			p.choices = {&"d09_drift": &"buy", &"d10_drift": &"stay", &"d19_drift": &"buy",
					# Acte III : reste au J20, part au J30 (places de la Soute, sinon billets).
					&"d27_drift": &"buy", &"d27_tycho": &"buy"}
			p.verdicts[&"sc82_dora"] = VK.DENY
			p.verdicts[&"sc82_mira"] = VK.DENY
		&"drift10":
			p.verdicts = {&"sc22_mira": VK.DENY}
			p.choices = {&"d09_drift": &"buy", &"d10_drift": &"board"}
		&"archiviste":
			p.items = {&"sc33_corvo": SD.KEEP, &"sc44_lindgren": SD.KEEP, &"sc23_lindgren": SD.KEEP}
			p.choices = {&"d12_page": &"keep", &"d14_names": &"write", &"d17_file": &"copy", &"d19_registre": &"send"}
		&"solidaire":
			p.verdicts = {&"sc35_okonkwo_released": VK.APPROVE, &"sc35_okonkwo_quai": VK.APPROVE,
					&"sc41_sato": VK.APPROVE, &"sc45_ravel": VK.APPROVE}
			p.choices = {&"d09_okonkwo": &"refuse", &"d11_petition": &"sign", &"d15_fund": &"give",
					&"d17_list": &"warn", &"d19_strike": &"join",
					# Acte III : Tycho, la caisse, le vote du J29.
					&"d21_amnesty": &"refuse", &"d23_job": &"tycho", &"d25_tycho_fund": &"give", &"d29_strike": &"join"}
			p.verdicts.merge({&"sc55_valentin": VK.APPROVE, &"sc63_dmitri": VK.APPROVE, &"sc75_okonkwo": VK.APPROVE})
		&"overrun":
			p.overrun = true
		&"passeur":
			# F10 : le réseau des répondants et les familles de Tycho au J30.
			p.verdicts = {&"sc59_beaumont": VK.APPROVE, &"sc55_valentin": VK.APPROVE, &"sc82_dora": VK.DENY,
					&"sc82_mira": VK.DENY}
			p.items = {&"sc79_adeyemi": SD.KEEP, &"sc64_lindgren": SD.KEEP}
			p.choices = {&"d25_tycho_fund": &"give"}
			p.pace = 0.8
			# Au J30, le quota (3) est dépassé : les familles entrent imputées (0 ₵).
			p.overrun = true
		&"temoin":
			# F8 : la vérité à l'Enquête, le registre de Tycho.
			p.items = {&"sc33_corvo": SD.KEEP, &"sc44_lindgren": SD.KEEP, &"sc23_lindgren": SD.KEEP,
					&"sc65_yara": SD.KEEP, &"sc77_lindgren": SD.KEEP, &"sc79_adeyemi": SD.KEEP, &"sc82_dora": SD.KEEP,
					&"sc82_mira": SD.KEEP}
			p.verdicts = {&"sc59_beaumont": VK.APPROVE}
			p.choices = {&"d12_page": &"keep", &"d14_names": &"write", &"d17_file": &"copy", &"d19_registre": &"send",
					&"d22_q1": &"tell", &"d24_noa": &"truth", &"d25_dora": &"write", &"d26_q2": &"tell",
					&"d28_q3": &"tell", &"d29_deposition": &"truth"}
		&"accusateur":
			p.choices = {&"d22_q1": &"accuse", &"d26_q2": &"accuse", &"d28_q3": &"accuse", &"d29_deposition": &"loyal"}
		&"mercenary3":
			# Acte III : honnête jusqu'au J20, enveloppes gardées ensuite (Déposition).
			p.keep_bribes = 1.0
			p.bribes_from_day = 21
			p.items = {&"sc51_valcourt": SD.KEEP, &"sc66_lev": SD.KEEP}
		&"negligent":
			p.spending = &"rent_only"
		&"evicted":
			p.spending = &"none"
		# M13 (docs/M13.md §4.5).
		&"presse":
			p.ask_rate = 0.3
			p.search_policy = SEARCH_NEVER
		&"curieux":
			p.ask_rate = 1.0
			p.search_policy = SEARCH_CUE
			p.search_zones = ZONES_FULL
		&"zele":
			p.search_policy = SEARCH_ALWAYS
			p.search_zones = ZONES_FULL
		&"economiste":
			p.upgrade_policy = UPGRADES_EAGER
	return p


## Préréglage `preset_name` joué en mode Récit (D-102).
static func story(preset_name: StringName = &"default", p_accuracy: float = 0.95) -> SimProfile:
	return preset(StringName(STORY_PREFIX + String(preset_name)), p_accuracy)


## Vrai si un verdict est imposé pour ce cas (étiquette de dialogue).
func forces(case: Case) -> bool:
	for tag: StringName in case.dialogue_tags:
		if verdicts.has(tag):
			return true
	return false


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
	if item.kind == SlippedItem.Kind.ENVELOPE and roll < keep_bribes and item.is_allowed(SlippedItem.Decision.KEEP) \
			and day_of(case) >= bribes_from_day:
		return SlippedItem.Decision.KEEP
	return item.default_decision


## Choix du soir du profil résolus sur les événements offerts (QA-036) : par
## intention plutôt que par identifiant exact — une variante conditionnelle au
## même libellé remplace l'option demandée (`d29_deposition` : `loyal` →
## `loyal_paid` si `montclair_pliable`). Les choix sans option offerte sont omis.
func choices_for(events: Array[EveningEvent]) -> Dictionary[StringName, StringName]:
	var resolved: Dictionary[StringName, StringName] = {}
	for event: EveningEvent in events:
		var wanted: StringName = choices.get(event.id, &"")
		var option: EveningOptionDef = event.option_for_intent(wanted)
		if option != null:
			resolved[event.id] = option.id
	return resolved


## Option offerte pour l'intention du profil sur un événement (`null` : aucune).
func option_for(event: EveningEvent) -> EveningOptionDef:
	if event == null:
		return null
	var wanted: StringName = choices.get(event.id, &"")
	return event.option_for_intent(wanted)


## Jour d'un cas (identifiant `dNN_cMM`), 0 si inconnu.
static func day_of(case: Case) -> int:
	var text: String = String(case.case_id)
	return text.substr(1, 2).to_int() if text.begins_with("d") and text.length() >= 3 else 0


## M13 : probabilité de relever une fausse déclaration une fois la question posée.
func statement_catch_rate() -> float:
	return statement_catch if statement_catch >= 0.0 else accuracy


## M13 : AG-04 n'est jamais acheté par la politique `smart`, sauf mercenaire.
func is_mercenary() -> bool:
	return String(name).trim_prefix(STORY_PREFIX).begins_with("mercenary")


## M12 : profil de Garde à précision dégressive (`balance_sim --garde --decay`).
static func garde_decaying() -> SimProfile:
	var p: SimProfile = SimProfile.new()
	p.name = &"garde_decay"
	p.accuracy = GARDE_DECAY_START
	p.garde_decay = true
	return p


## M12 : précision du joueur simulé en Garde selon le palier et les unités
## actives (constante sans `garde_decay`).
func garde_accuracy(tier: int, active_units: int) -> float:
	if not garde_decay:
		return accuracy
	var value: float = GARDE_DECAY_START - GARDE_DECAY_PER_TIER * tier \
			- GARDE_DECAY_PER_UNIT * maxi(active_units - GARDE_DECAY_FREE_UNITS, 0)
	return clampf(value, 0.0, 1.0)
