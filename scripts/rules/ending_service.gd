## Fins de la campagne (M7, GDD §11.2, NARRATIVE §6) — pur, statique.
##
## - **Audit du J9** (`audit_outcome`) : score = `suspicion` − 1 si le test de
##   l'Inspecteur est réussi ; ≥ 4 → F1 immédiate ; 2–3 → retenue de 30 ₵ (+ 30 ₵
##   confisqués si l'enveloppe de Ravel a été gardée), `loyalty −1`,
##   `audit_retention` ; ≤ 1 → `audit_clean`.
## - **Fin de campagne** (`evaluate_final`, après le bilan du J10, pas de
##   soirée) : priorité F1 > F3 > F2 > F5 > F6 > F4 > F7 (conditions exactes de
##   NARRATIVE §6.1 ; F2 et F3 sont anticipées, évaluées le soir par
##   `EveningService`, mais F3 est revérifiée ici).
## - **Épilogue** (`epilogue`) : titre + lignes (clés `end_fN_*`), lignes
##   conditionnelles « [si drapeau] sinon la suivante » (NARRATIVE §6.2).
class_name EndingService
extends RefCounted

const F1_ARRESTED: StringName = &"f1_arrested"
const F2_REASSIGNED: StringName = &"f2_reassigned"
const F3_FAMILY_LOST: StringName = &"f3_family_lost"
const F4_GLORY: StringName = &"f4_glory"
const F5_AIR: StringName = &"f5_air"
const F6_DRIFT: StringName = &"f6_drift"
const F7_REOPENS: StringName = &"f7_reopens"
const ALL_ENDINGS: Array[StringName] = [F1_ARRESTED, F2_REASSIGNED, F3_FAMILY_LOST, F4_GLORY, F5_AIR, F6_DRIFT, F7_REOPENS]
## Drapeau posé quand F1 tombe à l'audit (variante d'épilogue).
const FLAG_AUDIT_ARRESTED: StringName = &"audit_arrested"
const DOUBLE_GAME_THRESHOLD: int = 3
const AIR_TRUST_THRESHOLD: int = 4
const GLORY_LOYALTY_THRESHOLD: int = 3
const MIN_ALIVE: int = 2

## Résultats de l'audit.
const AUDIT_ARREST: StringName = &"arrest"
const AUDIT_RETENTION: StringName = &"retention"
const AUDIT_CLEAN: StringName = &"clean"


static func audit_score(flags: Dictionary[StringName, Variant]) -> int:
	var score: int = FlagCondition.gauge_value(flags, &"suspicion")
	if FlagCondition.is_flag_true(flags, &"inspector_test_passed"):
		score -= 1
	return score


## `{score, result, result_key, cost, flags: {drapeau: delta}, ending}`.
static func audit_outcome(flags: Dictionary[StringName, Variant], economy: EconomyDef) -> Dictionary:
	var score: int = audit_score(flags)
	var outcome: Dictionary = {"score": score, "cost": 0, "flags": {}, "ending": &""}
	if score >= economy.audit_arrest_score:
		outcome["result"] = AUDIT_ARREST
		outcome["result_key"] = "evt_d09_audit_arrest"
		outcome["flags"] = {FLAG_AUDIT_ARRESTED: 0}
		outcome["ending"] = F1_ARRESTED
	elif score >= economy.audit_retention_score:
		var cost: int = economy.audit_retention
		if FlagCondition.is_flag_true(flags, &"inspector_bribe_taken"):
			cost += economy.audit_retention
		outcome["result"] = AUDIT_RETENTION
		outcome["result_key"] = "evt_d09_audit_retention"
		outcome["cost"] = cost
		outcome["flags"] = {&"audit_retention": 0, &"loyalty": -1}
	else:
		outcome["result"] = AUDIT_CLEAN
		outcome["result_key"] = "evt_d09_audit_clean"
		outcome["flags"] = {&"audit_clean": 0}
	return outcome


static func is_double_game(flags: Dictionary[StringName, Variant]) -> bool:
	return FlagCondition.gauge_value(flags, &"lucioles_trust") >= DOUBLE_GAME_THRESHOLD \
			and FlagCondition.gauge_value(flags, &"loyalty") >= DOUBLE_GAME_THRESHOLD


## Fin de campagne après le bilan du J10 (`credits` : solde après le bilan).
static func evaluate_final(flags: Dictionary[StringName, Variant], household: Household, credits: int,
		compliance: float, economy: EconomyDef) -> StringName:
	var alive: int = household.alive_count() if household != null else 3
	var trust: int = FlagCondition.gauge_value(flags, &"lucioles_trust")
	var loyalty: int = FlagCondition.gauge_value(flags, &"loyalty")
	var passed: bool = FlagCondition.is_flag_true(flags, &"final_passed")
	var detained: bool = FlagCondition.is_flag_true(flags, &"final_detained")
	if is_double_game(flags):
		return F1_ARRESTED
	if alive == 0:
		return F3_FAMILY_LOST
	if passed and trust >= AIR_TRUST_THRESHOLD:
		return F5_AIR
	if FlagCondition.is_flag_true(flags, &"drift_passes_bought") and alive >= MIN_ALIVE \
			and credits >= economy.drift_min_credits and not detained:
		return F6_DRIFT
	if detained and loyalty >= GLORY_LOYALTY_THRESHOLD and compliance >= economy.glory_min_compliance - 0.0001 \
			and alive >= MIN_ALIVE:
		return F4_GLORY
	return F7_REOPENS


## Variante F5 : Brûlants si Arkady est passé ou si le colis a été caché.
static func is_burners_variant(flags: Dictionary[StringName, Variant]) -> bool:
	return FlagCondition.is_flag_true(flags, &"sc20_passed") or FlagCondition.is_flag_true(flags, &"brulants_package")


## Épilogue : `{ending, title_key, eyebrow_key, lines: PackedStringArray}`.
static func epilogue(ending: StringName, flags: Dictionary[StringName, Variant], household: Household) -> Dictionary:
	var lines: PackedStringArray = []
	var title: String = "end_title_%s" % ending
	var dora_alive: bool = household != null and household.get_member(Household.DORA) != null \
			and household.get_member(Household.DORA).is_alive()
	match ending:
		F1_ARRESTED:
			title = "end_f1_title"
			lines = _lines(flags, [
				"end_f1_l1", "end_f1_l2",
				["end_f1_l3_audit", FLAG_AUDIT_ARRESTED, "end_f1_l3_double"],
				"end_f1_l4",
				["end_f1_l5_okonkwo_warned", &"okonkwo_warned", "end_f1_l5"],
				"end_f1_l6"])
		F2_REASSIGNED:
			title = "end_f2_title"
			lines = _lines(flags, ["end_f2_l1", "end_f2_l2", "end_f2_l3", "end_f2_l4", "end_f2_l5", "end_f2_l6"])
		F3_FAMILY_LOST:
			title = "end_f3_title"
			lines = _lines(flags, ["end_f3_l1", "end_f3_l2", "end_f3_l3", ["end_f3_l4_lumika", &"lumika_learned", "end_f3_l4"],
				"end_f3_l5"])
		F4_GLORY:
			title = "end_f4_title"
			lines = _lines(flags, ["end_f4_l1", "end_f4_l2", ["end_f4_l3_ilan", &"ilan_denounced", "end_f4_l3"],
				["end_f4_l4_okonkwo_denounced", &"okonkwo_denounced", "end_f4_l4_okonkwo"],
				["end_f4_l5_mazur", &"sc11_veteran_passed", ""], "end_f4_l6", "end_f4_l7"])
		F5_AIR:
			title = "end_f5_title"
			if is_burners_variant(flags):
				lines = _lines(flags, ["end_f5b_l1", "end_f5b_l2", ["end_f5b_l3_package", &"brulants_package", ""],
					"end_f5b_l4", "end_f5b_l5", "end_f5b_l6"])
			else:
				lines = _lines(flags, ["end_f5v_l1", ["end_f5v_l2_ilan", &"ilan_supported", "end_f5v_l2"], "end_f5v_l3",
					["end_f5v_l4_okonkwo_warned", &"okonkwo_warned", "end_f5v_l4"],
					["end_f5v_l5_hadid", &"sc16_hana_passed", ""], "end_f5v_l6", "end_f5v_l7"])
		F6_DRIFT:
			title = "end_f6_title"
			lines = _lines(flags, ["end_f6_l1", "end_f6_l2"])
			lines.append("end_f6_l3_dora" if dora_alive else "end_f6_l3")
			lines.append_array(_lines(flags, ["end_f6_l4", ["end_f6_l5_final_passed", &"final_passed", "end_f6_l5"],
				"end_f6_l6"]))
		F7_REOPENS:
			title = "end_f7_title"
			var second: String = "end_f7_l2"
			if FlagCondition.is_flag_true(flags, &"final_denied"):
				second = "end_f7_l2_denied"
			elif FlagCondition.is_flag_true(flags, &"final_passed"):
				second = "end_f7_l2_passed"
			elif FlagCondition.is_flag_true(flags, &"final_detained"):
				second = "end_f7_l2_detained"
			lines = PackedStringArray(["end_f7_l1", second, "end_f7_l3", "end_f7_l4", "end_f7_l5", "end_f7_l6"])
	return {"ending": ending, "title_key": title, "eyebrow_key": "end_eyebrow_%s" % ending, "lines": lines,
			"variant": "brulants" if ending == F5_AIR and is_burners_variant(flags) else ""}


## Lignes : texte simple, ou `[clé_si_vrai, drapeau, clé_sinon]` (sinon vide = omise).
static func _lines(flags: Dictionary[StringName, Variant], spec: Array) -> PackedStringArray:
	var result: PackedStringArray = []
	for item: Variant in spec:
		if item is Array:
			var parts: Array = item
			var flag: StringName = parts[1]
			var key: String = parts[0] if FlagCondition.is_flag_true(flags, flag) else parts[2]
			if not key.is_empty():
				result.append(key)
		else:
			result.append(str(item))
	return result
