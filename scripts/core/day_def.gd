## Paramètres d'un jour de campagne (ARCHITECTURE §5.2, GDD §8, §10).
##
## Le Game Designer règle la difficulté uniquement ici. Les champs du groupe
## « GDD » (🟡 dans le GDD, acceptés par l'Orchestrateur) sont lus par le
## générateur (M3) et le scoring (M5).
class_name DayDef
extends Resource

@export var day_number: int = 1
## Jour absolu (`GameDate`) : J1 = 13.03.2187.
@export var game_date: int = 0
@export var rule_set: RuleSet = null
@export var duration_sec: float = 540.0
@export var passenger_count: int = 8
## Probabilités de 0, 1, 2, 3 anomalies par cas.
@export var anomaly_count_weights: PackedFloat32Array = PackedFloat32Array([1.0, 0.0, 0.0, 0.0])
## Distribution **cible** de 0, 1, 2, 3 anomalies par cas, cas scénarisés,
## avis, révocations et répondants propres compris (docs/ACT3.md §2.1, QA-037) :
## `anomaly_count_weights` est alors compensé pour l'atteindre. Vide : la cible
## est `anomaly_count_weights` (outil `gen_stats`).
@export var anomaly_count_targets: PackedFloat32Array
## Poids relatifs des types (filtrés par le générateur sur les types détectables).
@export var anomaly_weights: Dictionary[AnomalyType.Kind, float] = {}
@export var scripted_cases: Array[ScriptedCaseDef] = []
@export var intro_text_key: String = ""
@export var credit_per_correct: int = 5
## Amende de la 3ᵉ citation du jour.
@export var penalty_per_error: int = 5

@export_group("GDD")
## Poids des origines (`FactionDef.id` → poids).
@export var faction_weights: Dictionary[StringName, float] = {}
## Part des passagers visière baissée (D-021).
@export_range(0.0, 1.0) var visor_down_rate: float = 0.0
## Part des cas avec bruit légitime visible.
@export_range(0.0, 1.0) var legit_noise_rate: float = 0.0
## Part des cas avec anomalie qui offrent un pot-de-vin (J4+).
@export_range(0.0, 1.0) var bribe_rate: float = 0.0
## Part des passagers porteurs d'un code Luciole (hors scénarisés).
@export_range(0.0, 1.0) var luciole_rate: float = 0.0
## Citations du jour sans amende (avertissements).
@export var free_citations_per_day: int = 2
## Amende des citations à partir de la 4ᵉ.
@export var penalty_escalated: int = 10

@export_group("M7")
## Tampon DÉTENTION (« mise en attente ») disponible (J7+, GDD §4.5). Sinon une
## détention tamponnée est lue comme un REFUS.
@export var detain_enabled: bool = false
## Soirée après le shift (faux au J10 : le bilan enchaîne sur la fin, D-053).
@export var has_evening: bool = true
## Montant d'une enveloppe générée (`bribe_rate`) : min/max, par pas de 10 ₵.
@export var bribe_amounts: Vector2i = Vector2i(10, 20)
## Avis de recherche du jour (R22, onglet « Avis de recherche »).
@export var wanted_notices: Array[WantedNoticeDef] = []
## Messages conditionnels du briefing (J4+, `BriefingContent`).
@export var briefing_messages: Array[BriefingMessageDef] = []
## Événements du soir (J4+, `EveningService`).
@export var evening_events: Array[EveningEventDef] = []
## Annonces du haut-parleur du Hall : nombre de cas traités → clé
## (`hall_j7_okonkwo_citation` après le 5ᵉ cas du J7).
@export var hall_announcements: Dictionary[int, String] = {}
## Onglets du Rulebook ouverts ce jour (UI : `origins`, `implants`, `symbols`,
## `seals`, `wanted`), cumulatifs.
@export var rulebook_tabs: PackedStringArray = []


@export_group("Acte II")
## Quota respiratoire du guichet (R23, D-077) : entrées de ressortissants non
## exemptés par jour ; 0 = pas de quota.
@export var air_quota: int = 0
## Acte I : approuver un Luciole **généré** en infraction donne
## `lucioles_trust +1`. Faux à l'Acte II (QA §9, « F5 par accident », B24).
@export var luciole_trust_on_breach: bool = true
## Liste des révocations (R30, onglet « Révocations ») liée à des passagers du jour.
@export var revocations: Array[RevocationDef] = []
## N° ID révoqués sans passager (leurres de la liste, tirés du `day_seed`).
@export var revoked_decoys: int = 0
## Annonces conditionnelles ou horaires (`HallAnnouncementDef`).
@export var announcements: Array[HallAnnouncementDef] = []
## R28 : part des gravitaires C-4 de l'origine visée tirés en C-5 (porteurs
## d'une attestation d'asile) les jours où l'attestation est exigée (QA-026).
@export_range(0.0, 1.0) var asylum_class_rate: float = 0.30
## Documents « de la règle du jour » : quand le passager en porte un,
## `MISSING_DOCUMENT` / `EXPIRED_DOCUMENT` le visent en priorité (QA-026 :
## R28 presque jamais exercée, l'attestation n'était qu'un candidat parmi 3–4).
@export var focus_documents: Array[StringName] = []


@export_group("Acte III")
## Variantes de la directive du jour (`day27_intro_vanne`) : première vraie
## sur les drapeaux du matin, sinon `intro_text_key`.
@export var intro_variants: Array[ConditionalKey] = []
## M1 « Retour aux quais » (B37) : documents retirés du guichet (plus
## produits par le générateur, ligne barrée au Rulebook) — informatif pour l'UI.
@export var retired_documents: Array[StringName] = []
## Quota respiratoire suspendu ce jour si la condition est vraie (climat
## Vanne, J27–J30) ; null = jamais.
@export var quota_suspended_if: FlagCondition = null
## Part des documents datés d'un passager généré propre tirés **dans** la
## fenêtre de prorogation (R32, bruit légitime : expiré mais prorogé).
@export_range(0.0, 1.0) var prorogation_noise_rate: float = 0.0
## Part des leurres de l'onglet Révocations réintégrés (R33, bruit légitime) ;
## un passager généré révoqué peut aussi l'être (`RevocationDef.reinstated_on`).
@export_range(0.0, 1.0) var reinstated_decoy_rate: float = 0.0
## M2 « Répondants » (R34, B42) : part des ressortissants (hors HAL, hors
## convoqués) au motif VISITE FAMILIALE, par origine ; chacun reçoit un
## répondant placé **plus tôt** dans la file (`CaseBuilder`, plan du jour).
@export var family_visit_rates: Dictionary[StringName, float] = {}
## Liens de répondant imposés : index du protégé → index du répondant (J30 :
## familles de Tycho derrière Margaux, Okafor et le réseau). Un répondant
## scénarisé absent rend le protégé à la génération ordinaire.
@export var sponsor_links: Dictionary[int, int] = {}
## Origine imposée aux protégés à lien imposé (J30 : familles de Tycho).
@export var linked_ward_faction: StringName = &""
## Emplacements du réseau (SC-81b) : groupe → index, remplis dans l'ordre par
## les cas scénarisés actifs de ce groupe (`ScriptedCaseDef.slot_group`).
@export var slot_groups: Dictionary[StringName, PackedInt32Array] = {}
## Protégés au plus par répondant généré (cascade lisible).
@export var max_wards_per_sponsor: int = 2
## R36 (B43) : convocations du jour liées à des passagers, leurres (N° sans
## passager), part des ressortissants générés convoqués.
@export var summons: Array[SummonsDef] = []
@export var summons_decoys: int = 0
@export_range(0.0, 1.0) var summons_rate: float = 0.0
## Poids d'anomalies modulés par un drapeau du matin : `{drapeau: {type: facteur}}`
## (`SPONSOR_MISMATCH` ×1,5 si `sc62_tariq_passed`, `FORGED_SUMMONS` ×0,5 si
## `forged_summons_reported`).
@export var anomaly_weight_modifiers: Dictionary[StringName, Dictionary] = {}
## Part de Lucioles ajoutée si un drapeau est vrai (`climate_vanne` : +0,02).
@export var luciole_rate_bonus: Dictionary[StringName, float] = {}
## Admissions correctes comptées dans une jauge, par origine (J30 :
## `tyc` → `pont`, F10).
@export var admission_gauges: Dictionary[StringName, StringName] = {}


@export_group("M12")
## Mode du jour (ARCHITECTURE §11) : `campaign` (J1–J30, indexé par
## `DataCatalog.days`), `epilogue` (J31, un `DayDef` par monde, référencé par
## `EpilogueWorldDef.day_def`), `garde` (gabarit de la Garde de nuit,
## `GardeDef.day_template`). Seuls les jours `campaign` entrent dans
## `DataCatalog.days`.
@export var mode: StringName = &"campaign"
## Monde de l'épilogue (`a`, `b`, `c`, `d`) ; vide hors épilogue.
@export var epilogue_world: StringName = &""
## Aucune économie (J31, Garde) : ni salaire ni amende crédités, citations
## affichées « AVERTISSEMENT », pas de soirée (D-123).
@export var economy_disabled: bool = false
## Horloge non terminale dans les deux modes : le shift finit quand la file
## est traitée (comportement Récit, D-102 ; J31, Garde).
@export var untimed: bool = false
## Part des anomalies injectées en version **subtile** (Garde, §2.5 de M12 ;
## lue par le générateur, lot B).
@export_range(0.0, 1.0) var subtle_rate: float = 0.0

const MODE_CAMPAIGN: StringName = &"campaign"
const MODE_EPILOGUE: StringName = &"epilogue"
const MODE_GARDE: StringName = &"garde"


## Heure du shift (UI_FLOW §1) : 10:00 → 18:00, en minutes depuis minuit.
const SHIFT_START_MIN: int = 10 * 60
const SHIFT_LENGTH_MIN: int = 8 * 60


## Heure du shift (minutes depuis minuit) pour une durée et un temps restant.
static func minute_at(p_duration_sec: float, p_remaining_sec: float) -> int:
	if p_duration_sec <= 0.0:
		return SHIFT_START_MIN
	var elapsed: float = clampf(1.0 - p_remaining_sec / p_duration_sec, 0.0, 1.0)
	return SHIFT_START_MIN + floori(elapsed * SHIFT_LENGTH_MIN)


## Copie propre à un shift (M12, B54) : mêmes définitions (partagées, jamais
## mutées), mais un RuleSet de shift mutable (`RuleSet.make_shift_copy`) ; les
## champs simples de la copie (nombre de passagers, poids d'anomalies,
## avertissements gratuits, date) peuvent être réglés pour ce shift seulement
## (paliers de la Garde, événements). Le `CaseBuilder` reçoit cette copie.
func make_shift_copy() -> DayDef:
	var copy: DayDef = duplicate(false) as DayDef
	copy.rule_set = rule_set.make_shift_copy() if rule_set != null else RuleSet.new().make_shift_copy()
	return copy


## Index de tous les cas scénarisés prévus (toutes conditions confondues),
## croissants : un événement de station n'en couvre jamais un (D-129).
func scripted_indices() -> PackedInt32Array:
	var indices: PackedInt32Array = []
	for scripted: ScriptedCaseDef in scripted_cases:
		if scripted != null and not indices.has(scripted.at_index):
			indices.append(scripted.at_index)
	for group: StringName in slot_groups:
		for index: int in slot_groups[group]:
			if not indices.has(index):
				indices.append(index)
	indices.sort()
	return indices


## Cas scénarisé prévu à cet index, ou null.
func get_scripted_case(index: int) -> ScriptedCaseDef:
	for scripted: ScriptedCaseDef in scripted_cases:
		if scripted != null and scripted.at_index == index:
			return scripted
	return null
