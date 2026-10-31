## Passe QA M14 (docs/QA.md §17) — REVOIR (Dossier) ↔ séquence vue en partie.
## Pour chaque fin et variante d'`EpilogueService` (drapeaux réels qui la
## produisent), compare les planches et légendes de la séquence jouée en fin
## de partie (`DayScene.make_end_cinematic` : drapeaux de la partie) à celles
## de REVOIR (`DossierScreen.replays_for` + `play_replay` : drapeaux vides,
## variante et acte du profil), et à celles de la capture de debug
## (`--cinematic=<id>` : `DayScene.ctx_variant_flags`).
##   godot --headless --script res://tools/qa_boot.gd -- --qa-node=res://tests/qa_drivers/qa_m14_replay_scan.gd
## Sorties : QA14R_CASE, QA14R_DIFF, QA14R_SUMMARY.
extends Node

const CASES: Array = [
	# [fin, acte, jour, drapeaux réels]
	["f1_arrested", 1, 9, {"audit_arrested": true}],
	["f1_arrested", 2, 17, {"act2_started": true, "review_arrested": true}],
	["f1_arrested", 3, 29, {"act2_started": true, "act3_started": true, "deposition_arrested": true}],
	["f1_arrested", 3, 30, {"act2_started": true, "act3_started": true}],
	["f2_reassigned", 1, 10, {}],
	["f2_reassigned", 3, 30, {"act2_started": true, "act3_started": true}],
	["f3_family_lost", 2, 20, {"act2_started": true}],
	["f3_family_lost", 3, 30, {"act2_started": true, "act3_started": true, "lumika_learned": true}],
	["f4_glory", 3, 30, {"act2_started": true, "act3_started": true}],
	["f4_glory", 3, 30, {"act2_started": true, "act3_started": true, "final3_dora": true}],
	["f5_air", 3, 30, {"act2_started": true, "act3_started": true, "climate_vanne": true}],
	["f5_air", 3, 30, {"act2_started": true, "act3_started": true}],
	["f5_air", 3, 30, {"act2_started": true, "act3_started": true, "vanne2_brulants": true}],
	["f6_drift", 1, 10, {}],
	["f6_drift", 2, 20, {"act2_started": true}],
	["f6_drift", 3, 30, {"act2_started": true, "act3_started": true, "exit3_drift": true}],
	["f6_drift", 3, 30, {"act2_started": true, "act3_started": true}],
	["f7_reopens", 3, 30, {"act2_started": true, "act3_started": true}],
	["f8_registre", 3, 30, {"act2_started": true, "act3_started": true}],
	["f9_strike", 3, 30, {"act2_started": true, "act3_started": true}],
	["f10_pont", 3, 30, {"act2_started": true, "act3_started": true}],
]


func _ready() -> void:
	_run.call_deferred()


static func _typed(d: Dictionary) -> Dictionary[StringName, Variant]:
	var out: Dictionary[StringName, Variant] = {}
	for k: Variant in d:
		out[StringName(str(k))] = d[k]
	return out


static func _sequence(def: CinematicDef, ctx: Dictionary[StringName, Variant], act: int) -> PackedStringArray:
	var out: PackedStringArray = []
	if def == null:
		return out
	for plate: PlateDef in CinematicService.plates_for(def, ctx, act, {}):
		out.append("%s:%s" % [plate.id, CinematicService.caption_key(plate, ctx)])
	return out


func _run() -> void:
	var diffs: int = 0
	var debug_diffs: int = 0
	for c: Array in CASES:
		var ending: StringName = StringName(c[0])
		var act: int = c[1]
		var day: int = c[2]
		var flags: Dictionary[StringName, Variant] = _typed(c[3])
		var variant: StringName = EpilogueService.variant_of(ending, flags)
		var def: CinematicDef = CinematicService.select(ending, variant, flags, act, day)
		if def == null:
			print("QA14R_CASE %s act=%d variant=%s → aucune séquence" % [ending, act, variant])
			continue
		var real: PackedStringArray = _sequence(def, CinematicService.context_flags(flags, act, variant, day), act)
		# REVOIR : profil {id, variant, act}, drapeaux vides (DossierScreen).
		var empty: Dictionary[StringName, Variant] = {}
		var replay_def: CinematicDef = CinematicService.select(ending, variant, empty, act)
		var replay: PackedStringArray = _sequence(replay_def, CinematicService.context_flags(empty, act, variant), act)
		# Capture de debug `--cinematic=<id>` : drapeaux d'acte + ctx_variant_flags (F1 seulement).
		var dbg_flags: Dictionary[StringName, Variant] = {&"act2_started": act >= 2, &"act3_started": act >= 3}
		var saved: Dictionary[StringName, Variant] = GameState.narrative_flags.duplicate()
		GameState.narrative_flags = dbg_flags
		if not def.ending_variants.is_empty():
			DayScene.ctx_variant_flags(ending, def.ending_variants[0])
		dbg_flags = GameState.narrative_flags.duplicate()
		GameState.narrative_flags = saved
		var dbg_variant: StringName = EpilogueService.variant_of(ending, dbg_flags)
		var dbg_def: CinematicDef = CinematicService.select(ending, dbg_variant, dbg_flags, act, 30)
		print("QA14R_CASE %s act=%d variant=%s id=%s real=%s" % [ending, act, variant, def.id, ",".join(real)])
		if replay_def == null or replay_def.id != def.id or replay != real:
			diffs += 1
			print("QA14R_DIFF revoir %s/%s : %s ≠ %s" % [ending, variant, ",".join(replay) if replay_def != null else "(aucune)", ",".join(real)])
		if dbg_def == null or dbg_def.id != def.id:
			debug_diffs += 1
			print("QA14R_DIFF debug --cinematic=%s → %s" % [def.id, dbg_def.id if dbg_def != null else "(aucune)"])
	print("QA14R_SUMMARY cases=%d revoir_diffs=%d debug_diffs=%d" % [CASES.size(), diffs, debug_diffs])
	get_tree().quit(0)
