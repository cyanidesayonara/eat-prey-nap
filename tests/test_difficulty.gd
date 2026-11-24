extends "res://tests/check.gd"

const Difficulty := preload("res://src/sim/difficulty.gd")


func _initialize() -> void:
	var d := Difficulty.new()
	check(absf(d.chance() - 1.0 / 3.0) < 0.001, "starts at one in three")
	check(absf(d.pace() - 1.0) < 0.001, "starts at the normal pace")
	for i in range(4):
		d.record(true)
	check(d.chance() < 0.25 and d.pace() > 1.0, "catches make it harder")

	d = Difficulty.new()
	for i in range(4):
		d.record(false)
	check(d.chance() > 0.4 and d.pace() < 1.0, "misses make it easier")
	d.record(false)
	check(d.chance() == 1.0, "five misses in a row: the next is a catch")

	# left to itself it settles near the target
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	d = Difficulty.new()
	for i in range(5000):
		d.record(rng.randf() < d.chance())
	var r := float(d.catches) / d.good_tries
	check(r > 0.28 and r < 0.40, "long run catch rate near one in three (%.2f)" % r)
	finish()
