extends SceneTree

# Photographs the game for the website, into site/img/. Needs a display:
#   godot --path . --script res://tools/site_media.gd
# Rerun after a visual change and commit the result; never edit the images.

const Brain := preload("res://src/sim/mouse_brain.gd")

var m: Node2D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 800)
	m = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(m)
	m.settings.path = ""     # leave the human's settings alone
	m.settings.dpi = 120.0
	m.seed_value = 6
	m.set_process(false)
	await _pose("sniff", 0, Brain.SNIFF, Vector2(0.5, 0.55), -0.35)
	await _pose("ears", 0, Brain.TELL, Vector2.ZERO, 0.0)
	await _pose("ink", 1, Brain.FREEZE, Vector2(0.52, 0.5), 0.5)
	await _pose("grey", 2, Brain.FREEZE, Vector2(0.48, 0.5), -2.7)
	var icon := Image.load_from_file(ProjectSettings.globalize_path("res://icon.png"))
	icon.save_png("res://site/img/icon.png")
	quit()


func _pose(shot: String, palette: int, state: int, at: Vector2, heading: float) -> void:
	m.settings.palette = palette
	m.settings.size = 2 if state != Brain.TELL else 1
	m.to_play(false)
	var b: Brain = m.brain
	b.state = state
	b.heading = heading
	if state == Brain.TELL:
		b.mound = 0
		b.pos = b.mounds[0]
		b.out_dir = Vector2.RIGHT.rotated(-0.3)
		b.t = 0.6
	else:
		b.pos = b.area.position + b.area.size * at
		b.tail_out = 1.0
		# a curled tail, like the icon's
		m.prey.tail.resize(m.prey.TAIL_N)
		var p := b.pos - b.dir() * b.length * Brain.RUMP
		for i in range(m.prey.TAIL_N):
			m.prey.tail[i] = p
			p += (-b.dir()).rotated(-0.14 * i) * b.length * Brain.TAIL_LEN / (m.prey.TAIL_N - 1)
	m.prey.queue_redraw()
	for i in range(3):
		await process_frame
	root.get_texture().get_image().save_png("res://site/img/%s.png" % shot)
