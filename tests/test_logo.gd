extends "res://tests/check.gd"

# The logo: the game's numbers are the website's, every frame can be drawn,
# and it is nowhere in play.

const Poses := preload("res://src/view/logo_poses.gd")
const LogoView := preload("res://src/view/logo_view.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var js := FileAccess.get_file_as_string("res://site/logo.js")
	var text := js.get_slice("/* LOGO-BEGIN */", 1).get_slice("/* LOGO-END */", 0)
	text = text.substr(text.find("{"), text.rfind("}") - text.find("{") + 1)
	var web: Variant = JSON.parse_string(text)
	var game: Variant = JSON.parse_string(JSON.stringify(Poses.LOGO))
	check(web is Dictionary and web == game, "site/logo.js and logo_poses.gd hold the same numbers")

	var total := LogoView.total()
	var words := {}
	var jump := 0.0
	var last := PackedVector2Array()
	for i in range(int(total * 120.0) + 2):
		var p := LogoView.curl(LogoView.pose(i / 120.0), i / 120.0)
		for w in range(3):
			if p["words"][w] > 0.99:
				words[w] = true
		var now := LogoView.shape(p)
		if last.size() == now.size() and p["change"] > 0.0:
			for k in range(now.size()):
				jump = maxf(jump, minf(now[k].distance_to(last[k]), 1000.0))
		last = now
	check(words.size() == 3, "eat, prey and nap all come up")
	check(jump < 20.0, "the badge turns without a jump (%.1f)" % jump)
	for word in range(3):
		check(absf(LogoView.spin({"change": 1.0, "from": word, "to": 0}) - TAU) < 0.001, "a change is one full turn")

	var m: Node2D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(m)
	await process_frame
	m.paused = false
	check(m.start.logo.is_visible_in_tree(), "the logo is on the start screen")
	m.choose("play")
	check(not m.start.logo.is_visible_in_tree(), "and not in play")
	var before: float = m.start.logo.sec
	m._process(0.5)
	check(m.start.logo.sec == before, "where it does not even run")
	m.free()
	await process_frame
	finish()
