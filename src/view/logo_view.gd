extends Node2D

# The logo, as site/logo.js draws it on the web: a cat in a badge that hunts,
# eats and naps, and spins one turn with the badge, curled up, in between.
# Only ever on the start screen: in play nothing but the mouse moves.
#
# Drawn in the units of the poses (the badge is 300 across), then scaled in
# every point rather than by the node, so the antialias feather stays a pixel.

const Poses := preload("res://src/view/logo_poses.gd")

const KEYS: Array[String] = ["body", "head", "tail", "legs", "eye", "bowl", "mouse", "mx", "chew", "wiggle", "sleep"]
const MID := Vector2(125, 98)      # the curled cat's middle
const N := 96                      # points on the badge
const CAM := 0.9
const CHANGE := 0.95               # the nap's own change, in pose seconds

var ink := Color.BLACK
var field := Color.WHITE
var soft := Color.GRAY
var width := 100.0                 # pixels across
var still := false                 # reduced motion: the nap, not moving

var sec := 0.0
var _xf := Transform2D.IDENTITY
var _k := 1.0


func _ready() -> void:
	still = DisplayServer.accessibility_should_reduce_animation() > 0
	if still:
		sec = nap_time()


func step(dt: float) -> void:
	if still:
		return
	sec = fmod(sec + dt * float(Poses.LOGO["speed"]), total())
	queue_redraw()


static func total() -> float:
	var n := 0.0
	for p: Dictionary in Poses.LOGO["poses"]:
		n += float(p["hold"]) + float(p["go"])
	return n


static func nap_time() -> float:
	return total() - CHANGE - 0.8


static func _mix(a: Variant, b: Variant, t: float) -> Variant:
	if a is Array:
		var out := []
		for i in range(a.size()):
			out.append(_mix(a[i], b[i], t))
		return out
	return lerpf(float(a), float(b), t)


static func pose(at: float) -> Dictionary:
	var ps: Array = Poses.LOGO["poses"]
	at = fposmod(at, total())
	var i := 0
	while i < ps.size() - 1 and at >= float(ps[i]["hold"]) + float(ps[i]["go"]):
		at -= float(ps[i]["hold"]) + float(ps[i]["go"])
		i += 1
	var a: Dictionary = ps[i]
	var b: Dictionary = ps[(i + 1) % ps.size()]
	var t := clampf((at - float(a["hold"])) / float(a["go"]), 0.0, 1.0)
	match a["name"]:
		"crouch":
			t = 1.0 - pow(1.0 - t, 3.0)
		"leap":
			t = t * t
		_:
			t = 4.0 * t * t * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 3.0) / 2.0
	var p := {}
	for k in KEYS:
		p[k] = _mix(a[k], b[k], t)
	p["change"] = 0.0 if a["word"] == b["word"] else t
	p["from"] = int(a["word"])
	p["to"] = int(b["word"])
	var lit: Array[float] = [0.0, 0.0, 0.0]
	lit[int(a["word"])] += 1.0 - t
	lit[int(b["word"])] += t
	p["words"] = lit
	p["blob"] = pow(maxf(0.0, sin(PI * t)), 0.55) if p["change"] > 0.0 else 0.0
	return p


# towards the curled-up cat, by p.blob
static func curl(p: Dictionary, at: float) -> Dictionary:
	var w: float = p["blob"]
	if w == 0.0:
		return p
	var ring := []
	for deg: float in [135.0, 180.0, 225.0, 270.0, 315.0, 0.0, 45.0, 90.0]:
		var a := deg_to_rad(deg)
		var rad := 43.0 + 2.5 * sin(2.0 * a + at * 7.0) + sin(3.0 * a - at * 5.0)
		ring.append([MID.x + cos(a) * rad, MID.y + sin(a) * rad])
	p["body"] = _mix(p["body"], ring, w)
	p["head"] = _mix(p["head"], [MID.x + 19, MID.y - 8, 20, 24], w)
	p["tail"] = _mix(p["tail"], [[MID.x - 40, MID.y + 8], [MID.x - 34, MID.y + 40],
		[MID.x + 2, MID.y + 48], [MID.x + 28, MID.y + 27]], w)
	var tucked := []
	for q: Array in [[-12, 8, 16], [-4, 10, 18], [6, 10, 18], [12, 8, 16]]:
		tucked.append([[MID.x + q[0], MID.y + q[1]], [MID.x + q[0], MID.y + q[2]]])
	p["legs"] = _mix(p["legs"], tucked, w)
	p["eye"] *= maxf(0.0, 1.0 - 1.6 * w)
	for k: String in ["bowl", "mouse", "sleep", "chew", "wiggle"]:
		p[k] *= maxf(0.0, 1.0 - 1.5 * w)
	return p


static func spin(p: Dictionary) -> float:
	var t: float = p["change"]
	if t <= 0.0:
		return 0.0
	return (0.75 * t + 0.25 * (1.0 + 1.7 * pow(t - 1.0, 3.0) + 0.7 * pow(t - 1.0, 2.0))) * TAU


# eat a wide dish, prey a burst, nap a cushion: a radius for every angle
static func radius(word: int, a: float) -> float:
	match word:
		0:
			return 119.0 + 5.0 * cos(2.0 * a)
		1:
			return 116.0 + 12.0 * cos(8.0 * a)
	return 109.8 / pow(pow(cos(a), 4.0) + pow(sin(a), 4.0), 0.25) + 2.0


static func shape(p: Dictionary) -> PackedVector2Array:
	var t: float = p["change"]
	var squeeze := 1.0 - 0.1 * sin(PI * t)
	var pts := PackedVector2Array()
	for i in range(N):
		var a := TAU * i / N
		var rad := lerpf(radius(p["from"], a), radius(p["to"] if t > 0.0 else p["from"], a), t) * squeeze
		pts.append(Vector2.from_angle(a + spin(p)) * rad)
	return pts


static func camera(p: Dictionary) -> float:
	var lo := minf(p["head"][0] + 14.0, p["tail"][3][0])
	var hi := maxf(p["head"][0] + 14.0, p["tail"][3][0])
	for q: Array in p["body"]:
		lo = minf(lo, q[0])
		hi = maxf(hi, q[0])
	var cx: float = lerpf((lo + hi) / 2.0, (lo + p["mx"] + 18.0) / 2.0, p["mouse"] * 0.9) + p["bowl"] * 8.0
	return lerpf(cx, MID.x, p["blob"])


# --- drawing ----------------------------------------------------------------

func _draw() -> void:
	var p := curl(pose(sec), sec)
	_k = width / 324.0
	var disc := PackedVector2Array()
	for q in shape(p):
		disc.append(q * _k)
	draw_colored_polygon(disc, ink)
	disc.append(disc[0])
	draw_polyline(disc, ink, 1.0, true)
	# pose units, to the badge's middle, turned with it, to pixels
	_xf = Transform2D(spin(p), Vector2.ZERO) * Transform2D(0.0, Vector2.ONE * CAM, 0.0,
		Vector2(-camera(p) * CAM, 62.0 - 150.0))
	_xf = Transform2D.IDENTITY.scaled(Vector2.ONE * _k) * _xf
	_k *= CAM
	_cat(p)


func _cat(p: Dictionary) -> void:
	# a pale cat on the dark badge
	var fur := field
	var gap := ink
	var s: float = p["sleep"]
	var sway: float = p["wiggle"] * sin(sec * 15.0) * 2.6
	var tip: float = p["wiggle"] * sin(sec * 8.0) * 7.0
	if p["mouse"] > 0.01:
		_mouse(p)
	for i in range(4):
		var leg: Array = p["legs"][i]
		_stroke([Vector2(leg[0][0] + (sway if i < 2 else 0.0), leg[0][1]), Vector2(leg[1][0], leg[1][1])], 10.0, fur, _xf)
	var body := PackedVector2Array()
	for i in range(8):
		var part := 0.0
		if i < 3:
			part = 1.0
		elif i == 3 or i == 7:
			part = 0.5
		body.append(Vector2(p["body"][i][0] + sway * part, p["body"][i][1]))
	var breath := 1.0 + s * sin(sec * 2.4) * 0.014
	var chest := _xf * Transform2D(0.0, Vector2(1.0, breath), 0.0, Vector2(0.0, 133.0 - 133.0 * breath))
	_fill(_smooth(body), fur, chest)
	var t: Array = p["tail"]
	var tail := _bezier(Vector2(t[0][0] + sway, t[0][1]), Vector2(t[1][0], t[1][1]), Vector2(t[2][0], t[2][1]),
		Vector2(t[3][0], t[3][1] + tip))
	var halo := maxf(pow(s, 4.0), pow(p["blob"], 4.0))
	if halo > 0.02:
		# faded by mixing: see-through strokes would show their joints
		_stroke(tail, 14.0, fur.lerp(gap, halo), chest)
	_stroke(tail, 9.0, fur, chest)
	_head(p, fur, gap, chest)
	if p["bowl"] > 0.01:
		var at := _xf * Transform2D(0.0, Vector2.ONE * float(p["bowl"]), 0.0, Vector2(184, 134))
		_fill(PackedVector2Array([Vector2(-20, -14), Vector2(20, -14), Vector2(15, 1), Vector2(-15, 1)]), soft, at)
	if s > 0.01:
		for i in range(3):
			var f := fmod(sec * 0.35 + i / 3.0, 1.0)
			var at := _xf * Transform2D(0.0, Vector2.ONE * (0.5 + f * 0.6) * s, 0.0, Vector2(184.0 + f * 22.0, 82.0 - f * 42.0))
			_stroke([Vector2(-6, -6), Vector2(6, -6), Vector2(-6, 6), Vector2(6, 6)], 3.4 * (0.5 + f * 0.6) * s,
				ink.lerp(fur, s * sin(f * PI)), at)


func _head(p: Dictionary, fur: Color, gap: Color, chest: Transform2D) -> void:
	var h: Array = p["head"]
	var chew: float = p["chew"] * sin(sec * 9.0) * 1.5
	var size := float(h[2]) / 19.0
	var at := chest * Transform2D(deg_to_rad(h[3]), Vector2.ONE * size, 0.0, Vector2(h[0], h[1] + chew))
	var pts := PackedVector2Array([Vector2(-17, -6), Vector2(-15, -27)])
	pts.append_array(_quad(Vector2(-15, -27), Vector2(-14, -30), Vector2(-11, -28)))
	pts.append(Vector2(-2, -18))
	pts.append_array(_quad(Vector2(-2, -18), Vector2(3, -19), Vector2(6, -18)))
	pts.append(Vector2(15, -27))
	pts.append_array(_quad(Vector2(15, -27), Vector2(18, -29), Vector2(18, -25)))
	pts.append(Vector2(18, -5))
	# the round of the cheeks and chin
	var c := Vector2(0.4, 1.8)
	var from := ((Vector2(18, -5) - c) / Vector2(19, 18)).angle()
	var to := ((Vector2(-17, -6) - c) / Vector2(19, 18)).angle() + TAU
	for i in range(1, 24):
		pts.append(c + Vector2.from_angle(lerpf(from, to, i / 24.0)) * Vector2(19, 18))
	_stroke(_closed(pts), 5.0 * size, gap, at)
	_fill(pts, fur, at)
	for x: float in [-3.0, 11.0]:
		if p["eye"] < 0.3:
			_stroke(_quad(Vector2(x - 4.4, -3), Vector2(x, -3.0 + 4.5 * (1.0 - p["eye"])), Vector2(x + 4.4, -3)), 2.2 * size, gap, at)
		else:
			_fill(_oval(Vector2(x, -3), Vector2(4.4, 5.06 * p["eye"])), gap, at)
			_fill(_oval(Vector2(x + 0.8, -3), Vector2(2.0, 3.74 * p["eye"])), fur, at)


func _mouse(p: Dictionary) -> void:
	# it fades where it would stick out of the badge
	var foot := _xf * Vector2(p["mx"], 128)
	var room := clampf((width * 0.36 - foot.length()) / (width * 0.05), 0.0, 1.0)
	var size := minf(1.0, p["mouse"] * 1.6) * room
	if size < 0.02:
		return
	var at := _xf * Transform2D(0.0, Vector2.ONE * size, 0.0, Vector2(p["mx"], 134))
	var pts := PackedVector2Array([Vector2(-16, 0)])
	pts.append_array(_quad(Vector2(-16, 0), Vector2(-16, -15), Vector2(-2, -15)))
	pts.append_array(_quad(Vector2(-2, -15), Vector2(10, -15), Vector2(18, -2)))
	pts.append(Vector2(15, 0))
	_fill(pts, soft, at)
	_fill(_oval(Vector2(3, -15), Vector2(6, 6)), soft, at)
	_stroke(_quad(Vector2(-14, -3), Vector2(-25, -2), Vector2(-24, -12)), 3.0 * size, soft, at)


func _fill(pts: PackedVector2Array, col: Color, at: Transform2D) -> void:
	var out := at * pts
	if Geometry2D.triangulate_polygon(out).is_empty():
		out = Geometry2D.convex_hull(out)      # a pose folded over itself
		if out.size() < 4:
			return
	draw_colored_polygon(out, col)
	draw_polyline(_closed(out), col, 1.0, true)


# a round-ended line; w is in pose units
func _stroke(pts: PackedVector2Array, w: float, col: Color, at: Transform2D) -> void:
	var out := at * pts
	var px := maxf(w * _k, 0.5)
	draw_polyline(out, col, px, true)
	for q in out:
		draw_circle(q, px * 0.5, col, true, -1.0, true)


static func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	out.append(pts[0])
	return out


static func _quad(a: Vector2, b: Vector2, c: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array([a])
	for i in range(1, 9):
		out.append(a.lerp(b, i / 8.0).lerp(b.lerp(c, i / 8.0), i / 8.0))
	return out


static func _bezier(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(19):
		out.append(a.bezier_interpolate(b, c, d, i / 18.0))
	return out


static func _oval(c: Vector2, rad: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(20):
		out.append(c + Vector2.from_angle(TAU * i / 20.0) * rad)
	return out


# a closed Catmull-Rom curve
static func _smooth(p: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := p.size()
	for i in range(n):
		for j in range(6):
			out.append(p[i].cubic_interpolate(p[(i + 1) % n], p[(i + n - 1) % n], p[(i + 2) % n], j / 6.0))
	return out
