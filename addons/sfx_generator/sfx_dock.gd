@tool
extends Control
## SFX Generator editor dock: preset browser, live preview, parameter
## editing, randomization and WAV export.

const MODES: Array = [
	"osc", "fm", "pluck", "noise", "additive", "granular", "formant", "hybrid", "sample"
]
const WAVE_NAMES: Array = ["Sine", "Saw", "Square", "Triangle", "Pulse", "Noise"]
const NOISE_NAMES: Array = ["White", "Pink", "Brown"]
const FILTER_NAMES: Array = ["None", "Lowpass", "Highpass", "Bandpass", "Notch"]
const DISTORT_NAMES: Array = ["Tanh", "Hard clip", "Foldback"]
const SAMPLE_SOURCE_PREFIXES: Dictionary = {
	2: "community/adbertiser-sfx/",
	3: "community/chip-sounds/",
	4: "community/meta-open-sound/meta-nylon-guitar/",
	5: "community/meta-open-sound/meta-piano/",
	6: "community/meta-open-sound/meta-steel-guitar/",
}

var _params: Dictionary = {}
var _player: AudioStreamPlayer = null
var _sliders: Dictionary = {} # key -> HSlider
var _value_labels: Dictionary = {} # key -> Label
var _mode_option: OptionButton = null
var _wave_option: OptionButton = null
var _noise_option: OptionButton = null
var _filter_option: OptionButton = null
var _distort_option: OptionButton = null
var _preset_option: OptionButton = null
var _category_option: OptionButton = null
var _seed_spin: SpinBox = null
var _path_edit: LineEdit = null
var _status_label: Label = null
var _preset_names: Array = []
var _current_preset: String = ""
var _sample_option: OptionButton = null
var _sample_search: LineEdit = null
var _sample_source_option: OptionButton = null
var _sample_sort_option: OptionButton = null
var _sample_paths: Array = []
var _visible_sample_paths: Array = []
var _loop_check: CheckBox = null
var _reverse_check: CheckBox = null


func _ready() -> void:
	custom_minimum_size = Vector2(360, 500)
	_params = SFXSynthEngine.default_params()
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_build_ui()
	_on_category_selected(0) # populate preset dropdown
	var idx: int = _preset_names.find("Laser Zap")
	if idx >= 0:
		_preset_option.select(idx)
		_load_preset("Laser Zap")


## ---------------------------------------------------------------------------
## UI construction
## ---------------------------------------------------------------------------

func _build_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 8)
	scroll.add_child(root)

	# --- Header ---
	var title := Label.new()
	title.text = "SFX Generator"
	title.add_theme_font_size_override("font_size", 20)
	root.add_child(title)

	var sub := Label.new()
	sub.text = "Procedural synthesis plus CC0 samples — shape either with the full effects chain."
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(sub)

	root.add_child(HSeparator.new())
	root.add_child(_section_label("Preset"))

	_preset_option = OptionButton.new()
	_preset_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preset_option.item_selected.connect(_on_preset_selected)
	root.add_child(_preset_option)

	_category_option = OptionButton.new()
	_category_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_category_option.add_item("All categories", -1)
	for cat in SFXPresets.CATEGORIES:
		_category_option.add_item(String(cat).capitalize(), SFXPresets.CATEGORIES.find(cat))
	_category_option.item_selected.connect(_on_category_selected)
	root.add_child(_category_option)

	var seed_row := HBoxContainer.new()
	root.add_child(seed_row)
	var seed_label := Label.new()
	seed_label.text = "Seed"
	seed_row.add_child(seed_label)
	_seed_spin = SpinBox.new()
	_seed_spin.min_value = 0
	_seed_spin.max_value = 999999999
	_seed_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed_spin.value_changed.connect(_on_seed_changed)
	seed_row.add_child(_seed_spin)

	var rand_row := HBoxContainer.new()
	root.add_child(rand_row)
	var rand_btn := Button.new()
	rand_btn.text = "🎲 Randomize"
	rand_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rand_btn.pressed.connect(_on_randomize)
	rand_row.add_child(rand_btn)
	var mut_btn := Button.new()
	mut_btn.text = "🧬 Mutate"
	mut_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mut_btn.pressed.connect(_on_mutate)
	rand_row.add_child(mut_btn)

	root.add_child(HSeparator.new())
	root.add_child(_section_label("Preview"))

	var play_row := HBoxContainer.new()
	root.add_child(play_row)
	var play_btn := Button.new()
	play_btn.text = "▶ Preview"
	play_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_btn.pressed.connect(_on_preview)
	play_row.add_child(play_btn)
	var stop_btn := Button.new()
	stop_btn.text = "■ Stop"
	stop_btn.pressed.connect(_on_stop)
	play_row.add_child(stop_btn)

	_status_label = Label.new()
	_status_label.text = "Ready."
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status_label)

	root.add_child(HSeparator.new())
	root.add_child(_section_label("Source"))

	_mode_option = _make_option(root, "Mode", MODES, "mode")
	_wave_option = _make_option(root, "Waveform", WAVE_NAMES, "wave")
	_noise_option = _make_option(root, "Noise type", NOISE_NAMES, "noise_type")
	_add_slider(root, "Duration (s)", "duration", 0.05, 10.0, 0.01)
	_add_slider(root, "Base freq (Hz)", "base_freq", 20.0, 4000.0, 1.0)
	_add_slider(root, "Freq end (Hz, 0=off)", "freq_end", 0.0, 4000.0, 1.0)
	_add_slider(root, "Vibrato rate", "vibrato_rate", 0.0, 20.0, 0.1)
	_add_slider(root, "Vibrato depth", "vibrato_depth", 0.0, 0.3, 0.005)
	_add_slider(root, "Duty (pulse)", "duty", 0.05, 0.95, 0.01)
	_add_slider(root, "Sub osc amount", "sub_amount", 0.0, 1.0, 0.01)
	_add_slider(root, "2nd osc amount", "second_amount", 0.0, 1.0, 0.01)
	_add_slider(root, "2nd osc detune (cents)", "second_detune", -50.0, 50.0, 0.5)
	_add_slider(root, "Noise amount", "noise_amount", 0.0, 1.0, 0.01)
	_add_slider(root, "FM ratio", "fm_ratio", 0.1, 10.0, 0.01)
	_add_slider(root, "FM index", "fm_index", 0.0, 12.0, 0.05)
	_add_slider(root, "FM decay", "fm_decay", 0.1, 10.0, 0.05)
	_add_slider(root, "FM feedback", "fm_feedback", 0.0, 0.9, 0.01)
	_add_slider(root, "Pluck damping", "pluck_damping", 0.9, 0.9999, 0.0005)
	_add_slider(root, "Pluck brightness", "pluck_brightness", 0.0, 1.0, 0.01)
	_add_slider(root, "Partial count", "partial_count", 1.0, 32.0, 1.0)
	_add_slider(root, "Inharmonicity", "inharmonicity", 0.0, 0.01, 0.00005)
	_add_slider(root, "Grain density", "grain_density", 1.0, 80.0, 0.5)
	_add_slider(root, "Grain size (s)", "grain_size", 0.005, 0.5, 0.005)
	_add_slider(root, "Grain spread (st)", "grain_spread", 0.0, 36.0, 0.5)
	_add_slider(root, "Formant 1 (Hz)", "formant1", 200.0, 1500.0, 10.0)
	_add_slider(root, "Formant 2 (Hz)", "formant2", 500.0, 3000.0, 10.0)
	_add_slider(root, "Formant 3 (Hz)", "formant3", 1000.0, 5000.0, 10.0)

	root.add_child(HSeparator.new())
	root.add_child(_section_label("Sample (mode: sample)"))
	_sample_search = LineEdit.new()
	_sample_search.placeholder_text = "Search sample names or folders…"
	_sample_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sample_search.text_changed.connect(_on_sample_search_changed)
	root.add_child(_sample_search)

	var sample_filter_row := HBoxContainer.new()
	root.add_child(sample_filter_row)
	_sample_source_option = OptionButton.new()
	_sample_source_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sample_source_option.add_item("All libraries", 0)
	_sample_source_option.add_item("Wyzowl SFX Kit", 1)
	_sample_source_option.add_item("Adbertiser SFX", 2)
	_sample_source_option.add_item("Chip Sounds", 3)
	_sample_source_option.add_item("Meta Nylon Guitar", 4)
	_sample_source_option.add_item("Meta Piano", 5)
	_sample_source_option.add_item("Meta Steel Guitar", 6)
	_sample_source_option.item_selected.connect(_on_sample_source_selected)
	sample_filter_row.add_child(_sample_source_option)
	_sample_sort_option = OptionButton.new()
	_sample_sort_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sample_sort_option.add_item("Folder order", 0)
	_sample_sort_option.add_item("Name A–Z", 1)
	_sample_sort_option.item_selected.connect(_on_sample_sort_selected)
	sample_filter_row.add_child(_sample_sort_option)

	_sample_option = OptionButton.new()
	_sample_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sample_option.item_selected.connect(_on_sample_selected)
	root.add_child(_sample_option)
	_add_slider(root, "Sample pitch (st)", "sample_pitch", -24.0, 24.0, 0.5)
	_loop_check = CheckBox.new()
	_loop_check.text = "Loop sample to fill duration"
	_loop_check.toggled.connect(_on_loop_toggled)
	root.add_child(_loop_check)
	_reverse_check = CheckBox.new()
	_reverse_check.text = "Reverse sample"
	_reverse_check.toggled.connect(_on_reverse_toggled)
	root.add_child(_reverse_check)
	_scan_samples()

	root.add_child(HSeparator.new())
	root.add_child(_section_label("Envelope (ADSR)"))
	_add_slider(root, "Attack (s)", "amp_attack", 0.001, 1.0, 0.001)
	_add_slider(root, "Decay (s)", "amp_decay", 0.01, 2.0, 0.01)
	_add_slider(root, "Sustain", "amp_sustain", 0.0, 1.0, 0.01)
	_add_slider(root, "Release (s)", "amp_release", 0.01, 3.0, 0.01)

	root.add_child(HSeparator.new())
	root.add_child(_section_label("Filter"))
	_filter_option = _make_option(root, "Filter type", FILTER_NAMES, "filter_type")
	_add_slider(root, "Filter freq (Hz)", "filter_freq", 40.0, 16000.0, 10.0)
	_add_slider(root, "Filter freq end (0=off)", "filter_freq_end", 0.0, 16000.0, 10.0)
	_add_slider(root, "Filter Q", "filter_q", 0.3, 12.0, 0.05)
	_add_slider(root, "Filter env (oct)", "filter_env", -4.0, 4.0, 0.1)

	root.add_child(HSeparator.new())
	root.add_child(_section_label("Effects"))
	_distort_option = _make_option(root, "Distortion type", DISTORT_NAMES, "distortion_type")
	_add_slider(root, "Distortion", "distortion", 0.0, 1.0, 0.01)
	_add_slider(root, "Bitcrush bits", "bitcrush_bits", 2.0, 16.0, 0.5)
	_add_slider(root, "Ring mod amount", "ring_mod", 0.0, 1.0, 0.01)
	_add_slider(root, "Ring mod freq", "ring_mod_freq", 10.0, 1000.0, 1.0)
	_add_slider(root, "Chorus", "chorus", 0.0, 1.0, 0.01)
	_add_slider(root, "Delay mix", "delay_mix", 0.0, 1.0, 0.01)
	_add_slider(root, "Delay time (s)", "delay_time", 0.05, 1.0, 0.01)
	_add_slider(root, "Delay feedback", "delay_feedback", 0.0, 0.9, 0.01)
	_add_slider(root, "Reverb mix", "reverb_mix", 0.0, 1.0, 0.01)
	_add_slider(root, "Reverb decay (s)", "reverb_decay", 0.5, 8.0, 0.1)
	_add_slider(root, "Tremolo rate", "tremolo_rate", 0.0, 20.0, 0.1)
	_add_slider(root, "Tremolo depth", "tremolo_depth", 0.0, 1.0, 0.01)
	_add_slider(root, "Stereo width", "stereo_width", 0.0, 1.0, 0.01)
	_add_slider(root, "Volume", "volume", 0.0, 1.5, 0.01)

	root.add_child(HSeparator.new())
	root.add_child(_section_label("Export"))

	var path_row := HBoxContainer.new()
	root.add_child(path_row)
	_path_edit = LineEdit.new()
	_path_edit.text = "res://sfx_output/"
	_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_row.add_child(_path_edit)
	var browse_btn := Button.new()
	browse_btn.text = "Browse…"
	browse_btn.pressed.connect(_on_browse)
	path_row.add_child(browse_btn)

	var export_btn := Button.new()
	export_btn.text = "💾 Export WAV"
	export_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	export_btn.pressed.connect(_on_export)
	root.add_child(export_btn)

	var export_all_btn := Button.new()
	export_all_btn.text = "📦 Export All Presets"
	export_all_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	export_all_btn.pressed.connect(_on_export_all)
	root.add_child(export_all_btn)

	var open_btn := Button.new()
	open_btn.text = "📂 Open Output Folder"
	open_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open_btn.pressed.connect(_on_open_folder)
	root.add_child(open_btn)


func _section_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	return l


func _make_option(parent: Container, label_text: String, items: Array, key: String) -> OptionButton:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var lab := Label.new()
	lab.text = label_text
	lab.custom_minimum_size = Vector2(150, 0)
	row.add_child(lab)
	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in items.size():
		opt.add_item(String(items[i]), i)
	opt.item_selected.connect(_on_option_selected.bind(key))
	row.add_child(opt)
	return opt


func _add_slider(
	parent: Container, label_text: String, key: String, min_v: float, max_v: float, step: float
) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var lab := Label.new()
	lab.text = label_text
	lab.custom_minimum_size = Vector2(150, 0)
	row.add_child(lab)
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_on_slider_changed.bind(key))
	row.add_child(slider)
	var val := Label.new()
	val.custom_minimum_size = Vector2(64, 0)
	row.add_child(val)
	_sliders[key] = slider
	_value_labels[key] = val


## ---------------------------------------------------------------------------
## Parameter sync
## ---------------------------------------------------------------------------

func _refresh_ui() -> void:
	for key in _sliders.keys():
		var slider: HSlider = _sliders[key]
		var v: float = float(_params.get(key, slider.value))
		slider.set_value_no_signal(v)
		_update_value_label(key, v)
	_set_option(_mode_option, MODES.find(String(_params.get("mode", "osc"))))
	_set_option(_wave_option, int(_params.get("wave", 0)))
	_set_option(_noise_option, int(_params.get("noise_type", 0)))
	_set_option(_filter_option, int(_params.get("filter_type", 1)))
	_set_option(_distort_option, int(_params.get("distortion_type", 0)))
	_seed_spin.set_value_no_signal(float(_params.get("seed", 12345)))
	var sidx: int = _visible_sample_paths.find(String(_params.get("sample_path", "")))
	if sidx >= 0:
		_sample_option.select(sidx)
	_loop_check.set_pressed_no_signal(bool(_params.get("sample_loop", false)))
	_reverse_check.set_pressed_no_signal(bool(_params.get("sample_reverse", false)))


func _set_option(opt: OptionButton, idx: int) -> void:
	if opt != null and idx >= 0 and idx < opt.item_count:
		opt.select(idx)


func _update_value_label(key: String, v: float) -> void:
	var lab: Label = _value_labels.get(key, null)
	if lab != null:
		lab.text = str(v)


func _on_slider_changed(value: float, key: String) -> void:
	_params[key] = value
	_update_value_label(key, value)
	_current_preset = ""
	_status_label.text = "Custom parameters (modified)."


func _on_option_selected(index: int, key: String) -> void:
	if key == "mode":
		_params["mode"] = MODES[index]
		if MODES[index] == "sample":
			if String(_params.get("sample_path", "")) == "" and not _visible_sample_paths.is_empty():
				_params["sample_path"] = String(_visible_sample_paths[0])
				_sample_option.select(0)
	else:
		_params[key] = index
	_current_preset = ""
	_status_label.text = "Custom parameters (modified)."


func _on_seed_changed(value: float) -> void:
	_params["seed"] = int(value)


func _scan_samples() -> void:
	_sample_paths.clear()
	_collect_samples("res://samples")
	_sample_paths.sort()
	_refresh_sample_options()


func _collect_samples(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname != "." and fname != "..":
			var full: String = dir_path + "/" + fname
			if dir.current_is_dir():
				_collect_samples(full)
			elif fname.to_lower().ends_with(".wav") or fname.to_lower().ends_with(".ogg"):
				_sample_paths.append(full)
		fname = dir.get_next()
	dir.list_dir_end()


func _refresh_sample_options() -> void:
	if _sample_option == null:
		return
	var search: String = _sample_search.text.strip_edges().to_lower()
	var source_id: int = _sample_source_option.get_selected_id()
	_visible_sample_paths.clear()
	for sample_path in _sample_paths:
		var path: String = String(sample_path)
		var relative_path: String = path.replace("res://samples/", "")
		if not _sample_matches_source(relative_path, source_id):
			continue
		if search != "" and not relative_path.to_lower().contains(search):
			continue
		_visible_sample_paths.append(path)
	if _sample_sort_option.get_selected_id() == 1:
		_visible_sample_paths.sort_custom(_sort_samples_by_name)
	else:
		_visible_sample_paths.sort()

	_sample_option.clear()
	_sample_option.select(-1)
	if _visible_sample_paths.is_empty():
		_sample_option.add_item("(no samples match)")
		return
	for path in _visible_sample_paths:
		_sample_option.add_item(String(path).replace("res://samples/", ""))
	_sample_option.select(-1)
	var current_index: int = _visible_sample_paths.find(String(_params.get("sample_path", "")))
	if current_index >= 0:
		_sample_option.select(current_index)


func _sample_matches_source(relative_path: String, source_id: int) -> bool:
	if source_id == 1:
		return not relative_path.begins_with("community/")
	if SAMPLE_SOURCE_PREFIXES.has(source_id):
		return relative_path.begins_with(String(SAMPLE_SOURCE_PREFIXES[source_id]))
	return true


func _sort_samples_by_name(a: String, b: String) -> bool:
	var a_name: String = a.get_file().to_lower()
	var b_name: String = b.get_file().to_lower()
	if a_name == b_name:
		return a.to_lower() < b.to_lower()
	return a_name < b_name


func _on_sample_search_changed(_text: String) -> void:
	_refresh_sample_options()


func _on_sample_source_selected(_index: int) -> void:
	_refresh_sample_options()


func _on_sample_sort_selected(_index: int) -> void:
	_refresh_sample_options()


func _on_sample_selected(index: int) -> void:
	if index >= 0 and index < _visible_sample_paths.size():
		var sample_path: String = String(_visible_sample_paths[index])
		_params["sample_path"] = sample_path
		_params["mode"] = "sample"
		_set_option(_mode_option, MODES.find("sample"))
		_current_preset = ""
		_status_label.text = "Sample: %s" % sample_path.replace("res://samples/", "")


func _on_loop_toggled(pressed: bool) -> void:
	_params["sample_loop"] = pressed
	_current_preset = ""


func _on_reverse_toggled(pressed: bool) -> void:
	_params["sample_reverse"] = pressed
	_current_preset = ""


## ---------------------------------------------------------------------------
## Presets / randomization
## ---------------------------------------------------------------------------

func _load_preset(preset_name: String) -> void:
	var preset: Dictionary = SFXPresets.get_by_name(preset_name)
	if preset.is_empty():
		return
	_params = SFXSynthEngine.default_params()
	for k in (preset["params"] as Dictionary).keys():
		_params[k] = preset["params"][k]
	_current_preset = preset_name
	_refresh_ui()
	_status_label.text = "Loaded preset: %s (%s)" % [preset_name, String(preset["category"])]


func _on_preset_selected(index: int) -> void:
	if index >= 0 and index < _preset_names.size():
		_load_preset(String(_preset_names[index]))


func _on_category_selected(index: int) -> void:
	_preset_option.clear()
	_preset_names.clear()
	var cat: String = ""
	if index > 0:
		cat = String(SFXPresets.CATEGORIES[index - 1])
	for entry in SFXPresets.get_presets():
		if cat == "" or String(entry["category"]) == cat:
			_preset_option.add_item(String(entry["name"]))
			_preset_names.append(String(entry["name"]))
	if _preset_names.size() > 0:
		_preset_option.select(0)
		_load_preset(String(_preset_names[0]))


func _on_randomize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var cat: String = "any"
	if _category_option != null and _category_option.selected > 0:
		cat = String(SFXPresets.CATEGORIES[_category_option.selected - 1])
	_params = SFXSynthEngine.random_params(rng, cat)
	_current_preset = ""
	_refresh_ui()
	_status_label.text = "Randomized (%s, seed %d)." % [cat, int(_params["seed"])]


func _on_mutate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_params = SFXSynthEngine.mutate_params(_params, rng, 0.3)
	_current_preset = ""
	_refresh_ui()
	_status_label.text = "Mutated (seed %d)." % int(_params["seed"])


## ---------------------------------------------------------------------------
## Preview / export
## ---------------------------------------------------------------------------

func _on_preview() -> void:
	_status_label.text = "Rendering…"
	var stream: AudioStreamWAV = SFXSynthEngine.generate_stream(_params)
	_player.stream = stream
	_player.play()
	var label: String = _current_preset if _current_preset != "" else "Custom"
	_status_label.text = "Playing: %s (%.2fs)" % [label, float(_params.get("duration", 1.0))]


func _on_stop() -> void:
	_player.stop()
	_status_label.text = "Stopped."


func _sanitize(name: String) -> String:
	var out: String = ""
	for i in name.length():
		var c: String = name.substr(i, 1)
		if c.is_valid_identifier() or (c >= "0" and c <= "9") or c == " " or c == "-" or c == "_":
			out += c
	return out.strip_edges().replace(" ", "_").to_lower()


func _output_dir() -> String:
	var dir: String = _path_edit.text.strip_edges()
	if not dir.ends_with("/"):
		dir += "/"
	return dir


func _on_export() -> void:
	var dir: String = _output_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var base: String = _current_preset if _current_preset != "" else "custom_sfx"
	var path: String = dir + _sanitize(base) + ".wav"
	var err: Error = SFXSynthEngine.save_wav(path, _params)
	if err == OK:
		_status_label.text = "Exported: %s" % path
	else:
		_status_label.text = "Export failed (error %d): %s" % [err, path]


func _on_export_all() -> void:
	var dir: String = _output_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var count: int = 0
	for entry in SFXPresets.get_presets():
		var p: Dictionary = SFXSynthEngine.default_params()
		for k in (entry["params"] as Dictionary).keys():
			p[k] = entry["params"][k]
		var path: String = dir + _sanitize(String(entry["name"])) + ".wav"
		if SFXSynthEngine.save_wav(path, p) == OK:
			count += 1
	_status_label.text = "Exported %d presets to %s" % [count, dir]


func _on_browse() -> void:
	# In-editor folder picker is heavyweight; use the current path text and
	# let the user type/paste a res:// path. Show a hint.
	_status_label.text = "Type a res:// output folder path (e.g. res://sfx_output/), then Export."


func _on_open_folder() -> void:
	var abs_path: String = ProjectSettings.globalize_path(_output_dir())
	DirAccess.make_dir_recursive_absolute(abs_path)
	OS.shell_open(abs_path)
