extends RefCounted

# Three fields to compare, for a cat's eyes: brightness contrast first, then
# blue against yellow. Nothing depends on red against green, nothing is teal
# (about 505 nm looks grey to a cat). tests/test_palette.gd holds them to it.
# Only the prey stands out; border, mounds and crumbs stay close to the field.

const ALL: Array[Dictionary] = [
	{"name": "Straw field, ink-blue mouse", "field": Color("e9d9a0"), "border": Color("d9c789"),
		"mound": Color("c8b06c"), "lip": Color("b59c58"), "crumb": Color("b1954c"), "prey": Color("121b48")},
	{"name": "Ink-blue field, pale-yellow mouse", "field": Color("152150"), "border": Color("1c2959"),
		"mound": Color("2d3b78"), "lip": Color("3b4a8a"), "crumb": Color("475697"), "prey": Color("f6ebb4")},
	{"name": "Grey field, near-black mouse", "field": Color("979797"), "border": Color("888888"),
		"mound": Color("767676"), "lip": Color("696969"), "crumb": Color("646464"), "prey": Color("0b0b0e")},
]


# relative luminance as a person's daylight eyes weigh it (WCAG)
static func luminance(c: Color) -> float:
	var l := c.srgb_to_linear()
	return 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b


# and as rods do, which cats lean on far more (Larson's approximation, for
# human rods, which peak close to a cat's)
static func rod_luminance(c: Color) -> float:
	var l := c.srgb_to_linear()
	var x := 0.4124 * l.r + 0.3576 * l.g + 0.1805 * l.b
	var y := luminance(c)
	var z := 0.0193 * l.r + 0.1192 * l.g + 0.9505 * l.b
	return maxf(0.0, y * (1.33 * (1.0 + (y + z) / maxf(x, 0.00001)) - 1.68))


static func contrast(a: float, b: float) -> float:
	return (maxf(a, b) + 0.05) / (minf(a, b) + 0.05)
