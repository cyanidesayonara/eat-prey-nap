extends "res://tests/check.gd"

# The chase: order of states, irregular timing, no gliding, paws, boldness.

const Brain := preload("res://src/sim/mouse_brain.gd")
const MouseView := preload("res://src/view/mouse_view.gd")
const DT := 1.0 / 60.0
const AREA := Rect2(0, 0, 270, 170)


func _make(s: int, length := 40.0) -> Brain:
	var b := Brain.new()
	b.setup(AREA, length, s)
	return b


func _run_to(b: Brain, want: int, limit := 120.0) -> bool:
	var t := 0.0
	while t < limit:
		if b.state == want:
			return true
		b.step(DT)
		t += DT
	return false


func _initialize() -> void:
	_order()
	_rhythm()
	_stays_in()
	_hides_fully()
	_tail_covered()
	_paws()
	_cat()
	_boldness()
	_watch()
	_frame_rates()
	finish()


func _order() -> void:
	var b := _make(1)
	var seen := {}
	var prev := b.state
	var bad := ""
	var allowed := {
		Brain.HIDDEN: [Brain.TELL], Brain.TELL: [Brain.PEEK],
		Brain.PEEK: [Brain.SNIFF, Brain.HIDE],
		Brain.SNIFF: [Brain.CREEP, Brain.FREEZE], Brain.CREEP: [Brain.SNIFF, Brain.FREEZE],
		Brain.FREEZE: [Brain.DART, Brain.CREEP], Brain.DART: [Brain.HIDE, Brain.FREEZE],
		Brain.HIDE: [Brain.HIDDEN],
	}
	for i in range(60 * 600):
		b.step(DT)
		seen[b.state] = true
		if b.state != prev:
			if not b.state in allowed[prev]:
				bad = "%s > %s" % [Brain.NAMES[prev], Brain.NAMES[b.state]]
			prev = b.state
	check(bad == "", "only allowed transitions, got " + bad)
	check(seen.size() == 8, "all eight untouched states occur")


func _rhythm() -> void:
	var b := _make(2)
	var prev := b.state
	var t_in := 0.0
	var spells: Array[float] = []
	var ears := 0
	var tails := 0
	var glide := 0.0
	var worst := 0.0
	for i in range(60 * 900):
		b.step(DT)
		t_in += DT
		# frames of a feint's last step are still, so bursts always break up
		glide = glide + DT if b.state == Brain.CREEP and b.speed > 0.5 else 0.0
		worst = maxf(worst, glide)
		if b.state != prev:
			if prev == Brain.HIDDEN:
				spells.append(t_in)
			if b.state == Brain.TELL:
				if b.tell_tail:
					tails += 1
				else:
					ears += 1
			prev = b.state
			t_in = 0.0
	check(ears > 5 and tails > 5, "tells are sometimes ears (%d), sometimes a tail (%d)" % [ears, tails])
	check(worst < 0.8, "a creep never moves steadily for long (%.2f s)" % worst)
	var mean := 0.0
	for s in spells:
		mean += s / spells.size()
	var sd := 0.0
	for s in spells:
		sd += (s - mean) * (s - mean) / spells.size()
	check(sqrt(sd) / mean > 0.3, "hidden spells are irregular (cv %.2f)" % (sqrt(sd) / mean))


func _stays_in() -> void:
	for size: float in [28.0, 40.0, 55.0]:
		var b := _make(int(size), size)
		var escaped := false
		var covered := 0
		for i in range(60 * 300):
			b.step(DT)
			escaped = escaped or not AREA.grow(0.5).has_point(b.pos)
			# frozen in plain sight, never under a mound
			if b.state == Brain.FREEZE:
				for m in b.mounds:
					if b.pos.distance_to(m) < b.mound_r * 0.6:
						covered += 1
		check(not escaped, "%d mm mouse stays on the screen" % int(size))
		check(covered == 0, "%d mm mouse freezes where a cat can see it (%d)" % [int(size), covered])
	var phone := Brain.new()
	phone.setup(Rect2(0, 0, 140, 65), 55.0, 3)
	check(phone.length <= 65.0 * 0.3 + 0.01, "prey shrinks to fit a small screen")


func _hides_fully() -> void:
	var b := _make(5)
	var ok := true
	var n := 0
	for i in range(60 * 300):
		var was := b.state
		b.step(DT)
		if was == Brain.HIDE and b.state == Brain.HIDDEN:
			n += 1
			ok = ok and b.tail_out <= 0.01
	check(ok and n > 10, "the tail is in before it counts as hidden (%d times)" % n)


# coming out, no tail shows on the mound's far side
func _tail_covered() -> void:
	for size: float in [28.0, 40.0, 55.0]:
		var b := _make(50 + int(size), size)
		var v := MouseView.new()
		v.brain = b
		var bad := 0
		var looked := 0
		for i in range(60 * 200):
			b.step(DT)
			v.step(DT)
			if b.state == Brain.PEEK or (b.state == Brain.CREEP and b._emerging()):
				looked += 1
				for p in v.tail:
					var d := p - b.mounds[b.mound]
					if d.length() > b.mound_r + 0.5 and d.dot(b.out_dir) < 0.0:
						bad += 1
						break
		v.free()
		check(bad == 0 and looked > 100, "%d mm mouse's tail stays under its mound (%d of %d)" % [int(size), bad, looked])


func _paws() -> void:
	# a hit acts inside press(), with no step in between
	var b := _make(7)
	check(_run_to(b, Brain.SNIFF), "reaches a sniff")
	var r := b.press(b.pos)
	check(r in ["pin", "slip"] and b.state in [Brain.PINNED, Brain.DART], "a press acts at once: " + r)
	check(b.difficulty.good_tries == 1, "and is one good try")
	b.press(b.pos)
	check(b.difficulty.good_tries == 1, "the paw's second pad is not another")

	# generous: a pad beside the body still counts
	b = _make(8)
	_run_to(b, Brain.SNIFF)
	r = b.press(b.pos + b.dir().orthogonal() * (b.length * 0.235 + 8.0))
	check(r in ["pin", "slip"], "8 mm beside the body is a hit: " + r)

	# both endings of a pin happen
	var caught := 0
	var free := 0
	for s in range(80):
		b = _make(100 + s)
		_run_to(b, Brain.SNIFF)
		if b.press(b.pos) != "pin":
			continue
		for i in range(60 * 2):
			b.step(DT)
			if b.state == Brain.CAUGHT:
				caught += 1
				break
			if b.state == Brain.DART:
				free += 1
				break
	check(caught > 5 and free > 5, "pins end in catches (%d) and escapes (%d)" % [caught, free])

	# a near miss sends it running, after a short fright
	b = _make(9)
	_run_to(b, Brain.CREEP)
	r = b.press(b.pos + b.dir().orthogonal() * (b.hit_radius() + 12.0))
	check(r == "near" and b.state == Brain.CREEP, "a near miss: " + r)
	for i in range(16):
		b.step(DT)
	check(b.state in [Brain.DART, Brain.HIDE], "it runs from a near miss")

	b = _make(10)
	_run_to(b, Brain.SNIFF)
	b._go(Brain.CAUGHT, 2.0)
	check(b.press(b.pos) == "ignored", "a caught mouse ignores paws")

	b = _make(11)
	var m := b.mound
	check(b.press(b.mounds[m]) == "rummage", "pawing at its mound is noticed")
	_run_to(b, Brain.TELL)
	check(b.mound != m, "it comes out of another mound after a rummage")

	# a fast paw through it hits, even between two samples
	b = _make(12)
	_run_to(b, Brain.SNIFF)
	var side := b.dir().orthogonal() * 60.0
	check(b.swipe(b.pos - side, b.pos + side) in ["pin", "slip"], "a swipe across it hits")
	b = _make(13)
	_run_to(b, Brain.CREEP)
	b.stalk(b.pos + b.dir() * 30.0)
	check(b.state == Brain.FREEZE, "a stalking paw makes it freeze")


# a simulated cat: sees it, waits about a third of a second, swats where it was
func _cat() -> void:
	var b := _make(77)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var wait := 0.0
	var aim := Vector2.ZERO
	for i in range(60 * 1800):
		b.step(DT)
		if not b.is_out():
			wait = 0.0
			continue
		if wait <= 0.0:
			wait = rng.randf_range(0.25, 0.7)
			aim = b.pos + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 25.0)
		wait -= DT
		if wait <= 0.0:
			b.press(aim)
	var d := b.difficulty
	var rate := float(d.catches) / maxf(1.0, d.good_tries)
	check(d.good_tries > 100, "a simulated cat gets good tries (%d in 30 minutes)" % d.good_tries)
	check(rate > 0.25 and rate < 0.45, "and catches about one in three (%.2f)" % rate)


func _boldness() -> void:
	var b := _make(20)
	check(b.boldness < 0.01, "starts shy")
	for i in range(60 * 45):
		b.step(DT)
	check(b.boldness > 0.95, "bold when ignored")
	b.press(Vector2(-500, -500))
	b.step(DT)
	check(b.boldness < 0.01, "shy again after a paw")


func _watch() -> void:
	var b := _make(30)
	b.watch = true
	var seen := {}
	for i in range(60 * 300):
		b.step(DT)
		seen[b.state] = true
		if b.is_out():
			b.press(b.pos)
			b.swipe(b.pos - Vector2(20, 0), b.pos + Vector2(20, 0))
	check(not seen.has(Brain.PINNED) and b.difficulty.good_tries == 0, "watch mode needs and takes no touch")
	check(seen.size() == 8, "watch mode runs the whole chase")


func _frame_rates() -> void:
	# the share of time spent out is about the same at every refresh rate
	var share: Array[float] = []
	for hz: float in [60.0, 90.0, 120.0, 144.0]:
		var out := 0.0
		for s in range(4):
			var b := _make(40 + s)
			for i in range(int(hz * 400)):
				b.step(1.0 / hz)
				out += 1.0 / hz if b.is_out() else 0.0
		share.append(out / 1600.0)
	check(share.max() - share.min() < 0.08, "plays alike at every refresh rate %s" % [share])
