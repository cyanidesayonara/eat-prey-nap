extends SceneTree

# Generates icon.png, the Android adaptive icon layers and the website's
# copy: the logo's curled-up cat. Run it, do not hand-edit the output, then
# run tools/make_ico.py for the Windows icon:
#   godot --path . --script res://tools/make_icon.gd
# Drawn big by the game's own logo view, then scaled down.

const LogoView := preload("res://src/view/logo_view.gd")
const Palette := preload("res://src/view/palette.gd")
const SS := 4
const CORNER := 0.22


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://store/android"))
	var icon := await _render(256, 1.32, true, true)
	_round(icon, 256 * CORNER)
	var errs := [
		icon.save_png("res://icon.png"),
		icon.save_png("res://site/img/icon.png"),
		(await _render(432, 1.0, true, false)).save_png("res://store/android/icon_background.png"),
		# inside the 66 of 108 that every launcher's mask leaves
		(await _render(432, 0.84, false, true)).save_png("res://store/android/icon_foreground.png"),
	]
	print("icons: ", errs)
	quit(0 if errs.max() == OK else 1)


func _render(px: int, k: float, paint_field: bool, paint_cat: bool) -> Image:
	var pal: Dictionary = Palette.ALL[0]
	var vp := SubViewport.new()
	vp.size = Vector2i(px, px) * SS
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	if paint_field:
		var bg := ColorRect.new()
		bg.color = pal["prey"]
		bg.size = Vector2(vp.size)
		vp.add_child(bg)
	if paint_cat:
		var v := LogoView.new()
		v.curled = true
		v.ink = pal["prey"]
		v.field = pal["field"]
		v.width = px * SS * k
		v.position = Vector2(vp.size) * 0.5
		vp.add_child(v)
	for i in range(3):
		await process_frame
	var img := vp.get_texture().get_image()
	img.resize(px, px, Image.INTERPOLATE_LANCZOS)
	img.convert(Image.FORMAT_RGBA8)
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
