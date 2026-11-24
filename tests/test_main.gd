extends "res://tests/check.gd"

# The whole scene: start screen, play through real input events, the exit,
# Back, pausing, safe area, and what the export promises.

const Screen := preload("res://src/screen.gd")
const Brain := preload("res://src/sim/mouse_brain.gd")

var m: Node2D


func _initialize() -> void:
	call_deferred("_run")


func _touch(i: int, px: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = px
	e.pressed = down
	m._input(e)


func _click(button: int, px: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.position = px
	e.pressed = down
	m._input(e)


func _tap_button(id: String) -> void:
	for b: Dictionary in m.start.buttons:
		if b["id"] == id:
			_touch(0, (b["rect"] as Rect2).get_center(), true)
			_touch(0, Vector2.ZERO, false)
			return
	check(false, "button %s exists" % id)


func _run() -> void:
	root.size = Vector2i(1280, 800)
	m = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(m)
	await process_frame
	m.set_process(false)
	m.paused = false
	check(not quit_on_go_back, "Back does not quit by itself")
	check(m.start.visible and not m.playing, "opens on the start screen")
	var screen := Rect2(Vector2.ZERO, m.get_viewport_rect().size)
	for b: Dictionary in m.start.buttons:
		check(screen.encloses(b["rect"]), "button %s is on screen" % b["id"])
		check(not (b["rect"] as Rect2).intersects(Rect2(m.start.logo.position - Vector2.ONE * m.start.logo.width * 0.5, Vector2.ONE * m.start.logo.width)), "the logo is clear of button %s" % b["id"])

	_tap_button("palette1")
	_tap_button("size2")
	check(m.settings.palette == 1 and m.settings.size == 2, "palette and size are chosen")
	check(is_equal_approx(m.brain.length, 55.0), "the prey takes that size in mm (%.1f)" % m.brain.length)
	m.seed_value = 3
	_tap_button("play")
	check(m.playing and not m.start.visible, "plays")

	# a touch acts during its own event
	_run_until_sniff()
	_touch(0, m.brain.pos * m.ppm, true)
	check(m.brain.difficulty.good_tries == 1, "a touch on the mouse is a good try at once")
	_touch(0, Vector2.ZERO, false)

	m.on_back()
	check(m.playing, "Back does nothing during play")

	# pausing drops paws and stops time
	_touch(3, Vector2(300, 300), true)
	m.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var t: float = m.play_t
	m._process(0.5)
	check(m.paused and m.paws.touches.is_empty() and m.play_t == t, "pauses in the background")
	m.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	m._process(0.016)
	check(m.play_t > t, "and goes on")

	# the corners, through real touches
	var win: Vector2 = m.get_viewport_rect().size
	_touch(0, Vector2(8, 8), true)
	_touch(1, win - Vector2(8, 8), true)
	for i in range(125):
		m._process(1.0 / 60.0)
	check(not m.playing and m.start.visible, "two corners leave to the start screen")

	# and on a PC: right click leaves a paw in one corner, left holds the other
	m.paws.clear()
	_tap_button("play")
	_click(MOUSE_BUTTON_RIGHT, Vector2(8, 8), true)
	_click(MOUSE_BUTTON_RIGHT, Vector2(8, 8), false)
	_click(MOUSE_BUTTON_LEFT, win - Vector2(8, 8), true)
	for i in range(125):
		m._process(1.0 / 60.0)
	check(not m.playing, "the corners work with a mouse too")

	_tap_button("play")
	_run_until_sniff()
	_click(MOUSE_BUTTON_LEFT, m.brain.pos * m.ppm, true)
	check(m.brain.difficulty.good_tries == 1, "a click on the mouse is a good try")
	_click(MOUSE_BUTTON_LEFT, Vector2.ZERO, false)

	# safe area
	Screen.test_insets = Vector4(60, 30, 40, 20)
	m.relayout()
	check(m.brain.area.position.is_equal_approx(Vector2(60, 30) / m.ppm), "prey keeps inside the safe area")
	check(m.paws.bounds == m.brain.area, "and so do the exit corners")
	Screen.test_insets = Vector4(-1, -1, -1, -1)

	_export_promises()
	m.free()
	await process_frame
	finish()


func _run_until_sniff() -> void:
	for i in range(60 * 60):
		m._process(1.0 / 60.0)
		if m.brain.state == Brain.SNIFF:
			return
	check(false, "reached a sniff")


func _export_promises() -> void:
	var cfg := FileAccess.get_file_as_string("res://export_presets.cfg")
	check("permissions/internet=false" in cfg, "no internet permission")
	var granted := RegEx.create_from_string("permissions/\\w+=true")
	check(granted.search(cfg) == null, "no permissions at all")
	check('platform="Web"' in cfg and 'platform="Windows Desktop"' in cfg, "itch's web and Windows presets")
	check("variant/thread_support=false" in cfg, "the web build needs no special headers")
	check('min_sdk="24"' in cfg and 'target_sdk="36"' in cfg, "minSdk 24, targetSdk 36")
	check(int(ProjectSettings.get_setting("display/window/handheld/orientation")) == 4, "landscape, either way up")
	check(int(ProjectSettings.get_setting("application/run/max_fps")) == 0, "no frame cap")
	check(bool(ProjectSettings.get_setting("rendering/textures/vram_compression/import_etc2_astc")), "Android textures")
	for f: String in ["icon_foreground.png", "icon_background.png"]:
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://store/android/" + f))
		check(img != null and img.get_size() == Vector2i(432, 432), f + " is 432x432")
