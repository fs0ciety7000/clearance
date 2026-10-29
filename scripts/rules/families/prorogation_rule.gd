## Famille « Prorogation de Continuité » (R32, Acte III J21 ; docs/ACT3.md
## §2.4) — règle de **contexte**, jamais de violation : les documents expirés
## entre `window_start` et `window_end` (inclus) sont prorogés jusqu'à
## `extended_until` (inclus). Lue par les règles d'expiration
## (`RuleContext.is_document_expired` : R02, R05, R24, R26, R28, dérogation de
## R16) et par la comparaison « date d'expiration ↔ date du jour »
## (`disc_prorogated`, CONCORDANT). Le firmware NX (R27) n'est pas concerné.
class_name ProrogationRule
extends Rule

## Fenêtre de prorogation (`GameDate`) : 22.03 → 01.04.2187.
@export var window_start: int = 0
@export var window_end: int = 0
## Dernier jour de validité d'un document prorogé (10.04.2187).
@export var extended_until: int = 0


## Vrai si un document expiré le `expiry_date` est prorogé à la date `today`.
func covers(expiry_date: int, today: int) -> bool:
	return expiry_date >= window_start and expiry_date <= window_end and today <= extended_until


## Vrai si la date tombe dans la fenêtre (bruit légitime du générateur).
func in_window(expiry_date: int) -> bool:
	return expiry_date >= window_start and expiry_date <= window_end


## Comparaison « date d'expiration ↔ R32 » : PROROGÉ (concordant) dans la
## fenêtre, EXPIRÉ (discordant) hors fenêtre.
func check_against(case: Case, ref: FieldRef, ctx: RuleContext) -> Discrepancy.Result:
	var field: FieldDef = case.get_field_def(ref)
	if field == null or field.truth_path != &"document.expiry_date" or ctx == null:
		return Discrepancy.Result.INCOMPARABLE
	var value: Variant = case.get_value(ref)
	if not value is int:
		return Discrepancy.Result.INCOMPARABLE
	var expiry: int = value
	if expiry >= ctx.today or covers(expiry, ctx.today):
		return Discrepancy.Result.CONCORDANT
	return Discrepancy.Result.DISCORDANT
