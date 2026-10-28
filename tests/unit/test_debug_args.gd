## DebugArgs (ARCHITECTURE §13 R18) : analyse des arguments, garde de build,
## application unique des arguments qui modifient la partie (QA-017).
extends GutTest


func test_parse_key_values_and_flags() -> void:
	var args: Dictionary = DebugArgs.parse(PackedStringArray(["--day=7", "--seed=3", "--autoplay", "--flags=a,b:2"]))
	assert_eq(str(args.get("day")), "7")
	assert_eq(str(args.get("seed")), "3")
	assert_eq(str(args.get("autoplay")), "true")
	assert_eq(str(args.get("flags")), "a,b:2")


## QA-017 : après la première scène, `--seed` / `--day` (et les captures) ne
## sont plus réappliqués ; les modes restent actifs.
func test_one_shot_arguments_are_dropped_once_consumed() -> void:
	var args: Dictionary = DebugArgs.parse(PackedStringArray(["--day=7", "--seed=3", "--screen=end", "--autoplay",
			"--no-booth", "--reduce-motion"]))
	var first: Dictionary = DebugArgs.filter(args, false)
	assert_eq(first.size(), args.size(), "première scène : tout s'applique")
	var later: Dictionary = DebugArgs.filter(args, true)
	for key: String in ["day", "seed", "screen"]:
		assert_false(later.has(key), "%s non réappliqué" % key)
	for key: String in ["autoplay", "no-booth", "reduce-motion"]:
		assert_true(later.has(key), "%s conservé" % key)


func test_enabled_in_debug_builds() -> void:
	assert_eq(DebugArgs.enabled(), OS.is_debug_build() or OS.has_feature(DebugArgs.FEATURE))
	assert_true(DebugArgs.enabled(), "suite lancée par un binaire de debug")
