extends RefCounted

# One mouse, in millimetres of real screen. No nodes and no drawing, so the
# tests run it headless; src/view/ only reads it.
#
#   hidden > tell > peek > sniff > creep > freeze > dart > hide
#
# TELL shows ears or a tail at a mound's edge before anything else does.
# The first outing is in that order; after that sniff, creep and freeze mix.
# A paw can send it to PINNED, and from there it wriggles free or is CAUGHT.
# Stillness and bursts, of irregular length: it never glides steadily.

const Difficulty := preload("res://src/sim/difficulty.gd")

enum { HIDDEN, TELL, PEEK, SNIFF, CREEP, FREEZE, DART, HIDE, PINNED, CAUGHT }
const NAMES: Array[String] = ["hidden", "tell", "peek", "sniff", "creep", "freeze",
	"dart", "hide", "pinned", "caught"]

# mm and seconds
const MOUND_R := 0.58            # of a body length; hides the body
const RUMP := 0.36               # of a body length, behind the middle
const TAIL_LEN := 0.9
const MAX_LEN_SHARE := 0.30      # prey length is capped at this share of the short side
const HIT_BODY := 0.22           # of a body length, round the spine
const HIT_PAD := 10.0            # plus half a cat's paw
const REACT_NEAR := 45.0         # a press this close to the body: run
const REACT_FAR := 95.0          # a press this close: freeze and think
const REACT_DELAY := [0.07, 0.20]
const CREEP_SPEED := [22.0, 55.0]
const DART_SPEED := 420.0
const DART_RAMP := 0.10          # time to reach full dart speed
const DART_MAX := 3.0
const SLIP_GRACE := 0.35         # cannot be hit right after getting away
const PIN_CHANCE := 0.7          # a good try that is no catch still pins this often
const PIN_FREE := [0.5, 1.3]
const PIN_CATCH := [0.4, 0.9]
const CAUGHT_TIME := 2.6
const IGNORED_START := 6.0       # seconds without a paw before it gets bolder
const IGNORED_FULL := 40.0
const WATCH_BOLDNESS := 0.55
const MAX_CRUMBS := 5
const MAX_LEGS := 5              # sniff/creep rounds before it must run home

var rng := RandomNumberGenerator.new()
var difficulty := Difficulty.new()
var area := Rect2(0, 0, 270, 170)
var length := 40.0               # body without the tail
var watch := false               # watch mode: no touch at all

var mounds: Array[Vector2] = []
var mound_r := 30.0
var crumbs: Array[Vector2] = []

var state := HIDDEN
var t := 0.0                     # time in this state
var dur := 1.5                   # when it ends by itself
var pos := Vector2.ZERO
var heading := 0.0
var speed := 0.0                 # this step's, for the view and the tests
var mound := 0                   # the one it is under, or came from
var out_dir := Vector2.RIGHT     # which way it looks out of the mound
var tell_tail := false           # this tell is a tail, not ears
var tail_out := 1.0              # 0 reeled in under the mound, 1 full
var boldness := 0.0
var ignored := 0.0

# what happened, for sound and statistics; the owner empties it
var events: Array[String] = []

var _target := Vector2.ZERO
var _to_mound := false
var _react := -1.0               # countdown to a startled dart
var _threat := Vector2.ZERO
var _grace := 0.0
var _will_catch := false
var _burst := 0.0                # creep: time left moving (+) or still (-)
var _burst_speed := 0.0
var _wobble := 0.0
var _home := -1                  # the mound it must use next (after a rummage)
var _legs := 0
var _from := 0                   # the mound it came out of


func setup(area_mm: Rect2, len_mm: float, seed_value := -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	resize(area_mm, len_mm)
	_enter_hidden()
	dur = 1.2


func resize(area_mm: Rect2, len_mm: float) -> void:
	area = area_mm
	length = minf(len_mm, minf(area.size.x, area.size.y) * MAX_LEN_SHARE)
	mound_r = length * MOUND_R
	mounds.clear()
	var inner := area.grow(-mound_r * 0.45)
	for f: Vector2 in [Vector2(0.0, 0.66), Vector2(1.0, 0.36), Vector2(0.56, 1.0), Vector2(0.34, 0.0)]:
		mounds.append(inner.position + inner.size * f)
	pos = mounds[mound]
	crumbs.clear()
	_scatter()
	if state != HIDDEN:
		_enter_hidden()


func is_out() -> bool:
	return state in [PEEK, SNIFF, CREEP, FREEZE, DART, HIDE]


func dir() -> Vector2:
	return Vector2.from_angle(heading)


# the spine, rump to nose
func spine() -> PackedVector2Array:
	return PackedVector2Array([pos - dir() * length * RUMP, pos + dir() * length * 0.46])


func distance_to(p: Vector2) -> float:
	var s := spine()
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, s[0], s[1]))


func hit_radius() -> float:
	return length * HIT_BODY + HIT_PAD


# --- paws -------------------------------------------------------------------

# A paw came down. Acts at once. Returns what it did:
# ignored, far, near, rummage, slip, pin
func press(p: Vector2) -> String:
	if watch:
		return "ignored"
	ignored = 0.0
	if state in [PINNED, CAUGHT]:
		return "ignored"
	if state in [HIDDEN, TELL]:
		if p.distance_to(mounds[mound]) < mound_r + HIT_PAD:
			return _rummage()
		return "far"
	if _grace > 0.0:
		return "ignored"
	var d := distance_to(p)
	if d <= hit_radius():
		return _hit(p)
	if d <= hit_radius() + REACT_NEAR * lerpf(1.0, 0.7, boldness):
		_startle(p)
		return "near"
	if d <= REACT_FAR and state in [SNIFF, CREEP]:
		_enter_freeze()
	return "far"


# A paw swept across the screen from a to b (fast drags only).
func swipe(a: Vector2, b: Vector2) -> String:
	if watch:
		return "ignored"
	ignored = 0.0
	if not is_out() or _grace > 0.0:
		return "ignored"
	var s := spine()
	var pts := Geometry2D.get_closest_points_between_segments(a, b, s[0], s[1])
	var crosses: bool = Geometry2D.segment_intersects_segment(a, b, s[0], s[1]) != null
	if crosses or pts[0].distance_to(pts[1]) <= hit_radius():
		return _hit(pts[0])
	return "far"


# A paw is sliding about near here, slowly: stalking. It is noticed.
func stalk(p: Vector2) -> void:
	if watch:
		return
	ignored = 0.0
	if state in [SNIFF, CREEP] and distance_to(p) < hit_radius() + REACT_NEAR:
		_enter_freeze()


func _hit(p: Vector2) -> String:
	var caught := rng.randf() < difficulty.chance()
	difficulty.record(caught)
	_react = -1.0
	_threat = p
	if caught or rng.randf() < PIN_CHANCE:
		_will_catch = caught
		events.append("pin")
		_go(PINNED, _range(PIN_CATCH) if caught else _range(PIN_FREE))
		return "pin"
	_grace = SLIP_GRACE
	events.append("slip")
	_dart_away()
	return "slip"


func _startle(p: Vector2) -> void:
	if state in [DART, HIDE] or _react >= 0.0:
		return
	_threat = p
	_react = _range(REACT_DELAY) / difficulty.pace()


# pawing at the mound it is under: it slips out of another one, soon
func _rummage() -> String:
	_home = _other_mound(mound)
	mound = _home
	pos = mounds[mound]
	tail_out = 0.0
	events.append("rustle")
	_go(HIDDEN, rng.randf_range(0.5, 1.3))
	return "rummage"


# --- time -------------------------------------------------------------------

func step(dt: float) -> void:
	# substeps keep a slow frame from jumping a dart past its target
	var left := minf(dt, 0.1)
	while left > 0.00001:
		var h := minf(left, 1.0 / 60.0)
		_step(h)
		left -= h


func _step(dt: float) -> void:
	t += dt
	_grace = maxf(0.0, _grace - dt)
	ignored += dt
	boldness = WATCH_BOLDNESS if watch else smoothstep(IGNORED_START, IGNORED_FULL, ignored)
	speed = 0.0
	if _react >= 0.0:
		_react -= dt
		if _react < 0.0:
			if state == PEEK:
				_enter_hide()
			elif state in [SNIFF, CREEP, FREEZE]:
				_dart_away()
			return
	match state:
		HIDDEN:
			if t >= dur:
				_enter_tell()
		TELL:
			if t >= dur:
				_enter_peek()
		PEEK:
			_step_peek(dt)
		SNIFF:
			if t >= dur:
				_after_sniff()
		CREEP:
			_step_creep(dt)
		FREEZE:
			if t >= dur:
				_after_freeze()
		DART:
			_step_dart(dt)
		HIDE:
			_step_hide(dt)
		PINNED:
			if t >= dur:
				if _will_catch:
					events.append("caught")
					_go(CAUGHT, CAUGHT_TIME)
				else:
					_grace = SLIP_GRACE
					events.append("free")
					_dart_away()
		CAUGHT:
			if t >= dur:
				_enter_hidden()
				dur = rng.randf_range(2.5, 4.5)
	if state in [PEEK, SNIFF, CREEP, FREEZE, DART, PINNED]:
		# only as much tail as the mound it left still covers
		var clear := pos.distance_to(mounds[_from]) - length * RUMP + mound_r * 0.85
		tail_out = clampf(clear / (length * TAIL_LEN), 0.0, 1.0)


func _go(s: int, d: float) -> void:
	state = s
	t = 0.0
	dur = d


func _enter_hidden() -> void:
	mound = rng.randi() % mounds.size() if rng.randf() < 0.6 else mound
	pos = mounds[mound]
	tail_out = 0.0
	_react = -1.0
	_scatter()
	_go(HIDDEN, _irregular(lerpf(2.2, 1.0, boldness), 0.5, 6.0))


func _enter_tell() -> void:
	if _home >= 0:
		mound = _home
		_home = -1
	pos = mounds[mound]
	_from = mound
	out_dir = (area.get_center() - pos).normalized().rotated(rng.randf_range(-0.6, 0.6))
	heading = out_dir.angle()
	tell_tail = rng.randf() < 0.35
	_legs = 0
	events.append("rustle")
	_go(TELL, _irregular(0.9, 0.45, 2.4))


func _enter_peek() -> void:
	_go(PEEK, _irregular(lerpf(0.9, 0.6, boldness), 0.4, 2.6))


func _step_peek(dt: float) -> void:
	_move(mounds[mound] + out_dir * (mound_r - length * 0.10), 90.0, dt)
	if t < dur:
		return
	# a shy mouse often goes back in
	if rng.randf() < lerpf(0.30, 0.06, boldness):
		_enter_hide()
	else:
		_enter_sniff()


func _enter_sniff() -> void:
	events.append("sniff")
	_go(SNIFF, _irregular(lerpf(0.8, 1.2, boldness), 0.3, 3.0))


func _after_sniff() -> void:
	for i in range(crumbs.size()):
		if crumbs[i].distance_to(pos) < length * 0.7:
			crumbs.remove_at(i)
			break
	_legs += 1
	# the first sniff is at the mound's lip, so it comes out from there
	if _legs > 1 and rng.randf() < 0.45:
		_enter_freeze()
	else:
		_enter_creep()


func _enter_creep() -> void:
	_burst = 0.0
	if _emerging():
		# straight out from under the mound first, however long that takes
		_target = mounds[mound] + out_dir * (mound_r + length * 0.7)
		_go(CREEP, INF)
		return
	_target = _spot()
	_go(CREEP, _irregular(1.6, 0.7, 3.5))


func _emerging() -> bool:
	return pos.distance_to(mounds[mound]) < mound_r + length * 0.3


func _step_creep(dt: float) -> void:
	# scurry, stop, scurry: every creep is made of short unequal bursts
	if _burst > 0.0:
		_burst -= dt
		_move(_target, _burst_speed, dt)
		if _burst <= 0.0:
			_burst = -_irregular(0.22, 0.08, 0.7)
	else:
		_burst += dt
		if _burst >= 0.0:
			_burst = _irregular(0.28, 0.12, 0.6)
			_burst_speed = _range(CREEP_SPEED) * lerpf(1.0, 1.35, boldness)
	if pos.distance_to(_target) < length * 0.1 or t >= dur:
		if rng.randf() < 0.6 and _legs < MAX_LEGS:
			_enter_sniff()
		else:
			_enter_freeze()


func _enter_freeze() -> void:
	events.append("freeze")
	_go(FREEZE, _irregular(0.55, 0.2, 2.2))


func _after_freeze() -> void:
	_legs += 1
	if _legs < MAX_LEGS:
		var roll := rng.randf()
		var feint := lerpf(0.25, 0.45, boldness)
		if roll < feint:
			# a short dash, and it is still out
			_dart_to(_spot(), false)
			return
		if roll < feint + 0.15:
			_enter_creep()
			return
	# often another mound: the long run is the best part
	var m := _other_mound(mound) if rng.randf() < 0.7 else mound
	_dart_to(mounds[m], true, m)


func _dart_away() -> void:
	# the mound that takes it furthest from the paw for the least running
	var best := 0
	var best_score := INF
	for i in range(mounds.size()):
		var towards := (mounds[i] - pos).normalized().dot((_threat - pos).normalized())
		var score := pos.distance_to(mounds[i]) * (1.0 + 0.9 * towards) * rng.randf_range(0.8, 1.2)
		if score < best_score:
			best_score = score
			best = i
	_dart_to(mounds[best], true, best)


func _dart_to(p: Vector2, to_mound: bool, m := -1) -> void:
	_target = p
	_to_mound = to_mound
	if to_mound:
		mound = m
	_wobble = rng.randf() * TAU
	_react = -1.0
	events.append("dart")
	_go(DART, DART_MAX)


func _step_dart(dt: float) -> void:
	var v := DART_SPEED * difficulty.pace() * clampf(t / DART_RAMP, 0.15, 1.0)
	var to := _target - pos
	# it jinks, less as it gets there
	var jink := sin(t * 17.0 + _wobble) * 0.45 * clampf(to.length() / 80.0, 0.0, 1.0)
	_move(pos + to.rotated(jink), v, dt)
	var edge := area.grow(-2.0)
	pos = pos.clamp(edge.position, edge.end)
	var near := mound_r * 0.5 if _to_mound else 4.0
	if pos.distance_to(_target) < near or t >= dur:
		if _to_mound:
			_enter_hide()
		else:
			_enter_freeze()


func _enter_hide() -> void:
	_react = -1.0
	events.append("hide")
	_go(HIDE, 0.4)


func _step_hide(dt: float) -> void:
	_move(mounds[mound], 260.0, dt)
	# the tail goes in last
	tail_out = minf(tail_out, maxf(0.0, 1.0 - t / dur))
	if t >= dur and pos.distance_to(mounds[mound]) < 1.0:
		_enter_hidden()


func _move(to: Vector2, v: float, dt: float) -> void:
	var d := to - pos
	var n := minf(d.length(), v * dt)
	if n < 0.001:
		return
	pos += d.normalized() * n
	speed = n / dt
	# the peek comes out, and goes back in, facing the way it was
	if state in [CREEP, DART]:
		heading = lerp_angle(heading, d.angle(), 1.0 - exp(-dt * 22.0))


# --- choosing ---------------------------------------------------------------

# where to creep or feint to: a crumb, or open floor further in when bold
func _spot() -> Vector2:
	if not crumbs.is_empty() and rng.randf() < 0.6:
		var c: Vector2 = crumbs[rng.randi() % crumbs.size()]
		# the nose reaches the crumb, not the belly
		return _open(c - (c - pos).normalized() * length * 0.45)
	var reach := lerpf(0.35, 0.8, boldness)
	var p := mounds[mound].lerp(area.get_center(), rng.randf_range(0.5, 1.0) * reach + 0.2)
	return _open(p + Vector2.from_angle(rng.randf() * TAU) * length * rng.randf_range(0.2, 1.4))


# kept on the open floor: off the edges and out from under the mounds
func _open(p: Vector2) -> Vector2:
	var inner := area.grow(-length * 0.6)
	p = p.clamp(inner.position, inner.end)
	for m in mounds:
		var need := mound_r + length * 0.5
		if p.distance_to(m) < need:
			var away := (p - m).normalized() if p.distance_to(m) > 0.1 else (area.get_center() - m).normalized()
			p = (m + away * need).clamp(inner.position, inner.end)
	return p


func _other_mound(m: int) -> int:
	return (m + 1 + rng.randi() % (mounds.size() - 1)) % mounds.size()


func _scatter() -> void:
	if crumbs.size() >= 2:
		return
	while crumbs.size() < MAX_CRUMBS:
		crumbs.append(_open(area.position + area.size * Vector2(rng.randf(), rng.randf())))


func _range(r: Array) -> float:
	return rng.randf_range(r[0], r[1])


# log-normal: mostly near mid, sometimes much longer, never regular
func _irregular(mid: float, lo: float, hi: float) -> float:
	return clampf(mid * exp(rng.randfn(0.0, 0.55)), lo, hi)
