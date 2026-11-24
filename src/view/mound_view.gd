extends Node2D

# The hiding places: plain soft mounds, drawn over the mouse so that it
# really goes underneath.

const Brain := preload("res://src/sim/mouse_brain.gd")

var brain: Brain
var pal: Dictionary
var ppm := 4.0


func _draw() -> void:
	if pal.is_empty():
		return
	for m in brain.mounds:
		draw_circle(m * ppm, brain.mound_r * ppm, pal["mound"], true, -1.0, true)
		draw_circle(m * ppm, (brain.mound_r - 0.6) * ppm, pal["lip"], false, 1.2 * ppm, true)
