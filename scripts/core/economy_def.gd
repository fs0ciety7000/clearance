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
## M7 : taxe d'air relevée à partir de `air_tax_raise_day` (mesures d'urgence
## après l'attentat du J8) ; égale à `air_tax` = pas de hausse.
@export var air_tax_raised: int = 5
@export var air_tax_raise_day: int = 8
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

@export_group("M7")
## Prime de signalement d'un mot des Lucioles (GDD §4.7 : soirée J3, objet glissé).
@export var report_bonus: int = 10
## Audit du J9 (NARRATIVE §5) : score = suspicion − 1 si test de l'Inspecteur réussi.
@export var audit_arrest_score: int = 4
@export var audit_retention_score: int = 2
@export var audit_retention: int = 30
## Fin F6 : solde minimal après le bilan du J10.
@export var drift_min_credits: int = 30
## Fin F4 : indice de conformité minimal.
@export var glory_min_compliance: float = 0.85

@export_group("Acte II")
## Soirée pivot (« Nuit des vannes », D-076) : la suspicion y est divisée.
@export var pivot_day: int = 10
@export var pivot_suspicion_divisor: int = 2
## M2 — rations d'air (à partir de `ration_start_day`, remplacent la taxe d'air).
@export var ration_start_day: int = 11
@export var ration_self: int = 3
@export var ration_ilan: int = 4
@export var ration_noa: int = 3
@export var ration_dora: int = 4
## Forfait par ration sans compteur posé (`meter_refused`), J12 → J19.
@export var meter_surcharge: int = 1
@export var meter_fee: int = 10
## Prélèvements de Rééquilibrage (D-079) : `levy_rate` de l'épargne au-delà de
## `levy_floor`, les soirs `levy_days`.
@export var levy_rate: float = 0.30
@export var levy_floor: int = 40
@export var levy_days: PackedInt32Array = PackedInt32Array([11, 17])
## Hausses datées.
@export var food_raised: int = 12
@export var food_raise_day: int = 15
@export var oxygen_raised: int = 15
@export var oxygen_raise_day: int = 16
@export var medicine_raised: int = 20
@export var medicine_raise_day: int = 16
## Location de l'ACV-2 (M3), retenue d'office chaque soir du J14 au J19.
@export var lease_cost: int = 5
## Salaire d'Ilan, technicien·ne de rationnement (J13 → J19).
@export var ilan_job_income: int = 8
@export var ilan_job_first_day: int = 13
## Dépenses datées (montants des options du soir, reportés dans les données).
@export var bail: int = 60
@export var dora_ticket: int = 40
@export var drift2_cost: int = 60
## Revue du J17 (docs/ACT2.md §3.3).
@export var review_arrest_score: int = 5
@export var review_demote_score: int = 3
@export var review_retention: int = 40
## Seuils des fins du J20 (§1.3) — réglés par `tools/balance_sim.gd`.
@export var double_game2_threshold: int = 7
@export var air2_trust_threshold: int = 7
@export var glory2_loyalty_threshold: int = 7
@export var strike_solidarity_threshold: int = 3
@export var registre_threshold: int = 3
@export var drift2_min_present: int = 2


func air_tax_for(day_number: int) -> int:
	if day_number >= ration_start_day:
		return 0
	return air_tax_raised if day_number >= air_tax_raise_day else air_tax


## Acte II : rations d'air au lieu de la taxe (M2).
func rations_for(day_number: int) -> bool:
	return day_number >= ration_start_day


func food_for(day_number: int) -> int:
	return food_raised if day_number >= food_raise_day else food


func oxygen_for(day_number: int) -> int:
	return oxygen_raised if day_number >= oxygen_raise_day else oxygen


func medicine_for(day_number: int) -> int:
	return medicine_raised if day_number >= medicine_raise_day else medicine_per_member


## Ration d'un proche (`Household.*`), 0 si inconnu.
func ration_of(member_id: StringName) -> int:
	match member_id:
		&"ilan":
			return ration_ilan
		&"noa":
			return ration_noa
		&"dora":
			return ration_dora
	return 0


## Prélèvement de Rééquilibrage du soir sur un solde (0 hors jours de prélèvement).
func levy_for(day_number: int, balance: int) -> int:
	if not levy_days.has(day_number):
		return 0
	return floori(maxf(balance - levy_floor, 0.0) * levy_rate)


func rent_for(day_number: int) -> int:
	return rent_raised if day_number >= rent_raise_day else rent


func oxygen_due(day_number: int) -> bool:
	return oxygen_every_n_days > 0 and day_number % oxygen_every_n_days == 0
