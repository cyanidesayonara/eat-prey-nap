extends RefCounted

# Turns raw touches into paws. Positions are millimetres. Every press acts at
# once. Contacts that stay put are resting pads: they never act again, and
# never stop another paw from acting. Holding two opposite corners is the
# human's way out.

const REST_AFTER := 0.5        # still for this long: a resting pad
const REST_SLOP := 4.0         # mm a resting pad may shift
const SWIPE_SPEED := 160.0     # mm/s: faster is a swipe, slower is stalking
const SWAT_GAP := 0.15         # pads of one paw land within this ...
const SWAT_SPAN := 40.0        # ... and this far apart
const CORNER := 20.0           # mm square that counts as a corner
const EXIT_HOLD := 2.0

class Touch:
	var pos := Vector2.ZERO
	var anchor := Vector2.ZERO   # where it last settled
	var still := 0.0
	var resting := false
	var swiped := false          # a swipe hits at most once per touch
	var corner := -1             # started and stayed in this one

var touches := {}              # index -> Touch
var bounds := Rect2()          # the usable window, mm
var swats := 0                 # paws, not pads
var exit_t := 0.0
var active_t := 0.0            # seconds with a moving or fresh paw on the glass

var _clock := 0.0
var _last_press := -10.0
var _last_pos := Vector2.ZERO


func clear() -> void:
	touches.clear()
	exit_t = 0.0


# true if this is a new paw rather than another pad of the last one
func press(index: int, p: Vector2) -> bool:
	var k := Touch.new()
	k.pos = p
	k.anchor = p
	k.corner = corner_at(p)
	touches[index] = k
	var fresh := _clock - _last_press > SWAT_GAP or p.distance_to(_last_pos) > SWAT_SPAN
	_last_press = _clock
	_last_pos = p
	if fresh:
		swats += 1
	return fresh


func release(index: int) -> void:
	touches.erase(index)


# what a drag amounts to: "swipe", "stalk", or "" (resting, or unknown)
func drag(index: int, p: Vector2, velocity: Vector2) -> String:
	if not touches.has(index):
		return ""
	var k: Touch = touches[index]
	k.pos = p
	if k.corner >= 0 and corner_at(p) != k.corner:
		k.corner = -1
	if p.distance_to(k.anchor) > REST_SLOP:
		k.anchor = p
		k.still = 0.0
		k.resting = false
	if k.resting:
		return ""
	if velocity.length() >= SWIPE_SPEED:
		return "" if k.swiped else "swipe"
	return "stalk" if k.still == 0.0 else ""


func step(dt: float) -> void:
	_clock += dt
	var moving := false
	for k: Touch in touches.values():
		k.still += dt
		if k.still >= REST_AFTER:
			k.resting = true
		moving = moving or not k.resting
	if moving:
		active_t += dt
	exit_t = exit_t + dt if _corners_held() else 0.0


func exit_wanted() -> bool:
	return exit_t >= EXIT_HOLD


# 0 top left, 1 top right, 2 bottom right, 3 bottom left, -1 none
func corner_at(p: Vector2) -> int:
	var left := p.x <= bounds.position.x + CORNER
	var right := p.x >= bounds.end.x - CORNER
	var top := p.y <= bounds.position.y + CORNER
	var bottom := p.y >= bounds.end.y - CORNER
	if top and left:
		return 0
	if top and right:
		return 1
	if bottom and right:
		return 2
	if bottom and left:
		return 3
	return -1


func _corners_held() -> bool:
	var held := [false, false, false, false]
	for k: Touch in touches.values():
		if k.corner >= 0:
			held[k.corner] = true
	return (held[0] and held[2]) or (held[1] and held[3])
