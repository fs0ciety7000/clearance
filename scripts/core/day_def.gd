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


## Heure du shift (UI_FLOW §1) : 10:00 → 18:00, en minutes depuis minuit.
const SHIFT_START_MIN: int = 10 * 60
const SHIFT_LENGTH_MIN: int = 8 * 60


## Heure du shift (minutes depuis minuit) pour une durée et un temps restant.
static func minute_at(p_duration_sec: float, p_remaining_sec: float) -> int:
	if p_duration_sec <= 0.0:
		return SHIFT_START_MIN
	var elapsed: float = clampf(1.0 - p_remaining_sec / p_duration_sec, 0.0, 1.0)
	return SHIFT_START_MIN + floori(elapsed * SHIFT_LENGTH_MIN)


## Cas scénarisé prévu à cet index, ou null.
func get_scripted_case(index: int) -> ScriptedCaseDef:
	for scripted: ScriptedCaseDef in scripted_cases:
		if scripted != null and scripted.at_index == index:
			return scripted
	return null
