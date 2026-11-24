extends RefCounted

# The human's choices, kept on the device only.

const SIZES_MM: Array[float] = [28.0, 40.0, 55.0]   # body without tail

var path := "user://settings.cfg"
var palette := 0
var size := 1
var dpi := 0.0               # 0: what the device says
var sound := true


func load_file() -> void:
	var c := ConfigFile.new()
	if c.load(path) != OK:
		return
	palette = clampi(int(c.get_value("play", "palette", 0)), 0, 2)
	size = clampi(int(c.get_value("play", "size", 1)), 0, SIZES_MM.size() - 1)
	sound = bool(c.get_value("play", "sound", true))
	dpi = clampf(float(c.get_value("screen", "dpi", 0.0)), 0.0, 900.0)


func save_file() -> void:
	if path == "":
		return
	var c := ConfigFile.new()
	c.set_value("play", "palette", palette)
	c.set_value("play", "size", size)
	c.set_value("play", "sound", sound)
	c.set_value("screen", "dpi", dpi)
	c.save(path)
