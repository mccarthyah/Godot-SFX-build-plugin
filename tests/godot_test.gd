extends SceneTree
## Headless validation for the SFX Generator plugin.
## Run: godot --headless --path . --script tests/godot_test.gd
## Exit code 0 = all checks passed.

func _init() -> void:
	print("=== Godot SFX plugin validation ===")
	var failures: int = 0

	# 1. Engine: all modes produce expected sample counts.
	var modes: Array = ["osc", "fm", "pluck", "noise", "additive", "granular", "formant", "hybrid"]
	for mode in modes:
		var p: Dictionary = SFXSynthEngine.default_params()
		p["mode"] = mode
		p["duration"] = 0.3
		p["stereo"] = false
		var samples: PackedFloat32Array = SFXSynthEngine.generate_samples(p)
		var expected: int = int(0.3 * 44100)
		if samples.size() != expected:
			failures += 1
			print("FAIL mode ", mode, " size ", samples.size(), " expected ", expected)
		else:
			print("OK mode ", mode, " samples=", samples.size())

	# 2. All presets generate + save to disk.
	var presets: Array = SFXPresets.get_presets()
	print("Presets: ", presets.size())
	DirAccess.make_dir_recursive_absolute("res://godot_test_output")
	var saved: int = 0
	for entry in presets:
		var p: Dictionary = SFXSynthEngine.default_params()
		for k in (entry["params"] as Dictionary).keys():
			p[k] = entry["params"][k]
		var path: String = "res://godot_test_output/" + String(entry["name"]).replace(" ", "_") + ".wav"
		var err: Error = SFXSynthEngine.save_wav(path, p)
		if err == OK:
			saved += 1
		else:
			failures += 1
			print("FAIL save ", String(entry["name"]), " err=", err)
	print("Saved ", saved, "/", presets.size())

	# 3. Random + mutate across categories.
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for cat in ["ui", "sci-fi", "magic", "impact", "nature", "musical", "any"]:
		var rp: Dictionary = SFXSynthEngine.random_params(rng, cat)
		var s: PackedFloat32Array = SFXSynthEngine.generate_samples(rp)
		if s.size() == 0:
			failures += 1
			print("FAIL random ", cat)
	print("OK random_params all categories")
	var mp: Dictionary = SFXSynthEngine.mutate_params(SFXSynthEngine.default_params(), rng, 0.3)
	if mp.is_empty():
		failures += 1
		print("FAIL mutate_params empty")
	else:
		print("OK mutate_params")

	# 4. Stream generation.
	var stream: AudioStreamWAV = SFXSynthEngine.generate_stream({"mode": "fm", "duration": 0.2})
	if stream == null or stream.data.size() == 0:
		failures += 1
		print("FAIL generate_stream")
	else:
		print("OK generate_stream bytes=", stream.data.size())

	# 5. Determinism (same seed -> identical samples).
	var a: PackedFloat32Array = SFXSynthEngine.generate_samples({"mode": "noise", "noise_amount": 1.0, "duration": 0.2, "seed": 7, "stereo": false})
	var b: PackedFloat32Array = SFXSynthEngine.generate_samples({"mode": "noise", "noise_amount": 1.0, "duration": 0.2, "seed": 7, "stereo": false})
	if a != b:
		failures += 1
		print("FAIL determinism")
	else:
		print("OK determinism")

	# 6. Dock + player scripts load.
	var dock_script: GDScript = load("res://addons/sfx_generator/sfx_dock.gd")
	if dock_script == null:
		failures += 1
		print("FAIL dock load")
	else:
		print("OK dock script loads")
	var player_script: GDScript = load("res://addons/sfx_generator/sfx_player.gd")
	if player_script == null:
		failures += 1
		print("FAIL player load")
	else:
		print("OK player script loads")

	print("=== DONE failures=", failures, " ===")
	quit(1 if failures > 0 else 0)
