## Outil de stats du générateur (ARCHITECTURE §13 R5, jalon M3).
##
## Génère N campagnes × jours × passagers et imprime, par jour : distribution
## du nombre d'anomalies et des types (observé vs poids du `DayDef`), verdicts
## attendus, visière, bruit légitime, re-tirages, invariants, et l'anti-
## répétition des apparences (replis, paires trop proches dans la fenêtre).
##
## Usage (depuis la racine du projet) :
##   godot --headless --script res://tools/build_data.gd   # si les données ont changé
##   godot --headless --script res://tools/gen_stats.gd -- --campaigns=200 --seed=1
##   godot --headless --script res://tools/gen_stats.gd -- --campaigns=40 --days=21-30   # Acte III seul
## M13 (docs/M13.md §4.1) : par jour, passagers **générés** porteurs d'une
## fausse déclaration, d'une anomalie de fouille (25–27), armes, innocents
## avec indice, P(porteur | indice), réponses évasives des innocents.
extends SceneTree

var _campaigns: int = 200
var _seed: int = 1
## Jours mesurés (`--days=A-B` ou `--days=N`) ; tous par défaut.
var _first_day: int = 1
var _last_day: int = 999


func _init() -> void:
	_parse_args()
	var data: DataCatalog = DataCatalog.load_from()
	if not data.errors.is_empty():
		push_error("gen_stats: données invalides %s" % [data.errors])
		quit(1)
		return
	var start: int = Time.get_ticks_msec()
	var failures: int = 0
	var day_numbers: Array[int] = []
	day_numbers.assign(data.days.keys())
	day_numbers.sort()
	print("gen_stats : %d campagne(s), graine %d, jours %s" % [_campaigns, _seed, day_numbers])
	for n: int in day_numbers:
		if n >= _first_day and n <= _last_day:
			failures += _run_day(data, data.days[n])
	print("Durée : %d ms" % (Time.get_ticks_msec() - start))
	quit(1 if failures > 0 else 0)


func _parse_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--campaigns="):
			_campaigns = maxi(arg.trim_prefix("--campaigns=").to_int(), 1)
		elif arg.begins_with("--seed="):
			_seed = arg.trim_prefix("--seed=").to_int()
		elif arg.begins_with("--days="):
			var span: PackedStringArray = arg.trim_prefix("--days=").split("-")
			_first_day = span[0].to_int()
			_last_day = span[span.size() - 1].to_int()


func _run_day(data: DataCatalog, day: DayDef) -> int:
	var cases: int = 0
	var count_hist: Array[int] = [0, 0, 0, 0, 0]
	var kinds: Dictionary[String, int] = {}
	var verdicts: Dictionary[String, int] = {}
	var rules: Dictionary[String, int] = {}
	var visor: int = 0
	var noise: int = 0
	var retries: int = 0
	var shortfall: int = 0
	var invariant_errors: int = 0
	var fallbacks: int = 0
	var pairs: int = 0
	var close_pairs: int = 0
	var exact_dupes: int = 0
	var distance_sum: int = 0
	# M13 (§4.1) : passagers générés seulement.
	var generated_count: int = 0
	var lies: int = 0
	var search_carriers: int = 0
	var weapons: int = 0
	var innocents: int = 0
	var innocent_cues: int = 0
	var cued: int = 0
	var cued_carriers: int = 0
	var evasive_innocents: int = 0
	var catalog: AppearanceCatalog = data.appearance_catalog
	var slots: Array[StringName] = catalog.get_slot_ids()
	for campaign: int in _campaigns:
		var day_seed: int = SeededRng.day_seed(SeededRng.mix(_seed, campaign), day.day_number)
		var builder: CaseBuilder = CaseBuilder.new(data, day, day_seed)
		fallbacks += builder.roster.get_fallback_count()
		var entries: Array[AppearanceRoster.Entry] = builder.roster.entries
		for i: int in entries.size():
			for j: int in range(maxi(i - catalog.window_size, 0), i):
				var d: int = entries[i].appearance.distance(entries[j].appearance, slots)
				pairs += 1
				distance_sum += d
				if d < catalog.min_distance:
					close_pairs += 1
				if d == 0:
					exact_dupes += 1
		for generated: GeneratedCase in builder.build_day():
			cases += 1
			var anomalies: int = generated.key.anomalies.size()
			count_hist[mini(anomalies, 4)] += 1
			shortfall += generated.requested_anomalies - anomalies
			for kind: AnomalyType.Kind in generated.get_anomaly_kinds():
				_inc(kinds, AnomalyType.name_of(kind))
			_inc(verdicts, str(VerdictKind.Kind.find_key(generated.key.expected_verdict)))
			for rule_id: StringName in generated.key.get_violated_rule_ids():
				_inc(rules, String(rule_id))
			visor += int(generated.visor_down)
			noise += int(generated.photo_noise)
			retries += generated.clean_attempts - 1
			invariant_errors += generated.invariant_errors.size()
			if generated.scripted_id == &"":
				generated_count += 1
				var m13_kinds: Array[AnomalyType.Kind] = generated.get_anomaly_kinds()
				lies += int(m13_kinds.has(AnomalyType.Kind.STATEMENT_MISMATCH))
				weapons += int(m13_kinds.has(AnomalyType.Kind.CONCEALED_WEAPON))
				var carrier: bool = m13_kinds.has(AnomalyType.Kind.CONTRABAND) or m13_kinds.has(AnomalyType.Kind.CONCEALED_IMPLANT) \
						or m13_kinds.has(AnomalyType.Kind.CONCEALED_WEAPON)
				search_carriers += int(carrier)
				var has_cue: bool = not generated.case.search_cues.is_empty()
				cued += int(has_cue)
				cued_carriers += int(has_cue and carrier)
				if not carrier and generated.case.search_layout != null:
					innocents += 1
					innocent_cues += int(has_cue)
					evasive_innocents += int(generated.case.cargo_reply == Case.CARGO_EVASIVE)

	print("\n=== J%d (%d passagers × %d campagnes = %d cas) ===" % [day.day_number, day.passenger_count, _campaigns, cases])
	var hist: PackedStringArray = []
	for k: int in 4:
		var targets: PackedFloat32Array = day.anomaly_count_targets if day.anomaly_count_targets.size() == 4 \
				else day.anomaly_count_weights
		hist.append("%d:%s (cible %s)" % [k, _pct(count_hist[k], cases), _pct_f(targets[k])])
	print("Anomalies/cas  : " + " · ".join(hist) + " — scénarisés inclus")
	var weight_total: float = 0.0
	for kind: AnomalyType.Kind in day.anomaly_weights:
		weight_total += day.anomaly_weights[kind]
	var total_anomalies: int = 0
	for key: String in kinds:
		total_anomalies += kinds[key]
	print("Types          :")
	var names: Array[String] = []
	names.assign(kinds.keys())
	names.sort()
	for name: String in names:
		var target: String = "—"
		for kind: AnomalyType.Kind in day.anomaly_weights:
			if AnomalyType.name_of(kind) == name:
				target = _pct_f(day.anomaly_weights[kind] / weight_total)
		print("  %-20s %5d  %s (poids %s)" % [name, kinds[name], _pct(kinds[name], total_anomalies), target])
	print("Verdicts       : %s" % _table(verdicts, cases))
	print("Règles violées : %s" % _table(rules, cases))
	print("Visière        : %s · bruit photo : %s · re-tirages propres : %d · anomalies non placées : %d"
			% [_pct(visor, cases), _pct(noise, cases), retries, shortfall])
	print("Apparences     : replis %s · paires < min_distance (fenêtre %d) %d/%d (%s) · doublons exacts %d · distance moyenne %.2f/%d"
			% [_pct(fallbacks, cases), catalog.window_size, close_pairs, pairs, _pct(close_pairs, pairs), exact_dupes,
			float(distance_sum) / maxf(pairs, 1.0), slots.size()])
	print("M13 (générés)  : fausses déclarations %s · fouille (25–27) %s · armes %.2f/jour · indices des innocents %s · P(porteur | indice) %s · évasives des innocents %s"
			% [_pct(lies, generated_count), _pct(search_carriers, generated_count), float(weapons) / _campaigns,
			_pct(innocent_cues, innocents), _pct(cued_carriers, cued), _pct(evasive_innocents, innocents)])
	print("Invariants     : %s" % ("OK" if invariant_errors == 0 else "%d ERREUR(S)" % invariant_errors))
	return invariant_errors


func _inc(table: Dictionary[String, int], key: String) -> void:
	table[key] = table.get(key, 0) + 1


func _table(table: Dictionary[String, int], total: int) -> String:
	var keys: Array[String] = []
	keys.assign(table.keys())
	keys.sort()
	var parts: PackedStringArray = []
	for key: String in keys:
		parts.append("%s %s" % [key, _pct(table[key], total)])
	return " · ".join(parts)


func _pct(value: int, total: int) -> String:
	return "%.1f %%" % (100.0 * value / maxf(total, 1.0))


func _pct_f(ratio: float) -> String:
	return "%.1f %%" % (100.0 * ratio)
