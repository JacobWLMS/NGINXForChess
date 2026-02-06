extends Node

## Procedural audio manager - generates all sounds from code, no assets needed

var sample_rate := 44100.0
var master_volume := 0.7

# Pre-generated audio streams
var sfx_merge: AudioStreamWAV
var sfx_drop: AudioStreamWAV
var sfx_combo: AudioStreamWAV
var sfx_gameover: AudioStreamWAV
var sfx_button: AudioStreamWAV
var sfx_coin: AudioStreamWAV
var sfx_powerup: AudioStreamWAV
var sfx_highmerge: AudioStreamWAV

var players: Array[AudioStreamPlayer] = []
const MAX_PLAYERS := 8

func _ready() -> void:
	# Create a pool of audio players
	for i in range(MAX_PLAYERS):
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		players.append(p)

	# Generate all sound effects procedurally
	sfx_merge = _gen_merge_sound()
	sfx_drop = _gen_drop_sound()
	sfx_combo = _gen_combo_sound()
	sfx_gameover = _gen_gameover_sound()
	sfx_button = _gen_button_sound()
	sfx_coin = _gen_coin_sound()
	sfx_powerup = _gen_powerup_sound()
	sfx_highmerge = _gen_highmerge_sound()

func play(sfx: AudioStreamWAV, pitch_scale := 1.0) -> void:
	for p in players:
		if not p.playing:
			p.stream = sfx
			p.pitch_scale = pitch_scale
			p.volume_db = linear_to_db(master_volume)
			p.play()
			return

func play_merge(tier: int) -> void:
	# Higher tiers = higher pitch = more satisfying
	var pitch = 0.8 + tier * 0.12
	if tier >= 7:
		play(sfx_highmerge, pitch)
	else:
		play(sfx_merge, pitch)

func play_drop() -> void:
	play(sfx_drop, randf_range(0.9, 1.1))

func play_combo(combo_level: int) -> void:
	play(sfx_combo, 0.8 + combo_level * 0.15)

func play_gameover() -> void:
	play(sfx_gameover)

func play_button() -> void:
	play(sfx_button)

func play_coin() -> void:
	play(sfx_coin, randf_range(0.95, 1.05))

func play_powerup() -> void:
	play(sfx_powerup)

# --- Procedural sound generation ---

func _make_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(sample_rate)
	wav.stereo = false

	var data = PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		var s = clampf(samples[i], -1.0, 1.0)
		var val = int(s * 32767.0)
		data[i * 2] = val & 0xFF
		data[i * 2 + 1] = (val >> 8) & 0xFF
	wav.data = data
	return wav

func _gen_merge_sound() -> AudioStreamWAV:
	# Satisfying pop/pling sound
	var length := 0.15
	var num_samples := int(sample_rate * length)
	var samples := PackedFloat32Array()
	samples.resize(num_samples)
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var env = exp(-t * 25.0)
		var freq = 880.0 + 440.0 * (1.0 - t / length)
		samples[i] = sin(t * freq * TAU) * env * 0.6
		samples[i] += sin(t * freq * 2.0 * TAU) * env * 0.2
	return _make_wav(samples)

func _gen_drop_sound() -> AudioStreamWAV:
	# Soft thud
	var length := 0.08
	var num_samples := int(sample_rate * length)
	var samples := PackedFloat32Array()
	samples.resize(num_samples)
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var env = exp(-t * 40.0)
		samples[i] = sin(t * 200.0 * TAU) * env * 0.4
	return _make_wav(samples)

func _gen_combo_sound() -> AudioStreamWAV:
	# Rising arpeggio
	var length := 0.25
	var num_samples := int(sample_rate * length)
	var samples := PackedFloat32Array()
	samples.resize(num_samples)
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var env = exp(-t * 8.0)
		var freq = 440.0 + 880.0 * (t / length)
		samples[i] = sin(t * freq * TAU) * env * 0.5
		samples[i] += sin(t * freq * 1.5 * TAU) * env * 0.2
	return _make_wav(samples)

func _gen_gameover_sound() -> AudioStreamWAV:
	# Descending sad sound
	var length := 0.6
	var num_samples := int(sample_rate * length)
	var samples := PackedFloat32Array()
	samples.resize(num_samples)
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var env = exp(-t * 3.0)
		var freq = 440.0 - 200.0 * (t / length)
		samples[i] = sin(t * freq * TAU) * env * 0.5
	return _make_wav(samples)

func _gen_button_sound() -> AudioStreamWAV:
	# Quick click
	var length := 0.05
	var num_samples := int(sample_rate * length)
	var samples := PackedFloat32Array()
	samples.resize(num_samples)
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var env = exp(-t * 60.0)
		samples[i] = sin(t * 1200.0 * TAU) * env * 0.3
	return _make_wav(samples)

func _gen_coin_sound() -> AudioStreamWAV:
	# Coin ching
	var length := 0.12
	var num_samples := int(sample_rate * length)
	var samples := PackedFloat32Array()
	samples.resize(num_samples)
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var env = exp(-t * 20.0)
		samples[i] = sin(t * 1500.0 * TAU) * env * 0.3
		samples[i] += sin(t * 2000.0 * TAU) * env * 0.2
	return _make_wav(samples)

func _gen_powerup_sound() -> AudioStreamWAV:
	# Power-up whoosh
	var length := 0.3
	var num_samples := int(sample_rate * length)
	var samples := PackedFloat32Array()
	samples.resize(num_samples)
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var env = sin(t / length * PI) * 0.5
		var freq = 300.0 + 1200.0 * (t / length)
		samples[i] = sin(t * freq * TAU) * env
	return _make_wav(samples)

func _gen_highmerge_sound() -> AudioStreamWAV:
	# Epic merge - chord
	var length := 0.3
	var num_samples := int(sample_rate * length)
	var samples := PackedFloat32Array()
	samples.resize(num_samples)
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var env = exp(-t * 10.0)
		samples[i] = sin(t * 880.0 * TAU) * env * 0.25
		samples[i] += sin(t * 1108.0 * TAU) * env * 0.2  # major third
		samples[i] += sin(t * 1318.0 * TAU) * env * 0.2  # fifth
		samples[i] += sin(t * 1760.0 * TAU) * env * 0.15 # octave
	return _make_wav(samples)
