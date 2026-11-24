extends "res://tests/check.gd"

const Paws := preload("res://src/input/paws.gd")


func _make() -> Paws:
	var p := Paws.new()
	p.bounds = Rect2(0, 0, 270, 170)
	p.step(1.0)
	return p


func _hold(p: Paws, sec: float) -> void:
	for i in range(int(sec * 60)):
		p.step(1.0 / 60.0)


func _initialize() -> void:
	var p := _make()
	check(p.press(0, Vector2(100, 80)), "a press is a paw")
	check(not p.press(1, Vector2(112, 84)), "its other pads are not more paws")
	check(p.press(2, Vector2(220, 80)), "a second paw elsewhere is")
	check(p.swats == 2 and p.touches.size() == 3, "two paws, three pads")

	p = _make()
	p.press(0, Vector2(100, 80))
	_hold(p, 1.0)
	check((p.touches[0] as Paws.Touch).resting, "a still pad is resting")
	check(p.drag(0, Vector2(101, 80), Vector2(400, 0)) == "", "a resting pad's shiver does nothing")
	check(p.press(1, Vector2(150, 60)), "a resting pad does not block another paw")
	p.release(1)
	var t := p.active_t
	_hold(p, 1.0)
	check(is_equal_approx(p.active_t, t), "a resting pad is not activity")
	check(p.drag(0, Vector2(130, 80), Vector2(300, 0)) == "swipe", "a resting pad that swipes is a paw again")
	check(p.drag(0, Vector2(140, 80), Vector2(40, 0)) == "stalk", "a slow one stalks")
	check(p.drag(9, Vector2.ZERO, Vector2.ZERO) == "", "a drag without a press is nothing")

	# the human's way out
	var cs := [Vector2(5, 5), Vector2(265, 5), Vector2(265, 165), Vector2(5, 165)]
	for pair: Array in [[0, 2], [1, 3]]:
		p = _make()
		p.press(0, cs[pair[0]])
		p.press(1, cs[pair[1]])
		_hold(p, 1.9)
		check(not p.exit_wanted(), "not before two seconds")
		_hold(p, 0.2)
		check(p.exit_wanted(), "two opposite corners for two seconds leave")
	p = _make()
	p.press(0, cs[0])
	p.press(1, cs[1])
	_hold(p, 4.0)
	check(not p.exit_wanted(), "neighbouring corners do not")
	p = _make()
	p.press(0, cs[0])
	p.press(1, cs[2])
	_hold(p, 1.5)
	p.release(1)
	_hold(p, 0.1)
	p.press(1, cs[2])
	_hold(p, 1.5)
	check(not p.exit_wanted(), "lifting starts the two seconds again")
	p = _make()
	p.press(0, cs[0])
	p.press(1, cs[2])
	p.drag(1, Vector2(200, 100), Vector2(100, 0))
	_hold(p, 3.0)
	check(not p.exit_wanted(), "a paw that leaves its corner does not count")
	finish()
