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


## Cas scénarisé prévu à cet index, ou null.
func get_scripted_case(index: int) -> ScriptedCaseDef:
	for scripted: ScriptedCaseDef in scripted_cases:
		if scripted != null and scripted.at_index == index:
			return scripted
	return null
