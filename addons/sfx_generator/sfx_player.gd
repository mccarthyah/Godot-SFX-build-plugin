class_name SFXPlayer
extends Node
## Runtime SFX player: procedurally generate a sound from parameters and play it.
##
## Useful for prototyping or fully procedural games (no audio assets needed).
## For shipped games, prefer exporting WAVs from the editor dock instead —
## runtime generation costs CPU at startup.

@export var preset_name: String = "Laser Zap"
@export var params: Dictionary = {}
@export var autoplay: bool = false
@export var volume_db: float = 0.0

var _player: AudioStreamPlayer = null
var _stream: AudioStreamWAV = null


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.volume_db = volume_db
	add_child(_player)
	if autoplay:
		play()


## Generate (if needed) and play the sound.
func play() -> void:
	if _stream == null:
		generate()
	if _player != null and _stream != null:
		_player.stream = _stream
		_player.play()


## Generate the AudioStreamWAV from preset/params without playing.
func generate() -> AudioStreamWAV:
	var p: Dictionary = SFXSynthEngine.default_params()
	var preset: Dictionary = SFXPresets.get_by_name(preset_name)
	if not preset.is_empty():
		for k in (preset["params"] as Dictionary).keys():
			p[k] = preset["params"][k]
	for k in params.keys():
		p[k] = params[k]
	_stream = SFXSynthEngine.generate_stream(p)
	return _stream


## Stop playback.
func stop() -> void:
	if _player != null:
		_player.stop()
