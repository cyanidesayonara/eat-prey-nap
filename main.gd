extends Node2D

# Wires the parts: start screen <-> play. The simulation is in
# millimetres; input divides by ppm (pixels per mm) and the views multiply.
#
# On a PC: left button is a paw. Right click leaves a second paw resting
# where it is (right click again lifts it). Esc goes back to the start screen.
#
# Options after a "--": --play --watch --palette=N --size=N --dpi=N --seed=N

const Brain := preload("res://src/sim/mouse_brain.gd")
const Paws := preload("res://src/input/paws.gd")
const Screen := preload("res://src/screen.gd")
const Settings := preload("res://src/settings.gd")
const Palette := preload("res://src/view/palette.gd")
const MouseView := preload("res://src/view/mouse_view.gd")
const FieldView := preload("res://src/view/field_view.gd")
const MoundView := preload("res://src/view/mound_view.gd")
const StartView := preload("res://src/view/start_view.gd")

const MOUSE_LEFT := 1000     # touch indexes for the PC's mouse buttons
const MOUSE_RIGHT := 1001
const DPI_STEP := 2.0

var settings := Settings.new()
var brain := Brain.new()
var paws := Paws.new()
var world := Node2D.new()
var field := FieldView.new()
var prey := MouseView.new()
var mounds := MoundView.new()
var start := StartView.new()

var playing := false
var paused := false
var ppm := 4.0
var play_t := 0.0
var seed_value := -1
var _crumb_count := -1


func _ready() -> void:
	get_tree().quit_on_go_back = false
	# a press acts on its own event, not bundled with the frame's others
	Input.use_accumulated_input = false
	add_child(world)
	for n: Node2D in [field, prey, mounds]:
		world.add_child(n)
	add_child(start)
	start.settings = settings
	start.chosen.connect(choose)
	if DisplayServer.get_name() == "headless":
		settings.path = ""
	else:
		settings.load_file()
	var go := ""
	for a in OS.get_cmdline_user_args():
		if a == "--play" or a == "--watch":
			go = a.substr(2)
		elif a.begins_with("--palette="):
			settings.palette = clampi(int(a.get_slice("=", 1)), 0, Palette.ALL.size() - 1)
		elif a.begins_with("--size="):
			settings.size = clampi(int(a.get_slice("=", 1)), 0, Settings.SIZES_MM.size() - 1)
		elif a.begins_with("--dpi="):
			settings.dpi = float(a.get_slice("=", 1))
		elif a.begins_with("--seed="):
			seed_value = int(a.get_slice("=", 1))
	_use(brain)
	get_tree().root.size_changed.connect(relayout)
	relayout()
	to_start()
	if go != "":
		choose(go)


func _use(b: Brain) -> void:
	brain = b
	brain.setup(Rect2(0, 0, 270, 170), Settings.SIZES_MM[settings.size], seed_value)
	field.brain = b
	prey.brain = b
	mounds.brain = b


# --- layout -----------------------------------------------------------------

func relayout() -> void:
	ppm = Screen.px_per_mm(settings.dpi)
	var win := get_viewport_rect().size
	var ins := Screen.insets(get_window())
	var safe := Rect2(Vector2(ins.x, ins.y), win - Vector2(ins.x + ins.z, ins.y + ins.w))
	if safe.size.x < 1.0 or safe.size.y < 1.0:
		return               # a minimised window
	var safe_mm := Rect2(safe.position / ppm, safe.size / ppm)
	field.ppm = ppm
	prey.ppm = ppm
	mounds.ppm = ppm
	# a size change that changes nothing must not whisk the mouse away
	if brain.area != safe_mm or brain.length != Settings.SIZES_MM[settings.size]:
		brain.resize(safe_mm, Settings.SIZES_MM[settings.size])
	paws.bounds = safe_mm
	paws.clear()
	Sfx.enabled = settings.sound
	var pal: Dictionary = Palette.ALL[settings.palette]
	RenderingServer.set_default_clear_color(pal["field"])
	field.bounds = Rect2(Vector2.ZERO, win / ppm)
	field.pal = pal
	mounds.pal = pal
	prey.color = pal["prey"]
	prey.field = pal["field"]
	prey.reset_tail()
	field.queue_redraw()
	mounds.queue_redraw()
	start.ppm = ppm
	start.area = safe
	start.layout()


func to_start() -> void:
	if playing:
		start.report = "Last time: %d:%02d, %d paws, %d good tries, %d catches, paws busy %d s." % [
			int(play_t / 60.0), int(play_t) % 60, paws.swats,
			brain.difficulty.good_tries, brain.difficulty.catches, int(paws.active_t)]
	playing = false
	paws.clear()
	start.visible = true
	world.visible = false
	start.layout()


func to_play(watch: bool) -> void:
	var b := Brain.new()
	b.watch = watch
	_use(b)
	paws = Paws.new()
	play_t = 0.0
	playing = true
	relayout()
	start.visible = false
	world.visible = true


func choose(id: String) -> void:
	match id:
		"play":
			to_play(false)
			return
		"watch":
			to_play(true)
			return
		"quit":
			get_tree().quit()
			return
		"sound":
			settings.sound = not settings.sound
		"dpi-", "dpi+":
			var now := ppm * Screen.MM_PER_INCH
			settings.dpi = clampf(now + (DPI_STEP if id == "dpi+" else -DPI_STEP), 60.0, 900.0)
		_:
			if id.begins_with("palette"):
				settings.palette = int(id.trim_prefix("palette"))
			elif id.begins_with("size"):
				settings.size = int(id.trim_prefix("size"))
	relayout()
	settings.save_file()


# --- input ------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			paw_down(event.index, event.position)
		else:
			paws.release(event.index)      # a cancelled touch is a lifted one
	elif event is InputEventScreenDrag:
		paw_drag(event.index, event.position, event.relative, event.velocity)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				paw_down(MOUSE_LEFT, event.position)
			else:
				paws.release(MOUSE_LEFT)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and playing:
			if paws.touches.has(MOUSE_RIGHT):
				paws.release(MOUSE_RIGHT)
			else:
				paw_down(MOUSE_RIGHT, event.position)
	elif event is InputEventMouseMotion:
		paw_drag(MOUSE_LEFT, event.position, event.relative, event.velocity)
	elif event is InputEventKey and event.pressed and not event.echo:
		# a cat can walk over a tablet's keyboard, so keys work on a PC only
		if event.keycode == KEY_ESCAPE and playing and not OS.has_feature("mobile"):
			to_start()


func paw_down(index: int, px: Vector2) -> void:
	if not playing:
		start.press(px)
		return
	if paused:
		return
	var p := px / ppm
	paws.press(index, p)
	brain.press(p)
	_play_events()


func paw_drag(index: int, px: Vector2, relative: Vector2, velocity: Vector2) -> void:
	if not playing or paused:
		return
	var p := px / ppm
	match paws.drag(index, p, velocity / ppm):
		"swipe":
			if brain.swipe(p - relative / ppm, p) in ["pin", "slip"]:
				(paws.touches[index] as Paws.Touch).swiped = true
		"stalk":
			brain.stalk(p)
	_play_events()


# --- time -------------------------------------------------------------------

func _process(delta: float) -> void:
	if not playing:
		start.fps = Engine.get_frames_per_second()
		start.step(delta)
		return
	if paused:
		return
	play_t += delta
	paws.step(delta)
	if paws.exit_wanted():
		to_start()
		return
	brain.step(delta)
	prey.step(delta)
	_play_events()
	if brain.crumbs.size() != _crumb_count:
		_crumb_count = brain.crumbs.size()
		field.queue_redraw()


func _play_events() -> void:
	for e in brain.events:
		Sfx.play(e)
	brain.events.clear()


# --- the system -------------------------------------------------------------

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			on_back()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			on_pause()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_WM_WINDOW_FOCUS_IN:
			paused = false


# A cat swipes in from the edge all the time: Back does nothing during play.
func on_back() -> void:
	if not playing:
		choose("quit")


func on_pause() -> void:
	paused = true
	paws.clear()         # their releases may never arrive
