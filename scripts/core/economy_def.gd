## Barème de la soirée au Bloc Pétrel (GDD §5.3, §5.4) — `data/economy/economy.tres`.
##
## Toutes les valeurs d'équilibrage économique du foyer sont ici (données,
## pas code) : le Game Designer les règle sans toucher l'`EveningService`.
## Produit par `tools/build_data.gd` (D-029).
class_name EconomyDef
extends Resource

## Solde de départ de la campagne : « avance du Consortium » à la prise de
## poste (GDD §5.3, D-047).
@export var starting_credits: int = 20
@export var rent: int = 15
## Loyer après l'« ajustement sectoriel » (GDD §5.3 : J8).
@export var rent_raised: int = 20
@export var rent_raise_day: int = 8
## Taxe d'air : prélevée d'office, jamais décochable.
@export var air_tax: int = 5
@export var food: int = 10
@export var heating: int = 6
## Oxygène d'appoint de Dora, les soirs pairs (J2, J4…).
@export var oxygen: int = 10
@export var oxygen_every_n_days: int = 2
## Médicaments, par proche `MALADE` / `GRAVEMENT MALADE`.
@export var medicine_per_member: int = 15
## Probabilité que Noa tombe malade dès le premier soir sans chauffage.
@export_range(0.0, 1.0) var noa_cold_sick_chance: float = 0.5
## Soirs consécutifs de privation avant que les proches tombent malades.
@export var deprivation_sick_evenings: int = 2
## Soirs sans soins avant aggravation (MALADE → GRAVEMENT MALADE → PERDU).
@export var untreated_worsen_evenings: int = 2
## Manquements à l'oxygène avant « gravement malade ».
@export var oxygen_grave_misses: int = 2
## Fin F2 : loyers impayés consécutifs.
@export var eviction_unpaid_rent: int = 3
## Fin F2 : soirs consécutifs avec un solde négatif.
@export var debt_evenings_limit: int = 3
## Prime de détention (GDD §5.1) — post-MVP (J7), lue par le ScoringService.
@export var detain_bonus: int = 5


func rent_for(day_number: int) -> int:
	return rent_raised if day_number >= rent_raise_day else rent


func oxygen_due(day_number: int) -> bool:
	return oxygen_every_n_days > 0 and day_number % oxygen_every_n_days == 0
