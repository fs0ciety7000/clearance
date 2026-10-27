## Tests GameDate : epoch, format/parse, bissextiles, comparaisons, ajouts.
extends GutTest


func test_epoch_is_day_zero() -> void:
	assert_eq(GameDate.from_ymd(2100, 1, 1), 0)
	assert_eq(GameDate.format(0), "01.01.2100")
	assert_eq(GameDate.to_ymd(0), Vector3i(2100, 1, 1))


func test_format_reference_date() -> void:
	var d: int = GameDate.from_ymd(2187, 3, 19)
	assert_eq(GameDate.format(d), "19.03.2187")
	assert_eq(GameDate.format_pattern(d, "YYYY.MM.DD"), "2187.03.19")


func test_known_offsets() -> void:
	# 2100 n'est pas bissextile : 365 jours jusqu'au 01.01.2101.
	assert_eq(GameDate.from_ymd(2101, 1, 1), 365)
	assert_eq(GameDate.from_ymd(2099, 12, 31), -1)
	# 2000 l'est (divisible par 400) : 366 jours.
	assert_eq(GameDate.from_ymd(2001, 1, 1) - GameDate.from_ymd(2000, 1, 1), 366)


func test_round_trip_over_four_centuries() -> void:
	var start: int = GameDate.from_ymd(2000, 1, 1)
	var end: int = GameDate.from_ymd(2400, 12, 31)
	var failures: int = 0
	var d: int = start
	while d <= end:
		var ymd: Vector3i = GameDate.to_ymd(d)
		if GameDate.from_ymd(ymd.x, ymd.y, ymd.z) != d:
			failures += 1
		d += 1
	assert_eq(failures, 0)


func test_round_trip_format_parse_sample() -> void:
	for d: int in range(-40_000, 80_000, 97):
		assert_eq(GameDate.parse(GameDate.format(d)), d)


func test_leap_years() -> void:
	assert_true(GameDate.is_leap_year(2000))
	assert_true(GameDate.is_leap_year(2188))
	assert_false(GameDate.is_leap_year(2187))
	assert_false(GameDate.is_leap_year(2100))
	assert_false(GameDate.is_leap_year(2200))
	assert_true(GameDate.is_leap_year(2400))
	assert_eq(GameDate.days_in_month(2188, 2), 29)
	assert_eq(GameDate.days_in_month(2187, 2), 28)
	assert_eq(GameDate.days_in_month(2100, 2), 28)


func test_feb_29_handling() -> void:
	assert_eq(GameDate.parse("29.02.2188"), GameDate.from_ymd(2188, 2, 29))
	assert_eq(GameDate.parse("29.02.2187"), GameDate.INVALID)
	assert_eq(GameDate.parse("29.02.2100"), GameDate.INVALID)
	assert_eq(GameDate.add_days(GameDate.from_ymd(2188, 2, 28), 1), GameDate.from_ymd(2188, 2, 29))
	assert_eq(GameDate.add_days(GameDate.from_ymd(2187, 2, 28), 1), GameDate.from_ymd(2187, 3, 1))
	# 29.02 + 1 an → 28.02 de l'année suivante.
	assert_eq(GameDate.add_years(GameDate.from_ymd(2188, 2, 29), 1), GameDate.from_ymd(2189, 2, 28))


func test_parse_accepts_single_digit_day_month() -> void:
	assert_eq(GameDate.parse("1.3.2187"), GameDate.from_ymd(2187, 3, 1))
	assert_eq(GameDate.parse("  19.03.2187 "), GameDate.from_ymd(2187, 3, 19))


func test_parse_rejects_garbage() -> void:
	for text: String in ["", "19/03/2187", "19.03.87", "32.01.2187", "00.01.2187", "19.13.2187", "aa.bb.cccc", "+1.03.2187", "19.03.2187.1"]:
		assert_eq(GameDate.parse(text), GameDate.INVALID, "« %s » doit être invalide" % text)
		assert_false(GameDate.is_valid(GameDate.parse(text)))


func test_from_ymd_invalid_reports_error() -> void:
	assert_eq(GameDate.from_ymd(2187, 2, 30), GameDate.INVALID)
	assert_push_error_count(1)


func test_comparisons() -> void:
	var a: int = GameDate.from_ymd(2187, 3, 19)
	var b: int = GameDate.from_ymd(2187, 3, 20)
	assert_true(GameDate.is_before(a, b))
	assert_true(GameDate.is_after(b, a))
	assert_false(GameDate.is_before(a, a))
	assert_eq(GameDate.compare(a, b), -1)
	assert_eq(GameDate.compare(b, a), 1)
	assert_eq(GameDate.compare(a, a), 0)
	assert_eq(GameDate.days_between(a, b), 1)
	assert_eq(GameDate.days_between(b, a), -1)


func test_add_days_across_year() -> void:
	var d: int = GameDate.from_ymd(2187, 12, 31)
	assert_eq(GameDate.format(GameDate.add_days(d, 1)), "01.01.2188")
	assert_eq(GameDate.format(GameDate.add_days(d, -365)), "31.12.2186")


func test_components() -> void:
	var d: int = GameDate.from_ymd(2187, 3, 19)
	assert_eq(GameDate.year_of(d), 2187)
	assert_eq(GameDate.month_of(d), 3)
	assert_eq(GameDate.day_of(d), 19)


func test_age_on() -> void:
	var birth: int = GameDate.from_ymd(2150, 6, 15)
	assert_eq(GameDate.age_on(birth, GameDate.from_ymd(2187, 6, 14)), 36)
	assert_eq(GameDate.age_on(birth, GameDate.from_ymd(2187, 6, 15)), 37)
