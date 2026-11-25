@tool
extends EditorPlugin
## SFX Generator — procedural sound-effect synthesizer for Godot 4.
##
## Adds a dock (View > SFX Generator) with preset browsing, live preview,
## parameter editing, randomization and WAV export.
##
## Supports both the Godot <= 4.3 dock API (add_dock(control, slot)) and the
## Godot 4.4+ API (add_dock(EditorDock)) via runtime detection, so the same
## code parses and runs on either version.

const DockScript := preload("res://addons/sfx_generator/sfx_dock.gd")

var _dock: Control = null


func _enter_tree() -> void:
	var content: Control = DockScript.new()
	content.name = "SFX Generator"
	if ClassDB.class_exists("EditorDock"):
		# Godot 4.4+: docks are EditorDock nodes.
		var dock: Variant = ClassDB.instantiate("EditorDock")
		dock.set("title", "SFX Generator")
		dock.set("default_slot", ClassDB.class_get_integer_constant("EditorDock", "DOCK_SLOT_RIGHT_UL"))
		dock.set("closable", true)
		dock.add_child(content)
		_dock = dock
		call("add_dock", dock)
	else:
		# Godot <= 4.3: plain Control + slot constant.
		_dock = content
		var slot: int = ClassDB.class_get_integer_constant("EditorPlugin", "DOCK_SLOT_RIGHT_UL")
		call("add_dock", content, slot)


func _exit_tree() -> void:
	if _dock != null:
		call("remove_dock", _dock)
		_dock.queue_free()
		_dock = null
