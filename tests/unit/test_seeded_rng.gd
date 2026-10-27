## Tests SeededRng : déterminisme, mélange de graines, distribution, shuffle.
extends GutTest

const SAMPLES: int = 10_000


func _sequence(rng_seed: int, count: int) -> Array[int]:
	var rng: SeededRng = SeededRng.new(rng_seed)
	var out: Array[int] = []
	for i: int in count:
		out.append(rng.randi_range(0, 1_000_000))
	return out


func test_same_seed_same_sequence() -> void:
	assert_eq(_sequence(42, 100), _sequence(42, 100))


func test_different_seed_different_sequence() -> void:
	assert_ne(_sequence(42, 100), _sequence(43, 100))


func test_reset_replays_sequence() -> void:
	var rng: SeededRng = SeededRng.new(7)
	var first: Array[float] = []
	for i: int in 20:
		first.append(rng.randf())
	rng.reset()
	var second: Array[float] = []
	for i: int in 20:
		second.append(rng.randf())
	assert_eq(first, second)
	assert_eq(rng.get_seed(), 7)


func test_mix_is_deterministic_and_order_sensitive() -> void:
	assert_eq(SeededRng.mix(123, 4), SeededRng.mix(123, 4))
	assert_ne(SeededRng.mix(123, 4), SeededRng.mix(4, 123))
	assert_ne(SeededRng.mix(123, 4), SeededRng.mix(123, 5))
	assert_ne(SeededRng.mix(0, 0), 0)


func test_mix_reference_values() -> void:
	# Valeurs de référence (implémentation Python indépendante de SplitMix64) :
	# garde-fou contre un changement involontaire de l'algorithme de graines.
	assert_eq(SeededRng.avalanche(0), 0)
	assert_eq(SeededRng.avalanche(1), 6238072747940578789)
	assert_eq(SeededRng.mix(1, 2), -972091869234291113)
	assert_eq(SeededRng.hash_string("faction"), -2929813648748357861)


func test_mix_no_collisions_on_small_grid() -> void:
	var seen: Dictionary[int, bool] = {}
	for a: int in 50:
		for b: int in 50:
			seen[SeededRng.mix(a, b)] = true
	assert_eq(seen.size(), 2500)


func test_hash_string_stable() -> void:
	assert_eq(SeededRng.hash_string("abc"), SeededRng.hash_string("abc"))
	assert_ne(SeededRng.hash_string("abc"), SeededRng.hash_string("abd"))
	# FNV-1a 64 de la chaîne vide = offset basis.
	assert_eq(SeededRng.hash_string(""), SeededRng.FNV_OFFSET)


func test_case_seeds_are_independent_of_generation_order() -> void:
	var day: int = SeededRng.day_seed(99, 3)
	var direct: Array[int] = _sequence(SeededRng.case_seed(day, 7), 10)
	for i: int in 7:
		_sequence(SeededRng.case_seed(day, i), 10)
	assert_eq(_sequence(SeededRng.case_seed(day, 7), 10), direct)


func test_fork_does_not_consume_parent() -> void:
	var a: SeededRng = SeededRng.new(5)
	var b: SeededRng = SeededRng.new(5)
	var child: SeededRng = a.fork(1)
	assert_eq(a.next_u32(), b.next_u32())
	assert_eq(child.get_seed(), SeededRng.mix(5, 1))


func test_randi_range_bounds_and_rough_uniformity() -> void:
	var rng: SeededRng = SeededRng.new(2024)
	var counts: Array[int] = [0, 0, 0, 0, 0, 0]
	for i: int in SAMPLES:
		var v: int = rng.randi_range(0, 5)
		assert_true(v >= 0 and v <= 5)
		counts[v] += 1
	var expected: float = SAMPLES / 6.0
	for c: int in counts:
		assert_between(float(c), expected * 0.9, expected * 1.1)


func test_randf_bounds_and_mean() -> void:
	var rng: SeededRng = SeededRng.new(31337)
	var total: float = 0.0
	for i: int in SAMPLES:
		var v: float = rng.randf()
		assert_true(v >= 0.0 and v <= 1.0)
		total += v
	assert_almost_eq(total / SAMPLES, 0.5, 0.02)


func test_chance_extremes() -> void:
	var rng: SeededRng = SeededRng.new(1)
	for i: int in 100:
		assert_false(rng.chance(0.0))
		assert_true(rng.chance(1.0))


func test_pick_returns_member() -> void:
	var rng: SeededRng = SeededRng.new(11)
	var items: Array[StringName] = [&"a", &"b", &"c"]
	for i: int in 50:
		assert_has(items, rng.pick(items))


func test_pick_empty_returns_null_with_error() -> void:
	var rng: SeededRng = SeededRng.new(11)
	assert_null(rng.pick([]))
	assert_push_error_count(1)


func test_weighted_pick_distribution() -> void:
	var rng: SeededRng = SeededRng.new(77)
	var items: Array[String] = ["rare", "common", "never"]
	var weights: PackedFloat32Array = [1.0, 3.0, 0.0]
	var counts: Dictionary[String, int] = {"rare": 0, "common": 0, "never": 0}
	for i: int in SAMPLES:
		var picked: String = rng.weighted_pick(items, weights)
		counts[picked] += 1
	assert_eq(counts["never"], 0)
	assert_almost_eq(float(counts["common"]) / SAMPLES, 0.75, 0.03)


func test_weighted_index_all_zero() -> void:
	var rng: SeededRng = SeededRng.new(3)
	assert_eq(rng.weighted_index(PackedFloat32Array([0.0, 0.0])), -1)
	assert_eq(rng.weighted_index(PackedFloat32Array([0.0, 2.0])), 1)


func test_shuffle_is_stable_and_a_permutation() -> void:
	var base: Array[int] = []
	for i: int in 20:
		base.append(i)
	var a: Array[int] = base.duplicate()
	var b: Array[int] = base.duplicate()
	SeededRng.new(9).shuffle(a)
	SeededRng.new(9).shuffle(b)
	assert_eq(a, b, "même graine ⇒ même permutation")
	assert_ne(a, base, "20 éléments : la permutation identité est improbable")
	var sorted_a: Array[int] = a.duplicate()
	sorted_a.sort()
	assert_eq(sorted_a, base, "le mélange est une permutation")


func test_shuffled_keeps_original() -> void:
	var base: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8]
	var copy: Array = SeededRng.new(4).shuffled(base)
	assert_eq(base, [1, 2, 3, 4, 5, 6, 7, 8] as Array[int])
	assert_eq(copy.size(), base.size())
