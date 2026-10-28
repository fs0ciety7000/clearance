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
## Acte II (docs/ACT2.md §1.3, §5.4 ; D-076, D-078) : le J10 n'est plus
## terminal (sauf F1 de l'audit, F2/F3 anticipées, F6 « Embarquer ») ;
## **Revue du J17** (`review_outcome`, F1 anticipée) ; fin du J20
## (`evaluate_final_act2`) : F1 > F3 > F2 > F5 > F9 > F8 > F6 > F4 > F7, avec
## F8 « Le Registre » et F9 « Les vitres éteintes » ; épilogues `end2_*`
## (`epilogue_act2`) — F2, F3 et une F6 choisie au J10 gardent `end_f*`.
class_name EndingService
extends RefCounted

const F1_ARRESTED: StringName = &"f1_arrested"
const F2_REASSIGNED: StringName = &"f2_reassigned"
const F3_FAMILY_LOST: StringName = &"f3_family_lost"
const F4_GLORY: StringName = &"f4_glory"
const F5_AIR: StringName = &"f5_air"
const F6_DRIFT: StringName = &"f6_drift"
const F7_REOPENS: StringName = &"f7_reopens"
## Acte II (D-078).
const F8_REGISTRE: StringName = &"f8_registre"
const F9_STRIKE: StringName = &"f9_strike"
const ALL_ENDINGS: Array[StringName] = [F1_ARRESTED, F2_REASSIGNED, F3_FAMILY_LOST, F4_GLORY, F5_AIR, F6_DRIFT, F7_REOPENS,
		F8_REGISTRE, F9_STRIKE]
## Priorité des fins du J20 (D-078).
const ACT2_PRIORITY: Array[StringName] = [F1_ARRESTED, F3_FAMILY_LOST, F2_REASSIGNED, F5_AIR, F9_STRIKE, F8_REGISTRE,
		F6_DRIFT, F4_GLORY, F7_REOPENS]
## Drapeau posé par la soirée pivot quand la campagne continue (Acte II).
const FLAG_ACT2: StringName = &"act2_started"
## Revue du J17 (`EveningEventDef.audit_id`).
const AUDIT_REVIEW: StringName = &"review"
const FLAG_REVIEW_ARRESTED: StringName = &"review_arrested"
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


## Acte II — score de la Revue du J17 : `suspicion` + 2 si le boîtier magenta
## est encore branché − 1 si l'ACV-2 est loué (« dossier transparent »).
static func review_score(flags: Dictionary[StringName, Variant]) -> int:
	var score: int = FlagCondition.gauge_value(flags, &"suspicion")
	if FlagCondition.is_flag_true(flags, &"scanner_luciole") and not FlagCondition.is_flag_true(flags, &"scanner_luciole_removed"):
		score += 2
	if FlagCondition.is_flag_true(flags, &"scanner_consortium"):
		score -= 1
	return score


## Acte II — Revue de Rééquilibrage (J17) : ≥ `review_arrest_score` → F1 ;
## ≥ `review_demote_score` → rétrogradation (−40 ₵, `loyalty −1`,
## `purge_demoted`, `promotion_revoked`) ; sinon `purge_clean`.
static func review_outcome(flags: Dictionary[StringName, Variant], economy: EconomyDef) -> Dictionary:
	var score: int = review_score(flags)
	var outcome: Dictionary = {"score": score, "cost": 0, "flags": {}, "ending": &""}
	if score >= economy.review_arrest_score:
		outcome["result"] = AUDIT_ARREST
		outcome["result_key"] = "evt_d17_review_arrest"
		outcome["flags"] = {FLAG_REVIEW_ARRESTED: 0}
		outcome["ending"] = F1_ARRESTED
	elif score >= economy.review_demote_score:
		outcome["result"] = AUDIT_RETENTION
		outcome["result_key"] = "evt_d17_review_demoted"
		outcome["cost"] = economy.review_retention
		outcome["flags"] = {&"purge_demoted": 0, &"promotion_revoked": 0, &"loyalty": -1}
	else:
		outcome["result"] = AUDIT_CLEAN
		outcome["result_key"] = "evt_d17_review_clean"
		outcome["flags"] = {&"purge_clean": 0}
	return outcome


## Acte II — double jeu jugé au J20 (`lucioles_trust` et `loyalty` ≥ 7).
static func is_double_game2(flags: Dictionary[StringName, Variant], economy: EconomyDef) -> bool:
	return FlagCondition.gauge_value(flags, &"lucioles_trust") >= economy.double_game2_threshold \
			and FlagCondition.gauge_value(flags, &"loyalty") >= economy.double_game2_threshold


## Acte II — fins possibles au J20 (conditions exactes de docs/ACT2.md §1.3),
## dans l'ordre de priorité de D-078 (F2 n'est jugée que le soir).
static func act2_candidates(flags: Dictionary[StringName, Variant], household: Household, credits: int,
		compliance: float, economy: EconomyDef) -> Array[StringName]:
	var result: Array[StringName] = []
	var alive: int = household.alive_count() if household != null else 3
	var present: int = household.present_count() if household != null else 3
	var trust: int = FlagCondition.gauge_value(flags, &"lucioles_trust")
	var loyalty: int = FlagCondition.gauge_value(flags, &"loyalty")
	var detained: bool = FlagCondition.is_flag_true(flags, &"final2_detained")
	var strike: bool = FlagCondition.is_flag_true(flags, &"strike_joined")
	if is_double_game2(flags, economy):
		result.append(F1_ARRESTED)
	if alive == 0:
		result.append(F3_FAMILY_LOST)
	if FlagCondition.is_flag_true(flags, &"final2_passed") and trust >= economy.air2_trust_threshold:
		result.append(F5_AIR)
	if strike and FlagCondition.gauge_value(flags, &"solidarite") >= economy.strike_solidarity_threshold:
		result.append(F9_STRIKE)
	if FlagCondition.is_flag_true(flags, &"registre_sent"):
		result.append(F8_REGISTRE)
	if FlagCondition.is_flag_true(flags, &"drift2_passes_bought") and present >= economy.drift2_min_present \
			and credits >= economy.drift_min_credits and not detained:
		result.append(F6_DRIFT)
	if detained and loyalty >= economy.glory2_loyalty_threshold and compliance >= economy.glory_min_compliance - 0.0001 \
			and alive >= MIN_ALIVE and not FlagCondition.is_flag_true(flags, &"promotion_revoked") and not strike:
		result.append(F4_GLORY)
	result.append(F7_REOPENS)
	return result


## Acte II — fin de campagne après le bilan du J20 (D-078).
static func evaluate_final_act2(flags: Dictionary[StringName, Variant], household: Household, credits: int,
		compliance: float, economy: EconomyDef) -> StringName:
	return act2_candidates(flags, household, credits, compliance, economy)[0]


## Acte II — variante F5 « Brûlants » : Kasimir ou Arkady passés, ou colis caché,
## sauf si Kasimir a été mis en attente.
static func is_burners_variant2(flags: Dictionary[StringName, Variant]) -> bool:
	if FlagCondition.is_flag_true(flags, &"sc47_kasimir_detained"):
		return false
	return FlagCondition.is_flag_true(flags, &"sc47_kasimir_passed") or is_burners_variant(flags)


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
	if ending == F8_REGISTRE or ending == F9_STRIKE:
		return epilogue_act2(ending, flags, household)
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


## Acte II — épilogue d'une fin jugée après le pivot du J10 (`end2_*`,
## docs/ACT2.md §5.4). F2, F3 : épilogues de l'Acte I.
static func epilogue_act2(ending: StringName, flags: Dictionary[StringName, Variant], household: Household) -> Dictionary:
	var dora: Household.Member = household.get_member(Household.DORA) if household != null else null
	var dora_alive: bool = dora != null and dora.is_alive()
	var dora_home: bool = dora != null and dora.is_present()
	var ilan_final: bool = FlagCondition.is_flag_true(flags, &"ilan_joined_soute")
	var lines: PackedStringArray = []
	var variant: String = ""
	match ending:
		F2_REASSIGNED, F3_FAMILY_LOST:
			return epilogue(ending, flags, household)
		F1_ARRESTED:
			lines = _lines(flags, ["end2_f1_l1", ["end2_f1_l2_review", FLAG_REVIEW_ARRESTED, "end2_f1_l2_double"],
				["end2_f1_l3_ravel", &"ravel_file_destroyed", ""], "end2_f1_l3", "end2_f1_l4", "end2_f1_l5"])
		F4_GLORY:
			lines = _lines(flags, [["end2_f4_l1_ilan", &"ilan_detained_final", "end2_f4_l1"], "end2_f4_l2"])
			var estranged: bool = FlagCondition.is_flag_true(flags, &"ilan_detained_final") or FlagCondition.is_flag_true(flags, &"ilan_denounced")
			lines.append("end2_f4_l3_ilan" if estranged else "end2_f4_l3")
			lines.append("end2_f4_l4_tycho" if FlagCondition.is_flag_true(flags, &"dora_departed") else "end2_f4_l4")
			lines.append_array(_lines(flags, [["end2_f4_l5_silva", &"sc43_mateus_detained", ""],
				["end2_f4_l5_kasimir", &"sc47_kasimir_passed", ""], "end2_f4_l6", "end2_f4_l7"]))
		F5_AIR:
			if is_burners_variant2(flags):
				variant = "brulants"
				lines = _lines(flags, ["end2_f5b_l1", ["end2_f5b_l2_kasimir", &"sc47_kasimir_passed", "end2_f5b_l2"],
					"end2_f5b_l3", "end2_f5b_l4", "end2_f5b_l5", "end2_f5b_l6"])
			else:
				lines = PackedStringArray(["end2_f5v_l1", "end2_f5v_l2_ilan" if ilan_final else "end2_f5v_l2", "end2_f5v_l3"])
				if FlagCondition.is_flag_true(flags, &"strike_joined"):
					lines.append("end2_f5v_l4_strike")
				elif FlagCondition.is_flag_true(flags, &"sc24_dmitri_hired"):
					lines.append("end2_f5v_l4_dmitri")
				else:
					lines.append("end2_f5v_l4")
				lines.append_array(_lines(flags, [["end2_f5v_l5_registre", &"registre_sent", "end2_f5v_l5"], "end2_f5v_l6"]))
		F6_DRIFT:
			lines = _lines(flags, ["end2_f6_l1", "end2_f6_l2"])
			lines.append("end2_f6_l3_tycho" if FlagCondition.is_flag_true(flags, &"dora_departed") else "end2_f6_l3")
			if ilan_final and not FlagCondition.is_flag_true(flags, &"ilan_detained_final"):
				lines.append("end2_f6_l4_ilan")
			lines.append_array(PackedStringArray(["end2_f6_l5", "end2_f6_l6"]))
		F7_REOPENS:
			var second: String = "end2_f7_l2"
			if FlagCondition.is_flag_true(flags, &"final2_denied"):
				second = "end2_f7_l2_denied"
			elif FlagCondition.is_flag_true(flags, &"final2_passed"):
				second = "end2_f7_l2_passed"
			elif FlagCondition.is_flag_true(flags, &"final2_detained"):
				second = "end2_f7_l2_detained"
			lines = PackedStringArray(["end2_f7_l1", second])
			lines.append_array(_lines(flags, [["end2_f7_l3_ravel", &"sc45_ravel_refused", "end2_f7_l3"],
				["end2_f7_l4_lindgren", &"sc49_lindgren_yes", ""], "end2_f7_l5", "end2_f7_l6"]))
		F8_REGISTRE:
			lines = PackedStringArray(["end2_f8_l1", "end2_f8_l2"])
			if FlagCondition.is_flag_true(flags, &"dora_departed") and dora_alive:
				lines.append("end2_f8_l3_tycho")
			elif dora_home:
				lines.append("end2_f8_l3_dora")
			else:
				lines.append("end2_f8_l3")
			lines.append_array(PackedStringArray(["end2_f8_l4", "end2_f8_l5"]))
			lines.append_array(_lines(flags, [["end2_f8_l6_detained", &"final2_detained", ""],
				["end2_f8_l6_lindgren", &"lindgren_signed", ""], "end2_f8_l7"]))
		F9_STRIKE:
			lines = _lines(flags, ["end2_f9_l1", ["end2_f9_l2_sato", &"sc41_sato_spared", "end2_f9_l2"]])
			var okonkwo: bool = FlagCondition.is_flag_true(flags, &"sc35_okonkwo_helped") or FlagCondition.is_flag_true(flags, &"okonkwo_shielded")
			lines.append("end2_f9_l3_okonkwo" if okonkwo else "end2_f9_l3")
			lines.append_array(_lines(flags, [["end2_f9_l4_ravel", &"sc45_ravel_spared", "end2_f9_l4"], "end2_f9_l5",
				["end2_f9_l6_registre", &"registre_sent", "end2_f9_l6"], "end2_f9_l7"]))
		_:
			return epilogue(ending, flags, household)
	var eyebrow: String = "end_eyebrow_%s" % ending
	if ending == F8_REGISTRE:
		eyebrow = "end_eyebrow_f8_registre"
	elif ending == F9_STRIKE:
		eyebrow = "end_eyebrow_f9_strike"
	return {"ending": ending, "title_key": "end2_%s_title" % String(ending).get_slice("_", 0), "eyebrow_key": eyebrow,
			"lines": lines, "variant": variant, "act": 2}


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
