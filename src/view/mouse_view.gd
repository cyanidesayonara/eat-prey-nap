extends Node2D

# Draws the mouse the brain describes: one bold silhouette with big ears and
# a long tail. Works in millimetres and scales as it draws: a scaled node
# would blow up the one-pixel antialias feather into a blur.

const Brain := preload("res://src/sim/mouse_brain.gd")

const TAIL_N := 12

var brain: Brain
var ppm := 4.0
var color := Color.BLACK
var field := Color.WHITE
var tail := PackedVector2Array()

var _clock := 0.0
var _roll := 0.0             # 0 on its feet, 1 caught
var _gait := 0.0


func step(dt: float) -> void:
	_clock += dt
	_gait += brain.speed * dt / maxf(brain.length, 1.0) * 9.0
	_roll = move_toward(_roll, 1.0 if brain.state == Brain.CAUGHT else 0.0, dt * 5.0)
	_step_tail(dt)
	queue_redraw()


func reset_tail() -> void:
	tail.clear()


# the tail follows the rump like a rope, and twitches when the mouse is still
func _step_tail(dt: float) -> void:
	var rump := brain.pos - brain.dir() * brain.length * Brain.RUMP
	var seg := brain.length * Brain.TAIL_LEN / float(TAIL_N - 1) * maxf(brain.tail_out, 0.02)
	if tail.size() != TAIL_N or tail[0].distance_to(rump) > brain.length or brain.state <= Brain.TELL:
		tail.resize(TAIL_N)
		for i in range(TAIL_N):
			tail[i] = rump - brain.dir() * seg * float(i)
	tail[0] = rump
	var twitch := 0.0
	if brain.state in [Brain.SNIFF, Brain.FREEZE, Brain.PEEK]:
		twitch = maxf(0.0, sin(_clock * 2.3) * sin(_clock * 5.9)) * sin(_clock * 13.0)
	elif brain.state == Brain.PINNED:
		twitch = sin(_clock * 34.0) * 1.4
	elif brain.speed > 1.0:
		twitch = sin(_gait) * 0.5
	# under a mound it stays straight, or it would poke out of the side
	for m in brain.mounds:
		if rump.distance_to(m) < brain.mound_r:
			twitch = 0.0
	for i in range(1, TAIL_N):
		var d := tail[i] - tail[i - 1]
		if i == 1:
			d = -brain.dir() * seg + d * 0.3
		d += brain.dir().orthogonal() * twitch * brain.length * 3.0 * dt * (float(i) / TAIL_N)
		if d.length_squared() < 0.000001:
			d = -brain.dir()
		tail[i] = tail[i - 1] + d.normalized() * seg


func _draw() -> void:
	if brain == null or brain.state == Brain.HIDDEN:
		return
	if brain.state == Brain.TELL:
		_draw_tell()
		return
	var l := brain.length * ppm
	if brain.tail_out > 0.01:
		_draw_tail(tail, brain.length * 0.075)
	var tremble := Vector2.ZERO
	var squash := 1.0
	var wriggle := 0.0
	if brain.state == Brain.PINNED:
		tremble = Vector2(sin(_clock * 61.0), cos(_clock * 47.0)) * l * 0.012
		wriggle = sin(_clock * 38.0) * 0.16
		squash = 0.9
	elif brain.state == Brain.SNIFF:
		squash = 1.0 + sin(_clock * 18.0) * 0.015
	elif brain.state == Brain.CREEP and brain.speed < 1.0:
		squash = 0.96
	draw_set_transform(brain.pos * ppm + tremble, brain.heading + wriggle, Vector2(squash, 2.0 - squash))
	_draw_feet(l)
	# body, pear shaped: wide behind, narrow to the nose
	_blob([Vector2(-0.40, 0.0), Vector2(-0.34, 0.15), Vector2(-0.12, 0.235), Vector2(0.12, 0.19),
		Vector2(0.32, 0.12), Vector2(0.50, 0.0), Vector2(0.32, -0.12), Vector2(0.12, -0.19),
		Vector2(-0.12, -0.235), Vector2(-0.34, -0.15)], l)
	var ear := l * 0.155
	var flick := maxf(0.0, sin(_clock * 3.1)) * sin(_clock * 23.0) * 0.015
	for s: float in [-1.0, 1.0]:
		var c := Vector2(0.17 + flick * s, 0.19 * s) * l
		_dot(c, ear, color)
		# a paler middle makes the ear read as an ear
		_dot(c + Vector2(0.02, 0.025 * s) * l, ear * 0.42, color.lerp(field, 0.55))
	if _roll > 0.0:
		# caught: a paler belly up
		_dot(Vector2(-0.08, 0.0) * l, l * 0.12 * _roll, color.lerp(field, 0.4))
	draw_set_transform(Vector2.ZERO)


func _draw_feet(l: float) -> void:
	for i in range(4):
		var s := 1.0 if i % 2 == 0 else -1.0
		var phase := _gait + (0.0 if (i == 0 or i == 3) else PI)
		var reach := sin(phase) * 0.07 if brain.speed > 1.0 else 0.0
		_dot(Vector2((0.22 if i < 2 else -0.22) + reach, 0.20 * s) * l, l * 0.055, color)


# only ears, or only a tail, from behind a mound's edge
func _draw_tell() -> void:
	var l := brain.length
	var edge := brain.mounds[brain.mound] + brain.out_dir * brain.mound_r
	var side := brain.out_dir.orthogonal()
	var rise := smoothstep(0.0, 0.25, brain.t)
	if brain.tell_tail:
		var pts := PackedVector2Array()
		for i in range(TAIL_N):
			var f := float(i) / float(TAIL_N - 1)
			var sway := sin(_clock * 6.0 - f * 3.5) * f * l * 0.16
			pts.append(edge + brain.out_dir * (f * 0.62 * rise - 0.1) * l + side * sway)
		_draw_tail(pts, l * 0.08)
		return
	var twitch := maxf(0.0, sin(_clock * 4.0)) * sin(_clock * 19.0) * 0.02
	for s: float in [-1.0, 1.0]:
		_dot((edge + (brain.out_dir * (0.17 * rise - 0.15 + twitch * s) + side * 0.17 * s) * l) * ppm, l * 0.155 * ppm, color)


func _draw_tail(pts: PackedVector2Array, width: float) -> void:
	for i in range(pts.size() - 1):
		var w := lerpf(width, width * 0.4, float(i) / float(pts.size() - 1)) * ppm
		draw_line(pts[i] * ppm, pts[i + 1] * ppm, color, w, true)
		_dot(pts[i + 1] * ppm, w * 0.5, color)


func _dot(c: Vector2, r: float, col: Color) -> void:
	draw_circle(c, r, col, true, -1.0, true)


# a soft closed shape through control points (Chaikin corner cutting)
func _blob(ctrl: Array, k: float) -> void:
	var p := PackedVector2Array()
	for v: Vector2 in ctrl:
		p.append(v * k * 1.06)
	for _r in range(3):
		var q := PackedVector2Array()
		for i in range(p.size()):
			var b := p[(i + 1) % p.size()]
			q.append(p[i].lerp(b, 0.25))
			q.append(p[i].lerp(b, 0.75))
		p = q
	draw_colored_polygon(p, color)
	p.append(p[0])
	draw_polyline(p, color, k * 0.02, true)
