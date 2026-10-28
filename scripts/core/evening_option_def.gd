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
## Ilan est « mis·e en attente » (dénoncé·e) : PERDU motivé.
const HOUSEHOLD_ILAN_DETAINED: StringName = &"ilan_detained"

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
