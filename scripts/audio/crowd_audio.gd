class_name CrowdAudio
extends Node

## Afición del estadio generada por síntesis (AudioStreamGenerator):
## ruido marrón con un vaivén lento como ambiente base, y una envolvente
## de "grito" que se dispara en los momentos clave.
##
## Decisión registrada (GDD sección 10): por ahora solo ambiente de
## estadio + gritos en gol, falta e inicio de cada parte. Sin música ni
## comentarista. Al no depender de assets, funciona desde ya; cuando haya
## audio real grabado, este nodo mantiene la misma interfaz (cheer()).

const MIX_RATE := 22050.0

var _player := AudioStreamPlayer.new()
var _playback: AudioStreamGeneratorPlayback
var _brown := 0.0
var _cheer_envelope := 0.0
var _sway_phase := 0.0

## Nivel del murmullo constante del estadio.
@export var base_level := 0.2
## Segundos que tarda un grito a tope en apagarse (aprox.).
@export var cheer_decay := 0.45

func _ready() -> void:
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = MIX_RATE
	stream.buffer_length = 0.25
	_player.stream = stream
	_player.volume_db = -10.0
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback()

## Grito de la afición: 1.0 = gol, valores menores para falta o saque inicial.
func cheer(intensity: float) -> void:
	_cheer_envelope = maxf(_cheer_envelope, clampf(intensity, 0.0, 1.0))

func _process(delta: float) -> void:
	_cheer_envelope = maxf(0.0, _cheer_envelope - delta * cheer_decay)
	if _playback == null:
		return

	var frames := _playback.get_frames_available()
	if frames <= 0:
		return

	_sway_phase += delta
	# El murmullo respira lentamente; el grito se suma encima.
	var amplitude := base_level * (0.85 + 0.15 * sin(_sway_phase * 0.7)) \
			+ _cheer_envelope * 0.8

	for i in frames:
		# Ruido marrón: integra ruido blanco con fuga, suena a multitud lejana.
		_brown = clampf((_brown + (randf() * 2.0 - 1.0) * 0.12) * 0.985, -1.0, 1.0)
		var sample := _brown * amplitude
		_playback.push_frame(Vector2(sample, sample))
