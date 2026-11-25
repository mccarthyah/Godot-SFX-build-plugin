extends Node
## Demo: plays a few procedurally generated sounds on start.
## For the full experience, use the SFX Generator dock (View -> SFX Generator)
## to browse all 36 presets, tweak parameters and export WAV files.

var _players: Array = []


func _ready() -> void:
	print("SFX Generator demo — playing a few presets. Open View > SFX Generator for the full dock.")
	_play_sequence(["Laser Zap", "FM Bell", "Enchanted Pluck", "Deep Explosion", "Magic Sparkle"])


func _play_sequence(preset_names: Array) -> void:
	for preset_name in preset_names:
		var player := SFXPlayer.new()
		player.preset_name = String(preset_name)
		add_child(player)
		_players.append(player)
		player.play()
		print("Playing: ", preset_name)
		await get_tree().create_timer(1.2).timeout
