class_name NornActor
extends CharacterBody3D

signal action_completed(action_id: String, target_id: String)

const WALK_SPEED := 2.8
const ARRIVAL_DISTANCE := 1.05

var current_action: String = "idle"
var action_reason: String = "Looking around the habitat"
var target: Interactable
var is_walking: bool = false
var _sensor: Area3D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	_build_collision()
	_build_body()
	_build_sensor()


func set_action_target(target_node: Node3D, action_id: String, reason: String) -> void:
	target = target_node as Interactable if target_node is Interactable else null
	current_action = action_id
	action_reason = reason
	if target == null:
		velocity = Vector3.ZERO
		is_walking = false


func sensed_interactables() -> Array[Interactable]:
	var sensed: Array[Interactable] = []
	if _sensor == null or not is_inside_tree():
		return sensed
	for body: Node3D in _sensor.get_overlapping_bodies():
		if body is Interactable and body.available and _has_line_of_sight(body):
			sensed.append(body)
	return sensed


func reset_position(position_value: Vector3) -> void:
	global_position = position_value
	velocity = Vector3.ZERO
	target = null
	current_action = "idle"
	action_reason = "Looking around the habitat"
	is_walking = false


func _physics_process(_delta: float) -> void:
	if target == null or not is_instance_valid(target) or not target.available:
		velocity = Vector3.ZERO
		is_walking = false
		return
	var direction := target.global_position - global_position
	direction.y = 0.0
	if direction.length() <= ARRIVAL_DISTANCE:
		var completed_target := target
		var completed_action := current_action
		target = null
		velocity = Vector3.ZERO
		is_walking = false
		action_completed.emit(completed_action, completed_target.object_id)
		return
	var forward := direction.normalized()
	velocity.x = forward.x * WALK_SPEED
	velocity.z = forward.z * WALK_SPEED
	velocity.y = 0.0
	is_walking = true
	look_at(global_position + forward, Vector3.UP)
	move_and_slide()


func _build_collision() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "BodyCollision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.75
	collision.shape = capsule
	collision.position.y = 0.88
	add_child(collision)


func _build_body() -> void:
	var warm_brown := _material(Color(0.43, 0.27, 0.16))
	var cream := _material(Color(0.92, 0.76, 0.51))
	var dark := _material(Color(0.08, 0.055, 0.04))
	var eye_white := _material(Color(0.96, 0.92, 0.78))
	_add_sphere("Body", Vector3(0.0, 0.78, 0.0), Vector3(0.82, 1.05, 0.68), warm_brown, 14, 8)
	_add_sphere("Belly", Vector3(0.0, 0.79, -0.29), Vector3(0.49, 0.7, 0.22), cream, 12, 7)
	_add_sphere("Head", Vector3(0.0, 1.7, -0.02), Vector3(0.78, 0.72, 0.66), warm_brown, 14, 8)
	_add_sphere("LeftEar", Vector3(-0.57, 2.18, 0.02), Vector3(0.27, 0.56, 0.25), warm_brown, 10, 6)
	_add_sphere("RightEar", Vector3(0.57, 2.18, 0.02), Vector3(0.27, 0.56, 0.25), warm_brown, 10, 6)
	_add_sphere("LeftEarInner", Vector3(-0.57, 2.19, -0.19), Vector3(0.15, 0.36, 0.08), cream, 8, 5)
	_add_sphere("RightEarInner", Vector3(0.57, 2.19, -0.19), Vector3(0.15, 0.36, 0.08), cream, 8, 5)
	_add_sphere("LeftEye", Vector3(-0.27, 1.77, -0.58), Vector3(0.16, 0.2, 0.08), eye_white, 10, 6)
	_add_sphere("RightEye", Vector3(0.27, 1.77, -0.58), Vector3(0.16, 0.2, 0.08), eye_white, 10, 6)
	_add_sphere("LeftPupil", Vector3(-0.25, 1.76, -0.65), Vector3(0.075, 0.11, 0.05), dark, 8, 5)
	_add_sphere("RightPupil", Vector3(0.29, 1.76, -0.65), Vector3(0.075, 0.11, 0.05), dark, 8, 5)
	_add_sphere("Nose", Vector3(0.0, 1.52, -0.66), Vector3(0.15, 0.11, 0.09), _material(Color(0.2, 0.1, 0.08)), 8, 5)


func _add_sphere(label: String, at: Vector3, scale_value: Vector3, material: Material, segments: int, rings: int) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = label
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = segments
	sphere.rings = rings
	mesh_instance.mesh = sphere
	mesh_instance.position = at
	mesh_instance.scale = scale_value
	mesh_instance.material_override = material
	add_child(mesh_instance)


func _build_sensor() -> void:
	_sensor = Area3D.new()
	_sensor.name = "LocalSensor"
	_sensor.collision_layer = 0
	_sensor.collision_mask = 2
	_sensor.monitoring = true
	_sensor.position.y = 1.0
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 10.0
	collision.shape = sphere
	_sensor.add_child(collision)
	add_child(_sensor)


func _has_line_of_sight(item: Interactable) -> bool:
	var from := global_position + Vector3(0.0, 1.35, 0.0)
	var to := item.global_position + Vector3(0.0, 0.55, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, to, 2, [get_rid()])
	query.collide_with_areas = false
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return not result.is_empty() and result.get("collider") == item


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	return material
