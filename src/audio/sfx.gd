extends Node

# Quiet, short, high sounds, synthesized at startup: no audio assets. The
# noise comes from a local generator and never touches the global seed.

const RATE := 44100
const POOL := 6

var players: Array[AudioStreamPlayer] = []
var lib := {}
var enabled := true
var rng := RandomNumberGenerator.new()
var _next := 0


func _ready() -> void:
	rng.seed = 0xCA7
	if DisplayServer.get_name() == "headless":
		return
	for i in range(POOL):
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	build()


func build() -> void:
	lib["rustle"] = wav(_rustle(0.22, 5))
	lib["dart"] = wav(_rustle(0.30, 9))
	lib["hide"] = wav(_rustle(0.12, 2))
	lib["sniff"] = wav(_rustle(0.10, 3), 0.4)
	lib["pin"] = wav(_squeak(0.10, 4200.0, 6200.0))
	lib["free"] = wav(_squeak(0.14, 5200.0, 7400.0))
	lib["slip"] = wav(_squeak(0.07, 5600.0, 6800.0))
	lib["caught"] = wav(_squeak(0.22, 5200.0, 3000.0))


func play(sound: String, vol_db := -14.0) -> void:
	if not enabled or players.is_empty() or not lib.has(sound):
		return
	var p := players[_next]
	_next = (_next + 1) % players.size()
	p.stream = lib[sound]
	p.volume_db = vol_db
	p.pitch_scale = rng.randf_range(0.92, 1.08)
	p.play()


# dry little scratches: bursts of brightened noise with soft edges
func _rustle(sec: float, scratches: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(sec * RATE))
	for _s in range(scratches):
		var at := rng.randi_range(0, int(out.size() * 0.75))
		var n := mini(int(RATE * rng.randf_range(0.012, 0.035)), out.size() - at)
		var amp := rng.randf_range(0.3, 0.8)
		var last := 0.0
		for i in range(n):
			var noise := rng.randf_range(-1.0, 1.0)
			out[at + i] += (noise - last) * 0.5 * amp * sin(PI * float(i) / n)
			last = noise
	return out


func _squeak(sec: float, from_hz: float, to_hz: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(sec * RATE))
	var phase := 0.0
	for i in range(out.size()):
		var f := float(i) / out.size()
		phase += TAU * lerpf(from_hz, to_hz, f) / RATE
		out[i] = sin(phase) * sin(PI * f) * 0.6
	return out


static func wav(samples: PackedFloat32Array, gain := 1.0) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		data.encode_s16(i * 2, int(clampf(samples[i] * gain, -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.data = data
	return s
