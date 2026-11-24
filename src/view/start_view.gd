extends Node2D

# The start screen, for the human: pick a mode, palette, size; check the
# ruler. Draws in pixels and takes presses from main.gd, so touch and mouse
# work alike without emulation.

const Palette := preload("res://src/view/palette.gd")
const Settings := preload("res://src/settings.gd")
const LogoView := preload("res://src/view/logo_view.gd")

const ROW := 9.0             # mm, a button's height at most
const GAP := 2.5
const WIDTH := 150.0
const LOGO := 30.0           # mm across, beside the title

signal chosen(action: String)

var settings: Settings
var ppm := 4.0
var area := Rect2()          # usable pixels
var report := ""
var fps := 0.0
var buttons: Array[Dictionary] = []   # {id, label, rect, on}
var can_pin := false         # Android only
var logo := LogoView.new()


func _ready() -> void:
	add_child(logo)


func step(dt: float) -> void:
	logo.step(dt)
	queue_redraw()


func layout() -> void:
	buttons.clear()
	# mm, shrunk on small screens
	var m := minf(ppm, minf(area.size.y / 122.0, area.size.x / (WIDTH + 10.0)))
	var rows := [[["play", "Play", false], ["watch", "Watch only", false]]]
	for i in range(Palette.ALL.size()):
		rows.append([["palette%d" % i, Palette.ALL[i]["name"], settings.palette == i]])
	var sizes := []
	for i in range(Settings.SIZES_MM.size()):
		sizes.append(["size%d" % i, "%d mm" % int(Settings.SIZES_MM[i]), settings.size == i])
	rows.append(sizes)
	var last := [["dpi-", "Ruler shorter", false], ["dpi+", "Ruler longer", false],
		["sound", "Sound on" if settings.sound else "Sound off", settings.sound]]
	if can_pin:
		last.append(["pin", "Pinning on" if settings.pin else "Pinning off", settings.pin])
	# a web page cannot close itself
	if not OS.has_feature("web"):
		last.append(["quit", "Quit", false])
	rows.append(last)
	var x := area.get_center().x - WIDTH * 0.5 * m
	var y := area.position.y + (LOGO + 3.0) * m
	var pal: Dictionary = Palette.ALL[settings.palette]
	logo.ink = pal["prey"]
	logo.field = pal["field"]
	logo.soft = pal["crumb"]
	logo.width = LOGO * m
	logo.position = Vector2(x + LOGO * 0.5 * m, area.position.y + (LOGO * 0.5 + 1.5) * m)
	logo.queue_redraw()
	for items: Array in rows:
		var w := (WIDTH - GAP * (items.size() - 1)) / items.size()
		for i in range(items.size()):
			buttons.append({"id": items[i][0], "label": items[i][1], "on": items[i][2],
				"rect": Rect2(x + i * (w + GAP) * m, y, w * m, ROW * m)})
		y += (ROW + GAP) * m
	queue_redraw()


func press(p: Vector2) -> void:
	for b in buttons:
		if (b["rect"] as Rect2).has_point(p):
			chosen.emit(b["id"])
			return


func _draw() -> void:
	if buttons.is_empty():
		return
	var pal: Dictionary = Palette.ALL[settings.palette]
	var first: Rect2 = buttons[0]["rect"]
	var h := first.size.y
	var left := first.position.x
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), pal["field"])
	_text(logo.position + Vector2(logo.width * 0.62, h * 0.4), "Eat Prey Nap", int(h * 1.15), pal["prey"])
	for b in buttons:
		var r: Rect2 = b["rect"]
		draw_rect(r, pal["prey"] if b["on"] else pal["mound"])
		var fs := int(h * 0.42)
		var w := ThemeDB.fallback_font.get_string_size(b["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_text(r.get_center() + Vector2(-w * 0.5, fs * 0.36), b["label"], fs, pal["field"] if b["on"] else pal["prey"])
	var y: float = (buttons[-1]["rect"] as Rect2).end.y + h * 0.5
	draw_rect(Rect2(left, y, 50.0 * ppm, h * 0.15), pal["prey"])
	var small := int(h * 0.36)
	_text(Vector2(left, y + h * 0.65), "The bar above should measure 50 mm. Drawing %d frames a second." % roundi(fps), small, pal["prey"])
	_text(Vector2(left, y + h * 1.2), "To leave the game, hold two opposite corners for 2 seconds%s." % ("" if OS.has_feature("mobile") else ", or hold Esc"), small, pal["prey"])
	_text(Vector2(left, y + h * 1.75), report, small, pal["prey"])


func _text(at: Vector2, s: String, fs: int, col: Color) -> void:
	draw_string(ThemeDB.fallback_font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(fs, 6), col)
