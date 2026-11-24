extends RefCounted

# Pixels to millimetres, and the safe area. Godot gives Android's density
# bucket, which is only close to the panel's real dpi, so the human can
# correct it against the ruler on the start screen (a saved override).

const MM_PER_INCH := 25.4
const FALLBACK_DPI := 96.0

static var test_insets := Vector4(-1, -1, -1, -1)


static func px_per_mm(override_dpi := 0.0) -> float:
	var dpi := override_dpi
	if dpi <= 0.0 and DisplayServer.get_name() != "headless":
		dpi = float(DisplayServer.screen_get_dpi())
	if dpi < 40.0:
		dpi = FALLBACK_DPI
	return dpi / MM_PER_INCH


# left, top, right, bottom, in pixels; zero off a phone or tablet
static func insets(win: Window) -> Vector4:
	if test_insets.x >= 0.0:
		return test_insets
	if win == null or not OS.has_feature("android"):
		return Vector4.ZERO
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var full := Rect2(Vector2(win.position), Vector2(win.size))
	if safe.size.x <= 0.0 or safe.size.y <= 0.0 or not safe.intersects(full):
		return Vector4.ZERO
	return Vector4(maxf(0.0, safe.position.x - full.position.x), maxf(0.0, safe.position.y - full.position.y),
		maxf(0.0, full.end.x - safe.end.x), maxf(0.0, full.end.y - safe.end.y))
