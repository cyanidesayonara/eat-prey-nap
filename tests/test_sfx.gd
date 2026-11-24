extends "res://tests/check.gd"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var s := root.get_node("Sfx")
	s.build()
	for k: String in ["rustle", "dart", "hide", "sniff", "pin", "free", "slip", "caught"]:
		var w: AudioStreamWAV = s.lib.get(k)
		check(w != null and w.data.size() > 1000, "%s is synthesized" % k)
	finish()
