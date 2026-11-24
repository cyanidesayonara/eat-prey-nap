extends "res://tests/check.gd"

# Cat sight: strong brightness contrast for the prey, in daylight and by rods;
# everything else faint; no colour near a cat's neutral point.

const Palette := preload("res://src/view/palette.gd")


func _initialize() -> void:
	check(Palette.ALL.size() == 3, "three palettes to compare")
	for p in Palette.ALL:
		var n: String = p["name"]
		for rods: bool in [false, true]:
			var c := {}
			for k: String in ["border", "mound", "lip", "crumb", "prey"]:
				c[k] = Palette.contrast(_lum(p[k], rods), _lum(p["field"], rods))
			var how := "%s (%s)" % [n, "rods" if rods else "daylight"]
			check(c["prey"] >= 6.0, "%s: prey stands out %.1f" % [how, c["prey"]])
			check(c["border"] < 1.35, "%s: border is faint %.2f" % [how, c["border"]])
			for k: String in ["mound", "lip", "crumb"]:
				check(c[k] < c["prey"] * 0.5, "%s: %s stays under the prey %.2f" % [how, k, c[k]])
		for k: String in ["field", "border", "mound", "lip", "crumb", "prey"]:
			var col: Color = p[k]
			var teal := col.s > 0.15 and col.h > 0.20 and col.h < 0.58
			var red := col.s > 0.15 and (col.h < 0.10 or col.h > 0.72)
			check(not teal and not red, "%s: %s is grey, blue or yellow" % [n, k])
	finish()


func _lum(c: Color, rods: bool) -> float:
	return Palette.rod_luminance(c) if rods else Palette.luminance(c)
