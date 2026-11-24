extends Node2D

# The floor: one flat colour, crumbs, and a faint border made of a looping
# mouse tail with paw prints. Redrawn only when something on it changes.

const Brain := preload("res://src/sim/mouse_brain.gd")

const BORDER_IN := 4.0       # mm from the window's edge
const TAIL_W := 1.5
const LOOP_EVERY := 46.0
const LOOP_R := 4.0

var brain: Brain
var pal: Dictionary
var ppm := 4.0
var bounds := Rect2()        # the whole window, mm


func _draw() -> void:
	if pal.is_empty():
		return
	draw_rect(Rect2(bounds.position * ppm, bounds.size * ppm).grow(5.0), pal["field"])
	_draw_border()
	for c in brain.crumbs:
		_dot(c, 1.7, pal["crumb"])
		_dot(c + Vector2(1.4, 0.8), 1.0, pal["crumb"])


static func _sides(r: Rect2) -> Array:
	return [[r.position, Vector2(r.end.x, r.position.y)], [Vector2(r.end.x, r.position.y), r.end],
		[r.end, Vector2(r.position.x, r.end.y)], [Vector2(r.position.x, r.end.y), r.position]]


# once round the edge, with a loop in the middle of every stretch
static func border_path(r: Rect2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for s: Array in _sides(r):
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var along := (b - a).normalized()
		var inward := Vector2(-along.y, along.x)      # clockwise, so inside is this way
		var n := maxi(1, int(a.distance_to(b) / LOOP_EVERY))
		var gap := a.distance_to(b) / float(n)
		pts.append(a + along * 2.0)
		for i in range(n):
			var mid := a + along * gap * (float(i) + 0.5)
			for k in range(25):
				var f := float(k) / 24.0
				pts.append(mid + along * (sin(f * TAU) * LOOP_R + (f - 0.5) * 6.0)
					+ inward * (1.0 - cos(f * TAU)) * LOOP_R)
		pts.append(b - along * 2.0)
	return pts


func _draw_border() -> void:
	var r := bounds.grow(-BORDER_IN)
	var pts := border_path(r)
	# a tail: one width, tapering to a tip at the end
	var last := pts.size() - 1
	for i in range(last):
		var w := lerpf(TAIL_W, TAIL_W * 0.4, clampf((float(i) / last - 0.85) / 0.15, 0.0, 1.0))
		draw_line(pts[i] * ppm, pts[i + 1] * ppm, pal["border"], w * ppm, true)
		_dot(pts[i + 1], w * 0.5, pal["border"])
	for s: Array in _sides(r):
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var along := (b - a).normalized()
		var inward := Vector2(-along.y, along.x)
		var n := maxi(1, int(a.distance_to(b) / LOOP_EVERY))
		for i in range(1, n):
			_paw(a.lerp(b, float(i) / float(n)) + inward * 5.0, along)


func _paw(c: Vector2, fwd: Vector2) -> void:
	_dot(c - fwd * 0.6, 1.5, pal["border"])
	for k in range(4):
		_dot(c + fwd.rotated((float(k) - 1.5) * 0.62) * 2.2, 0.65, pal["border"])


# a disc in millimetres, with a one-pixel soft edge
func _dot(c: Vector2, r: float, col: Color) -> void:
	draw_circle(c * ppm, r * ppm, col, true, -1.0, true)
