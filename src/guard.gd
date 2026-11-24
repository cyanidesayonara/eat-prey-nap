extends RefCounted

# Keeps the cat in the game while it plays.
#
# Android: screen pinning (no permission). The system asks the human once per
# session; pinned, Home and Recents do nothing. Leaving play unpins.
# Web: site/guard.js (fullscreen, Back, closing the tab, screen on).
# PC: fullscreen.

static var _pinned := false
static var _activity: Object       # kept alive while the UI thread calls back
static var _job: Object


static func can_pin() -> bool:
	return OS.has_feature("android") and Engine.has_singleton("AndroidRuntime")


static func enter(pin: bool) -> void:
	if OS.has_feature("web"):
		_js("on")
	elif can_pin():
		if pin:
			_pin(true)
	elif not OS.has_feature("mobile") and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


static func leave() -> void:
	if OS.has_feature("web"):
		_js("off")
	elif can_pin():
		if _pinned:
			_pin(false)
	elif not OS.has_feature("mobile") and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


static func _js(what: String) -> void:
	JavaScriptBridge.eval("window.EPNGuard && window.EPNGuard.%s()" % what, true)


# startLockTask and stopLockTask have to run on Android's UI thread
static func _pin(on: bool) -> void:
	var runtime := Engine.get_singleton("AndroidRuntime")
	_activity = runtime.getActivity()
	if _activity == null:
		return
	_pinned = on
	var activity := _activity
	_job = runtime.createRunnableFromGodotCallable(func() -> void:
		if on:
			activity.startLockTask()
		else:
			activity.stopLockTask())
	_activity.runOnUiThread(_job)
