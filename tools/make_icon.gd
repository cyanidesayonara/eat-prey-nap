extends SceneTree

# Generates icon.png and the Android adaptive icon layers. Run it, do not
# hand-edit the output:
#   godot --path . --script res://tools/make_icon.gd
# Drawn big by the game's own mouse view, then scaled down, because Godot's
# 2D polygons are not fully antialiased.

const Brain := preload("res://src/sim/mouse_brain.gd")
const MouseView := preload("res://src/view/mouse_view.gd")
const Palette := preload("res://src/view/palette.gd")
const SS := 4
const CORNER := 0.12


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://store/android"))
	var errs := [
		(await _render(256, 1.0, true, true)).save_png("res://icon.png"),
		(await _render(432, 1.0, true, false)).save_png("res://store/android/icon_background.png"),
		(await _render(432, 0.62, false, true)).save_png("res://store/android/icon_foreground.png"),
	]
	print("icons: ", errs)
	quit(0 if errs.max() == OK else 1)


func _render(px: int, k: float, paint_field: bool, paint_mouse: bool) -> Image:
	var pal: Dictionary = Palette.ALL[0]
	var vp := SubViewport.new()
	vp.size = Vector2i(px, px) * SS
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	if paint_field:
		var bg := ColorRect.new()
		bg.color = pal["field"]
		bg.size = Vector2(vp.size)
		vp.add_child(bg)
	if paint_mouse:
		var b := Brain.new()
		b.setup(Rect2(0, 0, 400, 400), 60.0, 1)
		b.state = Brain.FREEZE
		b.tail_out = 1.0
		b.pos = Vector2.ZERO
		b.heading = -PI * 0.25
		var v := MouseView.new()
		v.brain = b
		v.color = pal["prey"]
		v.field = pal["field"]
		# a curled tail, so it reads at 48 px
		v.tail.resize(MouseView.TAIL_N)
		var p := -b.dir() * b.length * 0.36
		for i in range(MouseView.TAIL_N):
			v.tail[i] = p
			p += (-b.dir()).rotated(-0.20 * i) * b.length * 0.075
		v.ppm = float(px * SS) / 100.0 * k
		v.position = Vector2(vp.size) * 0.5 + Vector2(10.0, -10.0) * v.ppm
		vp.add_child(v)
	for i in range(3):
		await process_frame
	var img := vp.get_texture().get_image()
	img.resize(px, px, Image.INTERPOLATE_LANCZOS)
	img.convert(Image.FORMAT_RGBA8)
	if paint_field and paint_mouse:
		_round(img, px * CORNER)
	vp.queue_free()
	return img


func _round(img: Image, r: float) -> void:
	var n := img.get_width()
	for y in range(n):
		for x in range(n):
			var c := Vector2(x + 0.5, y + 0.5)
			var d := c.distance_to(c.clamp(Vector2(r, r), Vector2(n - r, n - r)))
			if d > r - 0.5:
				var col := img.get_pixel(x, y)
				col.a *= clampf(r + 0.5 - d, 0.0, 1.0)
				img.set_pixel(x, y, col)
