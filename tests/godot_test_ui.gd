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
	if dock._preset_names.size() != 46:
		failures += 1
		print("FAIL dock preset count: ", dock._preset_names.size())
	else:
		print("OK dock loaded 46 presets, current=", dock._current_preset)
	if dock._params.is_empty():
		failures += 1
		print("FAIL dock params empty")
	else:
		print("OK dock params mode=", dock._params["mode"])
	if dock._sample_paths.size() != 1951:
		failures += 1
		print("FAIL dock sample count: ", dock._sample_paths.size())
	else:
		print("OK dock indexed all 1951 bundled samples")
		if not dock._visible_sample_paths.is_empty() or dock._sample_option.item_count != 1:
			failures += 1
			print("FAIL sample picker loaded the full list before a filter")
		else:
			print("OK sample picker starts empty until a library or search is chosen")
		var has_adbertiser := false
		var has_chip := false
		var has_meta_ogg := false
		for sample_path in dock._sample_paths:
			has_adbertiser = has_adbertiser or "community/adbertiser-sfx/" in sample_path
			has_chip = has_chip or "community/chip-sounds/" in sample_path
			has_meta_ogg = has_meta_ogg or "community/meta-open-sound/" in sample_path
		if not has_adbertiser or not has_chip or not has_meta_ogg:
			failures += 1
			print("FAIL sample picker omitted a community audio collection")
		else:
			print("OK sample picker includes all three community collections")

		dock._sample_source_option.select(2) # Adbertiser SFX
		dock._on_sample_source_selected(2)
		if dock._visible_sample_paths.size() != 408:
			failures += 1
			print("FAIL Adbertiser filter count: ", dock._visible_sample_paths.size())
		else:
			print("OK library filter narrows to 408 Adbertiser samples")
		dock._sample_search.text = "alert"
		dock._on_sample_search_changed("alert")
		if dock._visible_sample_paths.size() != 12:
			failures += 1
			print("FAIL sample search count: ", dock._visible_sample_paths.size())
		else:
			print("OK sample search narrows results by name or folder")
		dock._sample_source_option.select(0)
		dock._on_sample_source_selected(0)
		dock._sample_search.text = "alarm_beep_1"
		dock._on_sample_search_changed("alarm_beep_1")
		if dock._visible_sample_paths.size() != 1:
			failures += 1
			print("FAIL global search-only results: ", dock._visible_sample_paths.size())
		else:
			print("OK search works across libraries without loading all choices")
		dock._sample_search.text = ""
		dock._on_sample_search_changed("")
		dock._sample_source_option.select(2)
		dock._on_sample_source_selected(2)
		dock._sample_sort_option.select(1)
		dock._on_sample_sort_selected(1)
		var first_name: String = String(dock._visible_sample_paths[0]).get_file().to_lower()
		var last_name: String = String(dock._visible_sample_paths[-1]).get_file().to_lower()
		if first_name > last_name:
			failures += 1
			print("FAIL sample name sort order")
		else:
			print("OK samples sort A–Z by filename")
		dock._sample_sort_option.select(0)
		dock._on_sample_sort_selected(0)
		dock._on_sample_selected(0)
		if dock._params.get("mode") != "sample" or String(dock._params.get("sample_path", "")) == "":
			failures += 1
			print("FAIL sample selection did not activate sample mode")
		else:
			print("OK sample selection activates sample mode")
		dock._on_loop_toggled(true)
		dock._on_reverse_toggled(true)
		if (
			not bool(dock._params.get("sample_loop", false))
			or not bool(dock._params.get("sample_reverse", false))
		):
			failures += 1
			print("FAIL sample loop/reverse controls")
		else:
			print("OK sample loop/reverse controls")

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
