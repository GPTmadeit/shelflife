extends RefCounted
## Offline sound synthesis. No audio files ship with the game: every effect,
## voice blip, ambience and the store muzak is generated here at startup.

const RATE := 22050

## voice id -> [wave, base Hz, noise, vibrato, glide]
const VOICES := {
	"baker": ["tri", 520.0, 0.0, 0.0, 0.08],
	"one": ["tri", 610.0, 0.0, 0.0, 0.03],
	"six": ["square", 455.0, 0.0, 0.0, -0.04],
	"twelve": ["sine", 780.0, 0.0, 0.0, 0.1],
	"skim": ["tri", 290.0, 0.0, 0.035, 0.0],
	"gary": ["saw", 395.0, 0.0, 0.0, -0.05],
	"yogurt": ["sine", 660.0, 0.0, 0.0, 0.04],
	"posh": ["sine", 600.0, 0.04, 0.01, 0.06],
	"virgin": ["sine", 560.0, 0.08, 0.025, 0.05],
	"beans": ["square", 320.0, 0.05, 0.0, -0.06],
	"dot": ["square", 350.0, 0.14, 0.0, -0.03],
	"sour": ["tri", 235.0, 0.0, 0.0, 0.02],
	"rolls": ["sine", 840.0, 0.0, 0.02, 0.12],
	"jug": ["tri", 340.0, 0.0, 0.02, 0.0],
	"tyler": ["saw", 150.0, 0.03, 0.0, -0.02],
	"doug": ["tri", 118.0, 0.06, 0.0, -0.03],
	"pa": ["saw", 205.0, 0.05, 0.0, 0.0],
	"narc": ["square", 940.0, 0.0, 0.0, 0.0],
}
const BLIP_VARIANTS := 6

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 20261110


# --- helpers ----------------------------------------------------------------

static func wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var n := samples.size()
	# Looping streams get a copy of sample 0 appended and loop_end points at it:
	# Godot plays the sample *at* loop_end, so loop_end == n would read past
	# the buffer.
	var frames := n + 1 if loop else n
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	for i in frames:
		bytes.encode_s16(i * 2, int(clampf(samples[i % n], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = n
	return w


static func _buf(dur: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(int(dur * RATE))
	return a


static func _osc(wave: String, ph: float) -> float:
	var f := ph - floorf(ph)
	if wave == "sine":
		return sin(f * TAU)
	if wave == "tri":
		return 1.0 - 4.0 * absf(f - 0.5)
	if wave == "saw":
		return 2.0 * f - 1.0
	return 1.0 if f < 0.5 else -1.0


func _noise() -> float:
	return _rng.randf() * 2.0 - 1.0


## Adds b into a at offset seconds, scaled.
static func _add(a: PackedFloat32Array, b: PackedFloat32Array, offset := 0.0, g := 1.0) -> void:
	var o := int(offset * RATE)
	for i in b.size():
		var k := o + i
		if k >= a.size():
			break
		a[k] += b[i] * g


static func _normalize(a: PackedFloat32Array, peak := 0.9) -> PackedFloat32Array:
	var m := 0.0001
	for v in a:
		m = maxf(m, absf(v))
	var g := peak / m
	for i in a.size():
		a[i] *= g
	return a


## One-pole low/high pass filters in place.
static func _lowpass(a: PackedFloat32Array, hz: float) -> void:
	var k := 1.0 - exp(-TAU * hz / RATE)
	var y := 0.0
	for i in a.size():
		y += (a[i] - y) * k
		a[i] = y


static func _highpass(a: PackedFloat32Array, hz: float) -> void:
	var k := 1.0 - exp(-TAU * hz / RATE)
	var y := 0.0
	for i in a.size():
		y += (a[i] - y) * k
		a[i] -= y


## Crossfades the tail into the head so the buffer loops without a click.
static func _loopify(a: PackedFloat32Array, fade: float) -> PackedFloat32Array:
	var f := int(fade * RATE)
	var n := a.size() - f
	var out := a.slice(0, n)
	for i in f:
		var k := float(i) / f
		out[i] = a[i] * k + a[n + i] * (1.0 - k)
	return out


## A pitched tone with an attack and exponential decay; f0 -> f1 glide.
func tone(dur: float, f0: float, f1: float, wave := "sine", attack := 0.005, decay := 0.2, gain := 0.6, vib := 0.0) -> PackedFloat32Array:
	var a := _buf(dur)
	var ph := 0.0
	var n := a.size()
	for i in n:
		var t := float(i) / RATE
		var u := float(i) / n
		var f := lerpf(f0, f1, u)
		if vib > 0.0:
			f *= 1.0 + vib * sin(TAU * 6.0 * t)
		ph += f / RATE
		var env := minf(1.0, t / maxf(attack, 0.0001)) * exp(-t / decay)
		a[i] = _osc(wave, ph) * env * gain
	return a


func noise(dur: float, lp_hz: float, attack: float, decay: float, gain := 0.6, hp_hz := 0.0) -> PackedFloat32Array:
	var a := _buf(dur)
	for i in a.size():
		var t := float(i) / RATE
		a[i] = _noise() * minf(1.0, t / maxf(attack, 0.0001)) * exp(-t / decay) * gain
	if lp_hz > 0.0:
		_lowpass(a, lp_hz)
		_lowpass(a, lp_hz)
	if hp_hz > 0.0:
		_highpass(a, hp_hz)
	return a


## A bell-like partial stack (PA chimes, checkpoint).
func bell(dur: float, f: float, gain := 0.5, decay := 0.6) -> PackedFloat32Array:
	var a := _buf(dur)
	var parts := [[1.0, 1.0, 1.0], [2.0, 0.35, 0.6], [2.76, 0.22, 0.45], [5.4, 0.08, 0.25]]
	for i in a.size():
		var t := float(i) / RATE
		var s := 0.0
		for p in parts:
			s += sin(TAU * f * p[0] * t) * p[1] * exp(-t / (decay * p[2]))
		a[i] = s * gain * minf(1.0, t / 0.003)
	return a


# --- the catalogue ------------------------------------------------------------

## Returns name -> AudioStreamWAV. Short sounds first, loops last.
func make_all() -> Dictionary:
	var out := {}
	# Voice blips: one short syllable per variant, pitched around the voice.
	var steps := [0.9, 0.96, 1.0, 1.05, 1.1, 1.16]
	for v in VOICES.keys():
		var p: Array = VOICES[v]
		for k in BLIP_VARIANTS:
			out["blip_%s_%d" % [v, k]] = wav(_blip(p[0], p[1] * steps[k], p[2], p[3], p[4], v == "pa"))
	out.step = wav(_gain(noise(0.035, 4200.0, 0.001, 0.008, 0.5, 900.0), 1.0))
	out.jump = wav(tone(0.14, 330.0, 760.0, "tri", 0.004, 0.06, 0.45))
	out.land = wav(_mix(tone(0.12, 150.0, 70.0, "sine", 0.002, 0.04, 0.8), noise(0.08, 1800.0, 0.001, 0.02, 0.35)))
	out.crack = wav(_crack())
	out.splat = wav(_splat())
	out.bounce = wav(tone(0.32, 210.0, 520.0, "sine", 0.004, 0.12, 0.6, 0.06))
	out.chime = wav(_mix(bell(1.6, 659.25, 0.45, 0.5), bell(1.4, 523.25, 0.45, 0.55), 0.42))
	out.beep = wav(tone(0.09, 1180.0, 1180.0, "square", 0.002, 0.05, 0.25))
	out.alert = wav(_alert())
	out.thud = wav(_thud())
	out.whoosh = wav(_whoosh())
	out.grab = wav(_mix(tone(0.16, 900.0, 300.0, "tri", 0.002, 0.05, 0.3), tone(0.2, 90.0, 50.0, "sine", 0.002, 0.08, 0.7)))
	out.clunk = wav(_clunk())
	out.ui_move = wav(tone(0.05, 880.0, 940.0, "sine", 0.002, 0.02, 0.25))
	out.ui_ok = wav(_mix(tone(0.12, 660.0, 660.0, "tri", 0.003, 0.05, 0.3), tone(0.16, 990.0, 990.0, "tri", 0.003, 0.06, 0.3), 0.06))
	out.objective = wav(_mix(bell(1.0, 784.0, 0.32, 0.4), bell(1.0, 1046.5, 0.32, 0.4), 0.13))
	out.checkpoint = wav(_arp([523.25, 659.25, 783.99], 0.09, 0.32))
	out.scrap = wav(_arp([783.99, 987.77, 1174.66, 1567.98], 0.07, 0.28))
	out.sting = wav(_sting())
	out.reveal = wav(_reveal())
	out.door = wav(_door())
	out.chomp = wav(_chomp())
	out.boo = wav(_mix(tone(0.5, 300.0, 180.0, "saw", 0.02, 0.25, 0.25), tone(0.5, 303.0, 182.0, "saw", 0.02, 0.25, 0.25)))
	out.cheer = wav(_cheer())
	out.gasp = wav(_gasp())
	out.hum_fridge = wav(_hum(4.0, 60.0, 0.28, 900.0), true)
	out.hum_store = wav(_hum(4.0, 120.0, 0.12, 500.0), true)
	out.tension = wav(_tension(), true)
	out.muzak = wav(_muzak(), true)
	return out


func _blip(wave: String, f: float, nz: float, vib: float, glide: float, muffled: bool) -> PackedFloat32Array:
	var dur := 0.065
	var a := _buf(dur)
	var ph := 0.0
	var lp := 0.0
	var n := a.size()
	for i in n:
		var t := float(i) / RATE
		var u := float(i) / n
		var ff := f * (1.0 + glide * (1.0 - u))
		if vib > 0.0:
			ff *= 1.0 + vib * sin(TAU * 9.0 * t)
		ph += ff / RATE
		var s := _osc(wave, ph)
		# a second, formant-ish partial makes it sound more like a syllable
		s = s * 0.75 + sin(ph * TAU * 2.0) * 0.25
		if nz > 0.0:
			s = s * (1.0 - nz) + _noise() * nz
		lp += (s - lp) * (0.18 if muffled else 0.4)
		var env := minf(1.0, t / 0.006) * exp(-t / (dur * 0.42))
		a[i] = lp * env * 0.55
	if muffled:
		_highpass(a, 260.0)
	return a


func _gain(a: PackedFloat32Array, g: float) -> PackedFloat32Array:
	for i in a.size():
		a[i] = tanh(a[i] * g)
	return a


func _mix(a: PackedFloat32Array, b: PackedFloat32Array, offset := 0.0) -> PackedFloat32Array:
	var n := maxi(a.size(), int(offset * RATE) + b.size())
	var out := PackedFloat32Array()
	out.resize(n)
	_add(out, a)
	_add(out, b, offset)
	return out


func _arp(freqs: Array, gap: float, gain: float) -> PackedFloat32Array:
	var out := _buf(gap * freqs.size() + 0.7)
	for k in freqs.size():
		_add(out, bell(0.7, freqs[k], gain, 0.25), gap * k)
	return out


func _crack() -> PackedFloat32Array:
	var a := noise(0.3, 7000.0, 0.0005, 0.03, 0.9, 1500.0)
	# brittle crackles after the snap
	for k in 9:
		var at := 0.01 + _rng.randf() * 0.2
		_add(a, noise(0.02, 9000.0, 0.0003, 0.004, 0.6 * (1.0 - at * 3.0), 2500.0), at)
	return _gain(a, 1.6)


func _splat() -> PackedFloat32Array:
	var a := _buf(0.7)
	var ph := 0.0
	var lp := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var f := 210.0 * exp(-t * 4.0) + 55.0 + 30.0 * sin(TAU * 13.0 * t)
		ph += f / RATE
		var s := sin(ph * TAU) * 0.6 + _noise() * 0.5
		lp += (s - lp) * 0.08
		a[i] = lp * exp(-t / 0.18) * minf(1.0, t / 0.002) * 1.6
	_add(a, _crack(), 0.0, 0.5)
	return _gain(a, 1.2)


func _alert() -> PackedFloat32Array:
	var a := _buf(0.9)
	var ph := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var f := 980.0 if int(t * 8.0) % 2 == 0 else 760.0
		ph += f / RATE
		a[i] = _osc("square", ph) * 0.22 * minf(1.0, (0.9 - t) * 20.0)
	_lowpass(a, 3500.0)
	return a


func _thud() -> PackedFloat32Array:
	var a := tone(0.45, 72.0, 34.0, "sine", 0.003, 0.14, 1.0)
	_add(a, noise(0.3, 400.0, 0.001, 0.05, 0.8))
	return _gain(a, 1.4)


func _whoosh() -> PackedFloat32Array:
	var a := _buf(0.45)
	var lp := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var k := 0.02 + 0.25 * sin(PI * t / 0.45)
		lp += (_noise() - lp) * k
		a[i] = lp * sin(PI * t / 0.45) * 0.9
	return a


func _clunk() -> PackedFloat32Array:
	var a := tone(0.5, 120.0, 60.0, "square", 0.001, 0.03, 0.4)
	_lowpass(a, 900.0)
	_add(a, noise(0.6, 1200.0, 0.001, 0.12, 0.25), 0.0)
	_add(a, tone(0.35, 3200.0, 3000.0, "sine", 0.001, 0.01, 0.2))
	return a


func _sting() -> PackedFloat32Array:
	# a dramatic low brass hit (D minor) with a timpani roll under it
	var out := _buf(2.2)
	for f in [73.42, 110.0, 146.83, 174.61, 220.0]:
		var t := tone(2.2, f, f * 0.99, "saw", 0.01, 0.7, 0.18)
		_lowpass(t, 1400.0)
		_add(out, t)
	_add(out, noise(1.2, 300.0, 0.002, 0.35, 0.7))
	return _normalize(out, 0.85)


func _reveal() -> PackedFloat32Array:
	var out := _buf(3.0)
	for f in [55.0, 82.41, 110.0, 130.81]:
		var a := _buf(3.0)
		var ph := 0.0
		for i in a.size():
			var t := float(i) / RATE
			ph += f * (1.0 + 0.004 * sin(TAU * 0.7 * t)) / RATE
			a[i] = _osc("saw", ph) * minf(1.0, t / 1.2) * exp(-maxf(t - 1.8, 0.0) / 0.5) * 0.2
		_lowpass(a, 700.0)
		_add(out, a)
	return _normalize(out, 0.8)


func _door() -> PackedFloat32Array:
	var a := _buf(0.8)
	var ph := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var f := 140.0 + 90.0 * sin(TAU * 1.7 * t) + 40.0 * sin(TAU * 23.0 * t)
		ph += f / RATE
		a[i] = _osc("saw", ph) * 0.3 * sin(PI * t / 0.8)
	_lowpass(a, 2200.0)
	return a


func _chomp() -> PackedFloat32Array:
	var a := noise(0.25, 3500.0, 0.001, 0.05, 0.8, 400.0)
	_add(a, tone(0.2, 110.0, 60.0, "sine", 0.002, 0.06, 0.7))
	_add(a, noise(0.15, 2500.0, 0.001, 0.03, 0.5, 600.0), 0.09)
	return _gain(a, 1.3)


func _cheer() -> PackedFloat32Array:
	# a tiny crowd of food yelling "yay"
	var out := _buf(1.2)
	for k in 9:
		var f := 380.0 + _rng.randf() * 520.0
		_add(out, tone(0.7 + _rng.randf() * 0.3, f, f * 1.25, "tri", 0.04, 0.35, 0.12, 0.03), _rng.randf() * 0.2)
	_lowpass(out, 3000.0)
	return _normalize(out, 0.7)


func _gasp() -> PackedFloat32Array:
	var out := _buf(0.7)
	for k in 7:
		var f := 420.0 + _rng.randf() * 500.0
		_add(out, tone(0.35, f, f * 1.4, "sine", 0.02, 0.12, 0.12), _rng.randf() * 0.08)
	_add(out, noise(0.4, 3000.0, 0.03, 0.12, 0.25, 800.0))
	return _normalize(out, 0.6)


func _hum(dur: float, f: float, gain: float, lp_hz: float) -> PackedFloat32Array:
	var a := _buf(dur + 0.5)
	var lp := 0.0
	for i in a.size():
		var t := float(i) / RATE
		lp += (_noise() - lp) * 0.02
		a[i] = (sin(TAU * f * t) * 0.6 + sin(TAU * f * 2.0 * t) * 0.25 + sin(TAU * f * 3.0 * t) * 0.08) * gain + lp * gain * 1.6
	_lowpass(a, lp_hz)
	return _loopify(a, 0.5)


## Low, sneaky pulse for the Narc's patrol.
func _tension() -> PackedFloat32Array:
	var bpm := 104.0
	var beat := 60.0 / bpm
	var dur := beat * 16.0
	var out := _buf(dur + 0.6)
	var bass := [38, 38, 41, 38, 36, 36, 41, 43]
	for k in 32:
		var t0 := k * beat * 0.5
		var m: int = bass[(k / 4) % bass.size()]
		var f := 440.0 * pow(2.0, (m - 69) / 12.0)
		var n := tone(beat * 0.45, f, f, "tri", 0.005, 0.12, 0.5 if k % 2 == 0 else 0.3)
		_add(out, n, t0)
		if k % 2 == 1:
			_add(out, noise(0.05, 9000.0, 0.001, 0.012, 0.12, 5000.0), t0)
	var plucks := [69, 72, 67, 70]
	for k in 4:
		_add(out, bell(0.9, _hz(plucks[k]), 0.07, 0.3), (k * 4 + 3) * beat)
	_lowpass(out, 2600.0)
	return _loopify(_normalize(out, 0.6), 0.6)


## The store's ceiling-speaker muzak: smooth chords, a walking bass, a vibes
## melody and a shaker, band-limited like it comes out of a cheap speaker.
func _muzak() -> PackedFloat32Array:
	var bpm := 92.0
	var beat := 60.0 / bpm
	var bars := 8
	var dur := beat * 4.0 * bars
	var out := _buf(dur + 1.0)
	# chords (MIDI notes), one per bar; bars 6 and 7 split in two
	var chords := [
		[[53, 57, 60, 64]], [[52, 55, 59, 62]], [[50, 53, 57, 60]], [[52, 55, 59, 60]],
		[[53, 57, 60, 64]], [[52, 55, 59, 62], [52, 55, 57, 61]], [[50, 53, 57, 60], [53, 55, 59, 62]], [[52, 55, 59, 60]],
	]
	var roots := [[41], [40], [38], [36], [41], [40, 45], [38, 43], [36]]
	for b in bars:
		var parts: Array = chords[b]
		var span := 4.0 / parts.size()
		for p in parts.size():
			var t0 := (b * 4.0 + p * span) * beat
			# electric piano stabs on 1 and the and-of-2
			var hits := [0.0, 1.5] if span >= 4.0 else [0.0]
			for hit in hits:
				for m in parts[p]:
					_add(out, _ep(_hz(m), beat * 2.2), t0 + hit * beat, 0.16)
			var r: int = roots[b][p]
			_add(out, _bass(_hz(r), beat * 1.6), t0, 0.5)
			if span >= 4.0:
				_add(out, _bass(_hz(r + 7), beat * 1.4), t0 + 2.0 * beat, 0.42)
		for k in 8:
			_add(out, noise(0.06, 8000.0, 0.004, 0.02, 0.06 if k % 2 == 0 else 0.1, 4000.0), (b * 4.0 + k * 0.5) * beat)
	# the tune: [MIDI, beats], 0 = rest
	var tune := [
		[69, 1], [72, 1], [76, 2],
		[74, 1.5], [71, 0.5], [67, 2],
		[65, 1], [69, 1], [72, 1], [69, 1],
		[67, 3], [0, 1],
		[69, 1], [72, 1], [77, 1.5], [76, 0.5],
		[74, 1], [71, 1], [73, 2],
		[74, 1], [77, 1], [76, 1], [74, 1],
		[72, 3], [0, 1],
	]
	var at := 0.0
	for n in tune:
		if n[0] > 0:
			_add(out, _vibes(_hz(n[0]), n[1] * beat + 0.4), at * beat, 0.3)
		at += n[1]
	_highpass(out, 240.0)
	_lowpass(out, 3200.0)
	_lowpass(out, 3800.0)
	return _loopify(_normalize(out, 0.7), 1.0)


static func _hz(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)


func _ep(f: float, dur: float) -> PackedFloat32Array:
	var a := _buf(dur)
	for i in a.size():
		var t := float(i) / RATE
		var trem := 1.0 + 0.25 * sin(TAU * 5.0 * t)
		var s := sin(TAU * f * t) + 0.25 * sin(TAU * f * 2.0 * t) * exp(-t / 0.15) + 0.12 * sin(TAU * f * 7.0 * t) * exp(-t / 0.02)
		a[i] = s * trem * minf(1.0, t / 0.004) * exp(-t / 0.55)
	return a


func _bass(f: float, dur: float) -> PackedFloat32Array:
	var a := _buf(dur)
	for i in a.size():
		var t := float(i) / RATE
		var s := sin(TAU * f * t) * 0.85 + _osc("tri", f * t) * 0.25
		a[i] = s * minf(1.0, t / 0.012) * exp(-t / 0.5)
	return a


func _vibes(f: float, dur: float) -> PackedFloat32Array:
	var a := _buf(dur)
	for i in a.size():
		var t := float(i) / RATE
		var trem := 1.0 + 0.35 * sin(TAU * 6.0 * t)
		var s := sin(TAU * f * t) + 0.2 * sin(TAU * f * 4.0 * t) * exp(-t / 0.08)
		a[i] = s * trem * minf(1.0, t / 0.003) * exp(-t / 0.7)
	return a
