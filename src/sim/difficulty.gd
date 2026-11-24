extends RefCounted

# Difficulty follows recent catches. A "good try" is a paw that lands on the
# mouse. About one in three is a catch to start with; catching more than that
# makes the next catch less likely and the mouse quicker, catching fewer does
# the opposite. A long run of good tries without a catch always ends in one.

const TARGET := 1.0 / 3.0
const WINDOW := 9            # good tries remembered
const GAIN := 0.9            # how hard the chance leans back towards TARGET
const MIN_CHANCE := 0.15
const MAX_CHANCE := 0.75
const MERCY := 5             # this many misses in a row: the next is a catch

var recent: Array[bool] = []
var good_tries := 0
var catches := 0
var dry := 0                 # good tries since the last catch


# the share of recent good tries that were catches; the unfilled part of the
# window counts as being on target, so one early result does not swing it
func rate() -> float:
	var n := 0.0
	for r in recent:
		n += 1.0 if r else 0.0
	return (n + float(WINDOW - recent.size()) * TARGET) / float(WINDOW)


func chance() -> float:
	if dry >= MERCY:
		return 1.0
	return clampf(TARGET + (TARGET - rate()) * GAIN, MIN_CHANCE, MAX_CHANCE)


# Multiplies the mouse's speed: above 1 when the cat is catching a lot.
func pace() -> float:
	return clampf(1.0 + (rate() - TARGET) * 0.6, 0.8, 1.25)


func record(caught: bool) -> void:
	good_tries += 1
	recent.append(caught)
	if recent.size() > WINDOW:
		recent.pop_front()
	if caught:
		catches += 1
		dry = 0
	else:
		dry += 1
