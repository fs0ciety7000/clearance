## Outil d'équilibrage du foyer (GDD §5.3, §5.4, §14) — headless.
##
## Simule la campagne (J1 → dernier jour des données) pour plusieurs profils de
## joueur (précision de verdict) et une politique de dépenses, sur N graines, et
## imprime par profil et par soir : revenu net, solde, postes non payés, état du
## foyer, taux de « foyer entièrement malade » et de fins anticipées.
##
## M7 : campagne J1–J10 (soirées à événements, audit, fin F1–F7) ; par profil,
## répartition des fins (et jour moyen d'une fin anticipée). `--presets=`
## liste de `SimProfile.PRESETS` (défaut : `default`, choix sans UI) ;
## `--days=N` limite la campagne aux N premiers jours.
## M8 : campagne J1–J20 (pivot du J10, quota, rations, prélèvements, Revue du
## J17, fins F1–F9 de D-078) ; profils Acte II `drift10`, `archiviste`,
## `solidaire`, `overrun`, `mercenary2` (docs/ACT2.md §6).
## M9 : campagne J1–J30 (pivot du J20, Acte III, fins F1–F10 de D-088) ;
## profils `passeur`, `temoin`, `accusateur`, `mercenary3` (docs/ACT3.md §6.5) ;
## `--climate=vanne|brulants|vitres|registre|promu|statu_quo` démarre au J21
## depuis un état synthétique de ce climat (solde selon la précision).
## M11 : `--story` joue chaque préréglage en mode Récit (D-102 : amendes à
## 0 ₵) ; équivalent à `--presets=story_<nom>` (`SimProfile.STORY_PREFIX`).
## M12 (docs/M12.md §6) : `--garde` joue des gardes de nuit (bots constants de
## `--profiles=`, `--decay` : bot dégressif) sur `--seeds` codes libres tirés
## de `--seed`, `--daily=N` : N graines du jour consécutives (UTC) ; médiane,
## p10, p90, directives, paliers, cas sans preuve. `--events=on|off|compare`
## (campagne) : calendrier des événements de station appliqué (B58) ;
## `compare` joue chaque graine avec et sans événements et imprime l'écart de
## répartition des fins (D-060 : ≤ 3 points) et de solde les jours
## d'événement.
##
## Usage (depuis la racine du projet) :
##   godot --headless --script res://tools/balance_sim.gd -- --seeds=200 --seed=1 \
##       --profiles=0.6,0.8,0.95 --spending=reasoned|default [--set=heating=6,starting_credits=10] \
##       [--presets=default,loyal,luciole,mercenary,drift,negligent,archiviste,solidaire] [--days=30] \
##       [--climate=vanne] [--story]
## `--set` surcharge en mémoire des champs de l'`EconomyDef` (essais sans
## régénérer les données ; les valeurs retenues vont dans `build_data.gd`).
extends SceneTree

var _seeds: int = 200
var _seed: int = 1
var _profiles: Array[float] = [0.6, 0.8, 0.95]
var _spending: BalanceSimulator.Spending = BalanceSimulator.Spending.REASONED
var _overrides: Dictionary[String, String] = {}
var _presets: Array[StringName] = [&"default"]
var _days: int = -1
## Acte III : climat d'entrée synthétique (vide : campagne depuis le J1).
var _climate: String = ""
## M11 : préréglages joués en mode Récit (`--story`).
var _story: bool = false
## M12 : gardes de nuit (`--garde`), bot dégressif (`--decay`), graines du jour (`--daily=N`).
var _garde: bool = false
var _decay: bool = false
var _daily: int = 0
## M12 : événements de station en campagne (`--events=on|off|compare`).
var _events: String = "on"

## État synthétique du J21 par climat : drapeaux et jauges (docs/ACT3.md §1.3).
const CLIMATES: Dictionary[String, Dictionary] = {
	"vanne": {"climate_vanne": true, "lucioles_trust": 6, "loyalty": 1, "suspicion": 2, "solidarite": 2, "registre": 1},
	"brulants": {"climate_vanne": true, "vanne2_brulants": true, "lucioles_trust": 5, "loyalty": 0, "suspicion": 3,
			"solidarite": 1, "registre": 1},
	"vitres": {"climate_vitres": true, "lucioles_trust": 3, "loyalty": 1, "suspicion": 1, "solidarite": 4, "registre": 1},
	"registre": {"climate_registre": true, "lucioles_trust": 2, "loyalty": 1, "suspicion": 1, "solidarite": 2, "registre": 3,
			"verite": 1},
	"promu": {"climate_promu": true, "lucioles_trust": -4, "loyalty": 7, "suspicion": 1, "solidarite": -2, "registre": 0},
	"statu_quo": {"climate_statu_quo": true, "lucioles_trust": 1, "loyalty": 2, "suspicion": 2, "solidarite": 1, "registre": 1},
}


func _init() -> void:
	_parse_args()
	var data: DataCatalog = DataCatalog.load_from()
	if not data.errors.is_empty():
		push_error("balance_sim: données invalides %s" % [data.errors])
		quit(1)
		return
	var e: EconomyDef = data.get_economy()
	for field: String in _overrides:
		if not field in e:
			push_error("balance_sim: champ inconnu %s" % field)
			quit(1)
			return
		var current: Variant = e.get(field)
		e.set(field, _overrides[field].to_float() if current is float else _overrides[field].to_int())
	print("balance_sim : %d graine(s), base %d, dépenses %s" % [_seeds, _seed,
			BalanceSimulator.Spending.keys()[_spending]])
	print("barème : départ %d ₵, loyer %d, air %d, nourriture %d, chauffage %d, O₂ %d, soins %d/proche ; Noa froid %.2f ; privation %d soirs ; aggravation %d soirs" % [
			e.starting_credits, e.rent, e.air_tax, e.food, e.heating, e.oxygen, e.medicine_per_member,
			e.noa_cold_sick_chance, e.deprivation_sick_evenings, e.untreated_worsen_evenings])
	var start: int = Time.get_ticks_msec()
	if _garde:
		_run_garde(data)
		print("Durée : %d ms" % (Time.get_ticks_msec() - start))
		quit(0)
		return
	if _events == "compare":
		for preset: StringName in _presets:
			for accuracy: float in _profiles:
				_compare_events(data, accuracy, preset)
		print("Durée : %d ms" % (Time.get_ticks_msec() - start))
		quit(0)
		return
	if _story:
		for i: int in _presets.size():
			if not String(_presets[i]).begins_with(SimProfile.STORY_PREFIX):
				_presets[i] = StringName(SimProfile.STORY_PREFIX + String(_presets[i]))
	for preset: StringName in _presets:
		for accuracy: float in _profiles:
			_run_profile(data, accuracy, preset)
	print("Durée : %d ms" % (Time.get_ticks_msec() - start))
	quit(0)


func _parse_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			_seeds = maxi(arg.trim_prefix("--seeds=").to_int(), 1)
		elif arg.begins_with("--seed="):
			_seed = arg.trim_prefix("--seed=").to_int()
		elif arg.begins_with("--profiles="):
			_profiles.clear()
			for part: String in arg.trim_prefix("--profiles=").split(",", false):
				_profiles.append(clampf(part.to_float(), 0.0, 1.0))
		elif arg.begins_with("--set="):
			for pair: String in arg.trim_prefix("--set=").split(",", false):
				var kv: PackedStringArray = pair.split("=")
				if kv.size() == 2:
					_overrides[kv[0].strip_edges()] = kv[1].strip_edges()
		elif arg.begins_with("--presets="):
			_presets.clear()
			for part: String in arg.trim_prefix("--presets=").split(",", false):
				_presets.append(StringName(part.strip_edges()))
		elif arg.begins_with("--days="):
			_days = arg.trim_prefix("--days=").to_int()
		elif arg.begins_with("--climate="):
			_climate = arg.trim_prefix("--climate=")
			if not CLIMATES.has(_climate):
				push_error("balance_sim: climat inconnu %s (%s)" % [_climate, ", ".join(CLIMATES.keys())])
				_climate = ""
		elif arg == "--story":
			_story = true
		elif arg == "--garde":
			_garde = true
		elif arg == "--decay":
			_decay = true
		elif arg.begins_with("--daily="):
			_daily = maxi(arg.trim_prefix("--daily=").to_int(), 0)
		elif arg.begins_with("--events="):
			_events = arg.trim_prefix("--events=")
		elif arg == "--spending=default":
			_spending = BalanceSimulator.Spending.DEFAULT


func _run_profile(data: DataCatalog, accuracy: float, preset: StringName = &"default") -> void:
	var last: int = _days if _days >= 1 else data.get_last_day_number()
	var ending_counts: Dictionary[String, int] = {}
	var ending_days: Dictionary[String, int] = {}
	# Agrégats par jour (index 0 = J1).
	var reached: Array[int] = []
	var acc: Array[float] = []
	var income: Array[int] = []
	var balance: Array[int] = []
	var sick: Array[int] = []
	var grave: Array[int] = []
	var lost: Array[int] = []
	var all_sick: Array[int] = []
	var any_sick: Array[int] = []
	var endings: Array[int] = []
	var sacrificed: Array[int] = []
	var unpaid: Array[Dictionary] = []
	for i: int in last:
		for arr: Array in [reached, income, balance, sick, grave, lost, all_sick, any_sick, endings, sacrificed]:
			arr.append(0)
		acc.append(0.0)
		var d: Dictionary[StringName, int] = {}
		for id: StringName in BalanceSimulator.TRACKED_LINES:
			d[id] = 0
		unpaid.append(d)
	var finished: int = 0
	for n: int in _seeds:
		var rows: Array[Dictionary] = []
		if _climate.is_empty():
			var profile: SimProfile = SimProfile.preset(preset, accuracy)
			profile.station_events = _events == "on"
			rows = BalanceSimulator.run_campaign(data, SeededRng.mix(_seed, n), accuracy, _spending, last, profile)
		else:
			rows = BalanceSimulator.run_campaign_from(data, SeededRng.mix(_seed, n), accuracy, _spending, last,
					SimProfile.preset(preset, accuracy), _climate_start(accuracy))
		var tail: Dictionary = rows[rows.size() - 1]
		var ending_name: String = str(tail["ending"]) if str(tail["ending"]) != "" else "—"
		ending_counts[ending_name] = ending_counts.get(ending_name, 0) + 1
		ending_days[ending_name] = ending_days.get(ending_name, 0) + SaveService.as_int(tail["day"])
		for row: Dictionary in rows:
			var i: int = SaveService.as_int(row["day"]) - 1
			reached[i] += 1
			var row_accuracy: float = row["accuracy"]
			acc[i] += row_accuracy
			income[i] += SaveService.as_int(row["income"])
			balance[i] += SaveService.as_int(row["balance_after"])
			sick[i] += SaveService.as_int(row["sick"])
			grave[i] += SaveService.as_int(row["grave"])
			lost[i] += SaveService.as_int(row["lost"])
			if row["all_sick"]:
				all_sick[i] += 1
			if SaveService.as_int(row["sick"]) + SaveService.as_int(row["grave"]) + SaveService.as_int(row["lost"]) > 0:
				any_sick[i] += 1
			if row["ending"] != EveningReport.ENDING_NONE:
				endings[i] += 1
			var u: Dictionary = row["unpaid"]
			var any_unpaid: bool = false
			for id: StringName in BalanceSimulator.TRACKED_LINES:
				if SaveService.as_int(u[id]) > 0:
					unpaid[i][id] += 1
					any_unpaid = true
			if any_unpaid:
				sacrificed[i] += 1
		if SaveService.as_int(tail["day"]) == last and (rows[rows.size() - 1]["ending"] == EveningReport.ENDING_NONE or rows[rows.size() - 1].get("final", false)):
			finished += 1
	print("")
	print("== Profil %d %% · %s ==" % [roundi(accuracy * 100.0), preset])
	print("jour | précis. | revenu | solde | ≥1 poste sacrifié | impayés % (loyer/nourr./chauff./O₂/soins) | malades | graves | perdus | ≥1 malade | foyer entièrement malade | fin anticipée (cumul)")
	var cumulative: int = 0
	for i: int in last:
		var r: int = maxi(reached[i], 1)
		cumulative += endings[i]
		var parts: PackedStringArray = []
		for id: StringName in BalanceSimulator.TRACKED_LINES:
			var missed: int = SaveService.as_int(unpaid[i][id])
			parts.append("%3d" % roundi(100.0 * missed / r))
		print("J%d   | %5.1f %% | %6.1f | %5.1f | %5.1f %% | %s | %7.2f | %6.2f | %6.2f | %7.1f %% | %6.1f %% | %5.1f %%" % [
				i + 1, 100.0 * acc[i] / r, float(income[i]) / r, float(balance[i]) / r, 100.0 * sacrificed[i] / r, " / ".join(parts),
				float(sick[i]) / r, float(grave[i]) / r, float(lost[i]) / r, 100.0 * any_sick[i] / r,
				100.0 * all_sick[i] / r, 100.0 * cumulative / _seeds])
	print("campagnes menées au bout : %.1f %%" % (100.0 * finished / _seeds))
	var names: Array[String] = []
	names.assign(ending_counts.keys())
	names.sort()
	var ending_parts: PackedStringArray = []
	for ending_name: String in names:
		ending_parts.append("%s %.1f %% (J%.1f)" % [ending_name, 100.0 * ending_counts[ending_name] / _seeds,
				float(ending_days[ending_name]) / ending_counts[ending_name]])
	print("fins : " + " · ".join(ending_parts))


## Acte III : état synthétique du soir du J20 (climat `_climate`) : solde de
## docs/ACT3.md §6.3 selon la précision, drapeaux d'acte, jauges du climat.
func _climate_start(accuracy: float) -> Dictionary:
	var flags: Dictionary = {"act2_started": true, EndingService.FLAG_ACT3: true, "pivot3_done": true}
	var climate: Dictionary = CLIMATES[_climate]
	for key: String in climate:
		flags[key] = climate[key]
	var credits: int = 40 if accuracy < 0.7 else (200 if accuracy < 0.9 else 380)
	var processed: int = 300
	return {"day": 21, "credits": credits, "flags": flags, "household": Household.new(), "processed": processed,
			"correct": roundi(processed * accuracy)}



# ---------------------------------------------------------------------------
# M12 : Garde de nuit (`--garde`) et événements de station (`--events=compare`)
# ---------------------------------------------------------------------------

## Codes des gardes simulées : codes libres tirés de `--seed`, ou `--daily=N`
## graines du jour consécutives à partir du 29.10.2026 (UTC).
func _garde_codes() -> PackedStringArray:
	var codes: PackedStringArray = []
	if _daily > 0:
		var base: int = Time.get_unix_time_from_datetime_string("2026-10-29T12:00:00")
		for d: int in _daily:
			codes.append(GardeService.daily_code(base + d * 86400))
		return codes
	for n: int in _seeds:
		codes.append(GardeService.code_from_bits(SeededRng.mix(_seed, n)))
	return codes


func _run_garde(data: DataCatalog) -> void:
	var codes: PackedStringArray = _garde_codes()
	var profiles: Array[SimProfile] = []
	if _decay:
		profiles.append(SimProfile.garde_decaying())
	else:
		for accuracy: float in _profiles:
			profiles.append(SimProfile.preset(&"default", accuracy))
	print("garde : %d code(s)%s" % [codes.size(), " (graines du jour)" if _daily > 0 else ""])
	for profile: SimProfile in profiles:
		var scores: Array[int] = []
		var directives: Array[int] = []
		var paliers: Dictionary[int, int] = {}
		var events: int = 0
		var insoluble: int = 0
		var passengers: int = 0
		var exercised: int = 0
		var windows: int = 0
		for i: int in codes.size():
			var r: Dictionary = BalanceSimulator.run_garde(data, codes[i], profile, i)
			scores.append(int(r["score"]))
			directives.append(int(r["directives"]))
			paliers[int(r["palier"])] = paliers.get(int(r["palier"]), 0) + 1
			events += int(r["events"])
			insoluble += int(r["violations_without_evidence"])
			passengers += int(r["passengers"])
			var ex: Dictionary = r["exercised"]
			for k: Variant in ex:
				windows += 1
				if ex[k]:
					exercised += 1
		var label: String = "dégressif" if profile.garde_decay else "%d %%" % roundi(profile.accuracy * 100.0)
		print("== Garde · bot %s ==" % label)
		print("score : médiane %.1f · moyenne %.1f · p10 %d · p90 %d · max %d" % [_percentile(scores, 0.5), _mean(scores),
				roundi(_percentile(scores, 0.1)), roundi(_percentile(scores, 0.9)), scores.max()])
		print("directives vues : médiane %.1f · ≥ 1 : %.1f %% · ≥ 4 : %.1f %%" % [_percentile(directives, 0.5),
				100.0 * _count_at_least(directives, 1) / codes.size(), 100.0 * _count_at_least(directives, 4) / codes.size()])
		print("paliers atteints : %s · événements : %.2f par garde" % [paliers, float(events) / codes.size()])
		print("passagers : %d · cas sans preuve citable : %d · directives exercées : %d / %d" % [passengers, insoluble,
				exercised, windows])


## Campagne avec et sans événements de station sur les mêmes graines :
## répartition des fins, écart par fin (D-060 : ≤ 3 points), nombre
## d'événements par campagne, écart de solde les jours d'événement.
func _compare_events(data: DataCatalog, accuracy: float, preset: StringName) -> void:
	var last: int = _days if _days >= 1 else data.get_last_day_number()
	var with_events: Dictionary[String, int] = {}
	var without: Dictionary[String, int] = {}
	var per_campaign: Array[int] = []
	var delta_sum: float = 0.0
	var delta_days: int = 0
	var types: Dictionary[String, int] = {}
	for n: int in _seeds:
		var campaign_seed: int = SeededRng.mix(_seed, n)
		var plain_profile: SimProfile = SimProfile.preset(preset, accuracy)
		var rows_plain: Array[Dictionary] = BalanceSimulator.run_campaign(data, campaign_seed, accuracy, _spending, last,
				plain_profile)
		var event_profile: SimProfile = SimProfile.preset(preset, accuracy)
		event_profile.station_events = true
		var rows_events: Array[Dictionary] = BalanceSimulator.run_campaign(data, campaign_seed, accuracy, _spending, last,
				event_profile)
		var a: String = str(rows_plain[rows_plain.size() - 1]["ending"])
		var b: String = str(rows_events[rows_events.size() - 1]["ending"])
		without[a] = without.get(a, 0) + 1
		with_events[b] = with_events.get(b, 0) + 1
		var schedule: Dictionary = BalanceSimulator.event_schedule(data, campaign_seed)
		per_campaign.append(schedule.size())
		for day_number: Variant in schedule:
			var plan: StationEventPlan = schedule[day_number]
			types[String(plan.event.id)] = types.get(String(plan.event.id), 0) + 1
			for row: Dictionary in rows_events:
				if int(row["day"]) == int(day_number):
					for plain_row: Dictionary in rows_plain:
						if int(plain_row["day"]) == int(day_number):
							delta_sum += float(int(row["income"]) - int(plain_row["income"]))
							delta_days += 1
	print("")
	print("== Événements · profil %d %% · %s ==" % [roundi(accuracy * 100.0), preset])
	var names: Array[String] = []
	for key: String in with_events:
		if not names.has(key):
			names.append(key)
	for key: String in without:
		if not names.has(key):
			names.append(key)
	names.sort()
	var worst: float = 0.0
	var parts: PackedStringArray = []
	for ending_name: String in names:
		var p_with: float = 100.0 * with_events.get(ending_name, 0) / _seeds
		var p_without: float = 100.0 * without.get(ending_name, 0) / _seeds
		worst = maxf(worst, absf(p_with - p_without))
		parts.append("%s %.1f → %.1f" % [ending_name if ending_name != "" else "—", p_without, p_with])
	print("fins (sans → avec) : " + " · ".join(parts))
	print("écart maximal : %.1f point(s) (D-060 : ≤ 3)" % worst)
	var in_range: int = 0
	for count: int in per_campaign:
		if count >= 3 and count <= 6:
			in_range += 1
	print("événements par campagne : moyenne %.2f · 3 à 6 : %.1f %% · types %s" % [_mean(per_campaign),
			100.0 * in_range / maxi(per_campaign.size(), 1), types])
	print("revenu un jour d'événement : écart moyen %.2f ₵ (sur %d jours)" % [delta_sum / maxi(delta_days, 1), delta_days])


static func _percentile(values: Array[int], q: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array[int] = values.duplicate()
	sorted.sort()
	var pos: float = q * (sorted.size() - 1)
	var lo: int = floori(pos)
	var hi: int = mini(lo + 1, sorted.size() - 1)
	return lerpf(float(sorted[lo]), float(sorted[hi]), pos - lo)


static func _mean(values: Array[int]) -> float:
	if values.is_empty():
		return 0.0
	var total: int = 0
	for v: int in values:
		total += v
	return float(total) / values.size()


static func _count_at_least(values: Array[int], minimum: int) -> int:
	var count: int = 0
	for v: int in values:
		if v >= minimum:
			count += 1
	return count
