## Scanner partiel du guichet (Acte II, M3 ; docs/ACT2.md §2.5, UI_FLOW §5.3) —
## pur, statique. Deux sources exclusives : l'ACV-2 du Consortium
## (`scanner_consortium`, loué) ou le boîtier magenta des Lucioles
## (`scanner_luciole`, débranchable : `scanner_luciole_removed`) ; l'ACV-2
## l'emporte si les deux sont posés.
##
## Effet identique : au début de chaque inspection, il **pré-trace** les liens
## « date ↔ date du jour » **discordants** (expirations, firmware NX) de tous
## les documents. Il ne ment jamais (zéro faux positif : chaque lien est une
## vraie `Discrepancy` DISCORDANTE du `DiscrepancyChecker`) et ne couvre
## qu'une catégorie : les dates. Le joueur confirme d'un clic
## (`discrepancy_check_requested` → discordance épinglée) ou ignore.
class_name PartialScanner
extends RefCounted

const SOURCE_ACV: StringName = &"acv"
const SOURCE_LUCIOLE: StringName = &"luciole"
const FLAG_CONSORTIUM: StringName = &"scanner_consortium"
const FLAG_LUCIOLE: StringName = &"scanner_luciole"
const FLAG_LUCIOLE_REMOVED: StringName = &"scanner_luciole_removed"


## Source branchée d'après les drapeaux (`acv`, `luciole`), vide sinon.
## Acte III (J21, rappel de Continuité) : ACV-2 restitué, plus de liens Consortium.
const FLAG_ACV_RETURNED: StringName = &"acv_returned"


static func source_for(flags: Dictionary[StringName, Variant]) -> StringName:
	# Acte III : l'ACV-2 de la Commission est restitué au rappel du J21.
	if FlagCondition.is_flag_true(flags, FLAG_CONSORTIUM) and not FlagCondition.is_flag_true(flags, FLAG_ACV_RETURNED):
		return SOURCE_ACV
	if FlagCondition.is_flag_true(flags, FLAG_LUCIOLE) and not FlagCondition.is_flag_true(flags, FLAG_LUCIOLE_REMOVED):
		return SOURCE_LUCIOLE
	return &""


## Liens suggérés (discordances « date ↔ date du jour » déjà calculées).
static func suggestions(case: Case, ctx: RuleContext) -> Array[Discrepancy]:
	var links: Array[Discrepancy] = []
	if case == null or ctx == null:
		return links
	var dated: Array[FieldRef] = case.find_refs_by_truth_path(DiscrepancyChecker.EXPIRY_PATH)
	dated.append_array(case.find_refs_by_truth_path(DiscrepancyChecker.FIRMWARE_PATH))
	for ref: FieldRef in dated:
		var check: Discrepancy = DiscrepancyChecker.check(case, ref, FieldRef.today(), ctx)
		if check.confirmed:
			links.append(check)
	return links
