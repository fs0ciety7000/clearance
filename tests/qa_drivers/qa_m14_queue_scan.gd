## Passe QA M14 (docs/QA.md §17) — file réelle ↔ passager à la vitre, hors scène.
## Pour chaque jour J1 → J30 et chaque graine, construit la journée
## (`CaseBuilder`, comme le `DayController`), puis compare la silhouette de la
## file (`QueueSilhouette.upcoming(roster…)`, ce que montre le Hall) à la
## silhouette du passager **réellement présenté** (`case.passenger_presented`),
## en séparant les passagers en règle (verdict attendu APPROUVÉ, aucune
## anomalie) et les autres. Un écart corrélé aux anomalies serait une fuite
## d'information (la file annoncerait un passager « différent » de celui qui
## se présente seulement quand il triche).
##   godot --headless --script res://tools/qa_boot.gd -- --qa-node=res://tests/qa_drivers/qa_m14_queue_scan.gd --seeds=6
## Sorties : QA14Q_DIFF (premiers écarts), QA14Q_SUMMARY.
extends Node

var _seeds: int = 6


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			_seeds = arg.trim_prefix("--seeds=").to_int()
	_run.call_deferred()


func _run() -> void:
	var data: DataCatalog = DataCatalog.load_from()
	var n: Dictionary = {"clean": 0, "anom": 0}
	var diff: Dictionary = {"clean": {}, "anom": {}}
	var shown: int = 0
	for seed: int in range(1, _seeds + 1):
		for day_n: int in range(1, 31):
			var day: DayDef = data.get_day(day_n).duplicate(true)
			var builder: CaseBuilder = CaseBuilder.new(data, day, SeededRng.mix(seed * 7919, day_n))
			var queue: Array[QueueSilhouette] = QueueSilhouette.upcoming(builder.roster, 0, day.passenger_count,
					QueueSilhouette.MAX_UPCOMING * 4)
			for s: QueueSilhouette in queue:
				var g: GeneratedCase = builder.build(s.index)
				if g == null or g.case == null:
					continue
				var bucket: String = "clean" if g.key.anomalies.is_empty() \
						and g.key.expected_verdict == VerdictKind.Kind.APPROVE else "anom"
				n[bucket] += 1
				var seen: QueueSilhouette = QueueSilhouette.from_appearance(s.index, g.case.passenger_presented.appearance)
				for field: String in ["palette_index", "shape", "height_step"]:
					if seen.get(field) != s.get(field):
						var d: Dictionary = diff[bucket]
						d[field] = int(d.get(field, 0)) + 1
						if shown < 12:
							shown += 1
							var kinds: PackedStringArray = []
							for a: Anomaly in g.key.anomalies:
								kinds.append(str(a.get(&"kind")) if &"kind" in a else a.get_class())
							print("QA14Q_DIFF seed=%d day=%d index=%d field=%s queue=%s window=%s scripted=%s bucket=%s anomalies=%s" % [
									seed, day_n, s.index, field, s.get(field), seen.get(field), g.scripted_id, bucket, kinds])
	print("QA14Q_SUMMARY clean=%d anom=%d diff_clean=%s diff_anom=%s" % [n["clean"], n["anom"], diff["clean"], diff["anom"]])
	get_tree().quit(0)
