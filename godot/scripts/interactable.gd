class_name Interactable
extends StaticBody3D

var object_id: String = ""
var kind: String = ""
var display_name: String = ""
var affordances: Array[String] = []
var available: bool = true
var _visual_root: Node3D
var _collision_shape: CollisionShape3D
var _pulse_time: float = 0.0
var _hide_after_pulse: bool = false


func configure(identifier: String, object_kind: String, label: String, actions: Array[String]) -> void:
	object_id = identifier
	kind = object_kind
	display_name = label
	affordances = actions.duplicate()
	add_to_group("interactable")


func set_visual_root(node: Node3D) -> void:
	_visual_root = node
	add_child(node)


func set_collision(node: CollisionShape3D) -> void:
	_collision_shape = node
	add_child(node)


func set_available(value: bool) -> void:
	available = value
	if _visual_root != null:
		_visual_root.visible = value
	if _collision_shape != null:
		_collision_shape.disabled = not value
	if value:
		_pulse_time = 0.0
		_hide_after_pulse = false


func pulse() -> void:
	_pulse_time = 1.0
	_hide_after_pulse = false


func activate() -> void:
	available = false
	if _collision_shape != null:
		_collision_shape.disabled = true
	if kind == "toy":
		_hide_after_pulse = true
		_pulse_time = 1.0
	else:
		_hide_after_pulse = false
		if _visual_root != null:
			_visual_root.visible = false


func _process(delta: float) -> void:
	if _pulse_time <= 0.0:
		return
	_pulse_time = maxf(0.0, _pulse_time - delta)
	if _visual_root != null:
		_visual_root.rotation.y += delta * 7.0
		if _pulse_time <= 0.0 and _hide_after_pulse:
			_visual_root.visible = false
