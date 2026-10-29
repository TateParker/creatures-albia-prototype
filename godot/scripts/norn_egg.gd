class_name NornEgg
extends Node3D

const INCUBATION_SECONDS := 45.0

var record: Dictionary = {}
var _completed := false
var _visuals_built := false
var _progress_label: Label3D


func configure(egg_record: Dictionary) -> void:
	record = egg_record.duplicate(true)
	name = str(record.get("eggId", "NornEgg"))
	_completed = float(record.get("remainingSeconds", INCUBATION_SECONDS)) <= 0.0
	_build_visuals()
	_update_progress_label()


func advance(delta_seconds: float) -> bool:
	if _completed or not is_finite(delta_seconds) or delta_seconds < 0.0:
		return false
	var remaining_value = record.get("remainingSeconds", null)
	if typeof(remaining_value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(remaining_value)) or float(remaining_value) < 0.0:
		return false
	var remaining := maxf(0.0, float(remaining_value) - delta_seconds)
	record["remainingSeconds"] = remaining
	_update_progress_label()
	if remaining > 0.0:
		return false
	_completed = true
	return true


func serialize_state() -> Dictionary:
	return record.duplicate(true) if not record.is_empty() else {}


func _build_visuals() -> void:
	if _visuals_built:
		return
	_visuals_built = true
	var color_values: Variant = record.get("bodyColor", [0.76, 0.67, 0.45, 1.0])
	var shell_color := Color(0.76, 0.67, 0.45, 1.0)
	if color_values is Array and color_values.size() == 4:
		shell_color = Color(float(color_values[0]), float(color_values[1]), float(color_values[2]), float(color_values[3])).lerp(Color(0.92, 0.83, 0.66), 0.45)
	var shell := MeshInstance3D.new()
	shell.name = "EggShell"
	var sphere := SphereMesh.new()
	sphere.radius = 0.38
	sphere.height = 0.86
	shell.mesh = sphere
	shell.position.y = 0.45
	shell.material_override = _material(shell_color)
	add_child(shell)
	var shine := MeshInstance3D.new()
	shine.name = "EggShine"
	var shine_mesh := SphereMesh.new()
	shine_mesh.radius = 0.075
	shine_mesh.height = 0.17
	shine.mesh = shine_mesh
	shine.position = Vector3(-0.16, 0.62, -0.24)
	shine.material_override = _material(Color(1.0, 0.96, 0.85, 0.72))
	add_child(shine)
	_progress_label = Label3D.new()
	_progress_label.name = "ProgressLabel"
	_progress_label.position.y = 1.15
	_progress_label.font_size = 14
	_progress_label.modulate = Color(1.0, 0.96, 0.82)
	_progress_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_progress_label.outline_size = 4
	_progress_label.outline_modulate = Color(0.12, 0.14, 0.1, 0.95)
	add_child(_progress_label)
	_update_progress_label()


func _update_progress_label() -> void:
	if _progress_label == null:
		return
	var remaining := clampf(float(record.get("remainingSeconds", INCUBATION_SECONDS)), 0.0, INCUBATION_SECONDS)
	var progress := 100.0 * (1.0 - remaining / INCUBATION_SECONDS)
	_progress_label.text = "%s\n%.0f%%" % [str(record.get("displayName", "Egg")), progress]


func _material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.3
	return result
