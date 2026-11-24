extends SceneTree

# Base for the headless tests: call check(), then finish().

var checks := 0
var failures := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + what)


func finish() -> void:
	print("%d checks, %d failed" % [checks, failures])
	quit(0 if failures == 0 and checks > 0 else 1)
