extends Node
## Âm thanh tổng hợp bằng code (không dùng file ngoài): nhạc nền đêm + hiệu ứng.

const RATE := 22050
# tên: [các nốt Hz, độ dài mỗi nốt (s), dạng sóng, âm lượng]
const DEFS := {
	"pick": [[880.0, 1320.0], 0.06, "sine", 0.35],
	"lit": [[523.0, 659.0, 784.0, 1046.0], 0.12, "sine", 0.45],
	"pulse": [[220.0, 440.0, 660.0], 0.08, "tri", 0.5],
	"hit": [[180.0, 120.0], 0.12, "square", 0.35],
	"jump": [[392.0, 587.0], 0.05, "tri", 0.3],
	"dash": [[300.0, 900.0], 0.05, "noise", 0.25],
	"win": [[523.0, 659.0, 784.0, 659.0, 1046.0], 0.16, "sine", 0.5],
	"lose": [[392.0, 330.0, 262.0, 196.0], 0.22, "tri", 0.45],
	"spawn": [[110.0, 98.0], 0.2, "square", 0.25],
	"tick": [[1200.0], 0.05, "square", 0.25],
	"wind": [[200.0, 260.0, 200.0], 0.25, "noise", 0.3],
	"out": [[330.0, 247.0, 165.0], 0.14, "tri", 0.4],
}

var players := {}
var bus_db := 0.0
var music_player: AudioStreamPlayer


func _ready() -> void:
	for k in DEFS:
		var p := AudioStreamPlayer.new()
		p.stream = _make(DEFS[k][0], DEFS[k][1], DEFS[k][2], DEFS[k][3])
		add_child(p)
		players[k] = p


func set_volume(v: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(max(v, 0.0001)))


func play(name: String) -> void:
	if players.has(name):
		players[name].play()


## Nhạc nền: hợp âm rải chậm, lặp vô hạn.
func music() -> void:
	var notes := [220.0, 261.6, 329.6, 392.0, 329.6, 261.6, 196.0, 246.9, 293.7, 349.2, 293.7, 246.9]
	var s := _make(notes, 0.5, "sine", 0.12, true)
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_end = int(notes.size() * 0.5 * RATE)
	music_player = AudioStreamPlayer.new()
	music_player.stream = s
	add_child(music_player)
	music_player.play()


func _make(notes: Array, dur: float, wave: String, vol: float, soft := false) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(notes.size() * n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var i := 0
	for f in notes:
		for k in n:
			var t := float(k) / RATE
			var ph := fmod(t * f, 1.0)
			var v := 0.0
			match wave:
				"sine": v = sin(TAU * ph)
				"tri": v = 4.0 * absf(ph - 0.5) - 1.0
				"square": v = 1.0 if ph < 0.5 else -1.0
				"noise": v = rng.randf_range(-1.0, 1.0) * 0.6 + sin(TAU * ph) * 0.4
			var env := minf(1.0, k / (RATE * 0.005)) * (1.0 - float(k) / n) if not soft else sin(PI * float(k) / n)
			data.encode_s16(i * 2, int(clampf(v * env * vol, -1.0, 1.0) * 32767))
			i += 1
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.data = data
	return s
