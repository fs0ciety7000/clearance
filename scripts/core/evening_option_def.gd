## Option d'un événement du soir (M7, NARRATIVE §5) — données.
##
## `cost` est débité avec les dépenses (une option `requires_funds` est
## indisponible si le solde ne la couvre pas : pas de dette, ex. laissez-passer
## de dérive), `gain` crédité (primes : dénonciation, colis, déposition).
## `flags` : deltas de drapeaux (0 = drapeau mis à vrai). `line_costs` : coût
## imposé d'un poste du soir (`heating` → 0 : chauffage offert). `household` :
## effet sur le foyer (`HOUSEHOLD_*`). `default_rank` : préférence du choix par
## défaut sans UI (le plus petit rang disponible et finançable l'emporte ; −1 =
## jamais par défaut).
class_name EveningOptionDef
extends Resource

## Noa tombe malade (bio-scan sauté).
const HOUSEHOLD_NOA_SICK: StringName = &"noa_sick"
## Ilan est « mis·e en attente » (dénoncé·e, vannes échouées) : vivant·e,
## absent·e du foyer, libérable (Acte II : distinct de PERDU).
const HOUSEHOLD_ILAN_DETAINED: StringName = &"ilan_detained"
## Acte II : Ilan libéré·e contre caution (rentre MALADE).
const HOUSEHOLD_ILAN_RELEASED: StringName = &"ilan_released"
## Acte II : Ilan caché·e / parti·e dans la Soute (ABSENT · DANS LA SOUTE).
const HOUSEHOLD_ILAN_SOUTE: StringName = &"ilan_soute"
## Acte II : Ilan rentre de la Soute (MALADE).
const HOUSEHOLD_ILAN_BACK: StringName = &"ilan_back"
## Acte II : Dora rentre à Tycho (ABSENT · PARTIE À TYCHO, vivante).
const HOUSEHOLD_DORA_TYCHO: StringName = &"dora_tycho"

@export var id: StringName = &""
@export var label_key: String = ""
@export var result_key: String = ""
@export var cost: int = 0
@export var gain: int = 0
@export var requires_funds: bool = true
@export var flags: Dictionary[StringName, int] = {}
@export var line_costs: Dictionary[StringName, int] = {}
@export var household: StringName = &""
@export var condition: FlagCondition = null
@export var default_rank: int = 0
## Acte II : fin de campagne immédiate si l'option est retenue (« Embarquer »
## au J10 → `f6_drift`, B30) ; vide sinon.
@export var ends_campaign: StringName = &""
## Acte II : jauges fixées à une valeur absolue (`registre := 0`, B30),
## appliquées après les deltas de `flags`.
@export var set_gauges: Dictionary[StringName, int] = {}
