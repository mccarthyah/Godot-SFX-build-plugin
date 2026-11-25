extends SceneTree
## Headless UI/runtime validation: dock instantiation + SFXPlayer.
## Run: godot --headless --path . --script tests/godot_test_ui.gd

func _init() -> void:
	print("=== Godot SFX UI/runtime validation ===")
	var failures: int = 0

	# 1. Dock instantiates and builds its UI.
	var dock_script: GDScript = load("res://addons/sfx_generator/sfx_dock.gd")
	var dock: Control = dock_script.new()
	root.add_child(dock)
	await process_frame
	await process_frame
	if dock._preset_names.size() != 36:
		failures += 1
		print("FAIL dock preset count: ", dock._preset_names.size())
	else:
		print("OK dock loaded 36 presets, current=", dock._current_preset)
	if dock._params.is_empty():
		failures += 1
		print("FAIL dock params empty")
	else:
		print("OK dock params mode=", dock._params["mode"])

	# 2. Dock preview path (generate stream from dock params).
	var stream: AudioStreamWAV = SFXSynthEngine.generate_stream(dock._params)
	if stream == null or stream.data.size() == 0:
		failures += 1
		print("FAIL dock stream")
	else:
		print("OK dock stream bytes=", stream.data.size())

	# 3. Dock randomize + mutate paths.
	dock._on_randomize()
	if dock._params.is_empty():
		failures += 1
		print("FAIL dock randomize")
	else:
		print("OK dock randomize mode=", dock._params["mode"])
	dock._on_mutate()
	print("OK dock mutate")

	# 4. SFXPlayer generates a stream.
	var player: Node = load("res://addons/sfx_generator/sfx_player.gd").new()
	player.preset_name = "Laser Zap"
	root.add_child(player)
	var ps: AudioStreamWAV = player.generate()
	if ps == null or ps.data.size() == 0:
		failures += 1
		print("FAIL SFXPlayer generate")
	else:
		print("OK SFXPlayer stream bytes=", ps.data.size())

	print("=== DONE failures=", failures, " ===")
	quit(1 if failures > 0 else 0)
