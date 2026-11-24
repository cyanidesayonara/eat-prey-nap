extends SceneTree

# Photographs the start screen, and each state of the chase in each palette
# and size, into shots/ (gitignored). Needs a display:
#   godot --path . --script res://tools/shots.gd

const Brain := preload("res://src/sim/mouse_brain.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var m: Node2D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(m)
	m.settings.path = ""     # leave the human's settings alone
	m.settings.dpi = 120.0
	m.seed_value = 6
	m.set_process(false)
	m.relayout()
	await _shot("start")
	for pal in range(3):
		for size in range(3):
			m.settings.palette = pal
			m.settings.size = size
			m.to_play(false)
			var got := {}
			for i in range(60 * 90):
				m.paused = false
				m._process(1.0 / 60.0)
				var b: Brain = m.brain
				var key: String = Brain.NAMES[b.state]
				if b.state == Brain.TELL:
					key += "_tail" if b.tell_tail else "_ears"
				if not got.has(key) and b.t > 0.2 and (size == 1 or b.state in [Brain.CREEP, Brain.FREEZE]):
					got[key] = true
					if pal == 0 or b.state == Brain.CREEP:
						await _shot("p%d_s%d_%s" % [pal, size, key])
				if size == 1 and got.size() >= 7 and b.state == Brain.FREEZE:
					b._will_catch = true
					b._go(Brain.PINNED, 0.4)
	quit()


func _shot(shot_name: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://shots/%s.png" % shot_name)
