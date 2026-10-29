class_name NornActor
extends CharacterBody3D

signal action_completed(actor_id: String, action_id: String, target_id: String)

const WALK_SPEED := 2.8
const ARRIVAL_DISTANCE := 1.05
const OBSERVATION_STOP_DISTANCE := 2.1
const SPHERE_RADIUS := 0.5
const WORLD_MIN_X := -11.5
const WORLD_MAX_X := 59.5
const WORLD_MIN_Z := -8.5
const WORLD_MAX_Z := 8.5
const NORN_MODEL_PATH := "res://assets/generated/norns/albia-norn/model.glb"
const HEAD_POSITION := Vector3(0.0, 1.7, -0.02)
const HEAD_SIZE := Vector3(0.78, 0.72, 0.66)

var current_action: String = "idle"
var action_reason: String = "Looking around the habitat"
var actor_id: String = ""
var display_name: String = "Norn"
var body_color: Color = Color(0.43, 0.27, 0.16)
var target: Node3D
var target_id: String = ""
var is_walking: bool = false
var _sensor: Area3D
var _visual_root: Node3D
var _name_label: Label3D
var _life_stage_label: Label3D
var _life_stage: String = "adult"
var _drawing_effector: Node3D
var _drawing_arm: MeshInstance3D
var _drawing_hand: Node3D
var _drawing_target_local := Vector3(0.45, 0.88, -0.76)
var _drawing_rest_local := Vector3(0.45, 0.88, -0.76)
var _drawing_tip_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("norn_actors")
	collision_layer = 1
	collision_mask = 1
	_build_collision()
	_build_body()
	_build_sensor()


func configure_identity(profile_actor_id: String, profile_display_name: String, profile_body_color: Color) -> void:
	actor_id = profile_actor_id
	display_name = profile_display_name
	body_color = profile_body_color
	name = profile_display_name
	if has_node("NameLabel"):
		get_node("NameLabel").queue_free()
	if has_node("LifeStageLabel"):
		get_node("LifeStageLabel").queue_free()
	_name_label = Label3D.new()
	_name_label.name = "NameLabel"
	_name_label.text = display_name
	_name_label.position = Vector3(0.0, 3.15, 0.0)
	_name_label.font_size = 24
	_name_label.modulate = Color(1.0, 0.92, 0.66)
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.outline_size = 6
	_name_label.outline_modulate = Color(0.1, 0.12, 0.08, 0.95)
	add_child(_name_label)
	_life_stage_label = Label3D.new()
	_life_stage_label.name = "LifeStageLabel"
	_life_stage_label.position = Vector3(0.0, 2.82, 0.0)
	_life_stage_label.font_size = 14
	_life_stage_label.modulate = Color(0.85, 0.91, 0.75)
	_life_stage_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_life_stage_label.outline_size = 4
	_life_stage_label.outline_modulate = Color(0.1, 0.12, 0.08, 0.95)
	add_child(_life_stage_label)
	_apply_life_stage()


func set_life_stage(stage: String) -> void:
	var normalized := stage.strip_edges().to_lower()
	if not ["baby", "child", "adolescent", "adult", "elder"].has(normalized):
		return
	_life_stage = normalized
	_apply_life_stage()


func _apply_life_stage() -> void:
	var scale_by_stage := {"baby": 0.55, "child": 0.70, "adolescent": 0.85, "adult": 1.0, "elder": 0.95}
	if _visual_root != null:
		_visual_root.scale = Vector3.ONE * float(scale_by_stage.get(_life_stage, 1.0))
	if _life_stage_label != null:
		_life_stage_label.text = _life_stage.capitalize()


func set_action_target(target_node: Node3D, action_id: String, reason: String, target_id_value: String = "") -> void:
	target = target_node
	current_action = action_id
	action_reason = reason
	target_id = target_id_value
	if target is Interactable and target_id.is_empty():
		target_id = (target as Interactable).object_id
	if target == null:
		velocity = Vector3.ZERO
		is_walking = false
	if action_id != "draw":
		set_drawing_effector_pose(Vector3.ZERO, false)


func set_drawing_effector_pose(surface_world_position: Vector3, contact: bool) -> void:
	if _drawing_effector == null or _drawing_hand == null or _visual_root == null:
		return
	if contact:
		var target_local := _visual_root.to_local(surface_world_position)
		var shoulder := Vector3(0.34, 1.22, -0.34)
		var reach := target_local - shoulder
		if reach.length() > 1.12:
			target_local = shoulder + reach.normalized() * 1.12
		_drawing_target_local = target_local
		if _drawing_tip_material != null:
			_drawing_tip_material.albedo_color = Color(0.12, 0.10, 0.075)
	else:
		_drawing_target_local = _drawing_rest_local
		if _drawing_tip_material != null:
			_drawing_tip_material.albedo_color = Color(0.34, 0.28, 0.20)


func sensed_interactables() -> Array[Interactable]:
	var sensed: Array[Interactable] = []
	if _sensor == null or not is_inside_tree():
		return sensed
	for body: Node3D in _sensor.get_overlapping_bodies():
		if body is Interactable and body.available and _has_line_of_sight(body):
			sensed.append(body)
	return sensed


func can_see_peer(peer: NornActor) -> bool:
	if peer == null or peer == self or not is_inside_tree() or not peer.is_inside_tree():
		return false
	var from := global_position + Vector3(0.0, 1.35, 0.0)
	var to := peer.global_position + Vector3(0.0, 1.35, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	query.collide_with_areas = false
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return not result.is_empty() and result.get("collider") == peer


func can_see_interactable(item: Interactable) -> bool:
	return item != null and item.available and item.is_inside_tree() and _has_line_of_sight(item)


func reset_position(position_value: Vector3) -> void:
	global_position = position_value
	velocity = Vector3.ZERO
	target = null
	target_id = ""
	current_action = "idle"
	action_reason = "Looking around the habitat"
	is_walking = false


func _physics_process(_delta: float) -> void:
	if target == null or not is_instance_valid(target):
		velocity = Vector3.ZERO
		is_walking = false
		return
	if target is Interactable and not (target as Interactable).available:
		target = null
		target_id = ""
		velocity = Vector3.ZERO
		is_walking = false
		return
	var direction := target.global_position - global_position
	direction.y = 0.0
	var arrival_distance := OBSERVATION_STOP_DISTANCE if current_action == "observe_peer" else ARRIVAL_DISTANCE
	if direction.length() <= arrival_distance:
		if current_action == "draw":
			velocity = Vector3.ZERO
			is_walking = false
			return
		var completed_target := target
		var completed_action := current_action
		var completed_target_id := target_id
		target = null
		target_id = ""
		velocity = Vector3.ZERO
		is_walking = false
		if completed_target is Interactable:
			action_completed.emit(actor_id, completed_action, completed_target_id)
		return
	var forward := direction.normalized()
	velocity.x = forward.x * WALK_SPEED
	velocity.z = forward.z * WALK_SPEED
	velocity.y = 0.0
	is_walking = true
	look_at(global_position + forward, Vector3.UP)
	move_and_slide()
	global_position.x = clampf(global_position.x, WORLD_MIN_X, WORLD_MAX_X)
	global_position.z = clampf(global_position.z, WORLD_MIN_Z, WORLD_MAX_Z)


func _process(delta: float) -> void:
	if _drawing_hand == null or _drawing_arm == null:
		return
	var blend := 1.0 - exp(-maxf(0.0, delta) * 15.0)
	_drawing_hand.position = _drawing_hand.position.lerp(_drawing_target_local, blend)
	_update_drawing_arm()


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
	_visual_root = Node3D.new()
	_visual_root.name = "LifeStageVisuals"
	add_child(_visual_root)
	var model_scene := load(NORN_MODEL_PATH) as PackedScene
	var model_instance: Node3D
	if model_scene != null:
		model_instance = model_scene.instantiate() as Node3D
	if model_instance != null:
		model_instance.name = "MeshyNornModel"
		model_instance.scale = Vector3.ONE * 2.4
		model_instance.position = Vector3(0.0, 1.14, 0.0)
		model_instance.rotation.y = PI
		_visual_root.add_child(model_instance)
	else:
		_build_procedural_body_geometry()
	_build_drawing_effector()
	_apply_life_stage()


func _build_procedural_body_geometry() -> void:
	var warm_brown := _material(body_color)
	var eye_socket := _material(body_color.darkened(0.18))
	var cream := _material(Color(0.92, 0.76, 0.51))
	var dark := _material(Color(0.08, 0.055, 0.04))
	var eye_white := _material(Color(0.96, 0.92, 0.78))
	_add_sphere("Body", Vector3(0.0, 0.78, 0.0), Vector3(0.82, 1.05, 0.68), warm_brown, 14, 8)
	_add_sphere("Belly", Vector3(0.0, 0.79, -0.29), Vector3(0.49, 0.7, 0.22), cream, 12, 7)
	_add_sphere("Head", HEAD_POSITION, HEAD_SIZE, warm_brown, 14, 8)
	_add_sphere("LeftEar", Vector3(-0.42, 2.13, 0.02), Vector3(0.38, 0.66, 0.25), warm_brown, 10, 6)
	_add_sphere("RightEar", Vector3(0.42, 2.13, 0.02), Vector3(0.38, 0.66, 0.25), warm_brown, 10, 6)
	_add_sphere("LeftEarInner", Vector3(-0.42, 2.19, -0.10), Vector3(0.15, 0.36, 0.08), cream, 8, 5)
	_add_sphere("RightEarInner", Vector3(0.42, 2.19, -0.10), Vector3(0.15, 0.36, 0.08), cream, 8, 5)
	var left_eye_x := -0.27
	var right_eye_x := 0.27
	var eye_y := 1.77
	var eyelid_y := 1.88
	_add_sphere("LeftEyeSocket", _front_surface_point(left_eye_x, eye_y, 0.012), Vector3(0.22, 0.26, 0.06), eye_socket, 10, 6)
	_add_sphere("RightEyeSocket", _front_surface_point(right_eye_x, eye_y, 0.012), Vector3(0.22, 0.26, 0.06), eye_socket, 10, 6)
	_add_sphere("LeftEye", _front_surface_point(left_eye_x, eye_y, 0.025), Vector3(0.16, 0.2, 0.08), eye_white, 10, 6)
	_add_sphere("RightEye", _front_surface_point(right_eye_x, eye_y, 0.025), Vector3(0.16, 0.2, 0.08), eye_white, 10, 6)
	_add_sphere("LeftPupil", _front_surface_point(-0.25, 1.76, 0.06), Vector3(0.075, 0.11, 0.05), dark, 8, 5)
	_add_sphere("RightPupil", _front_surface_point(0.25, 1.76, 0.06), Vector3(0.075, 0.11, 0.05), dark, 8, 5)
	_add_sphere("LeftEyelid", _front_surface_point(left_eye_x, eyelid_y, 0.018), Vector3(0.18, 0.07, 0.055), warm_brown, 10, 6)
	_add_sphere("RightEyelid", _front_surface_point(right_eye_x, eyelid_y, 0.018), Vector3(0.18, 0.07, 0.055), warm_brown, 10, 6)
	_add_sphere("Nose", _front_surface_point(0.0, 1.52, 0.04), Vector3(0.14, 0.1, 0.07), _material(Color(0.2, 0.1, 0.08)), 8, 5)


func _build_drawing_effector() -> void:
	_drawing_effector = Node3D.new()
	_drawing_effector.name = "DrawingEffector"
	_visual_root.add_child(_drawing_effector)
	_drawing_arm = MeshInstance3D.new()
	_drawing_arm.name = "Arm"
	var arm_mesh := CapsuleMesh.new()
	arm_mesh.radius = 0.065
	arm_mesh.height = 1.0
	arm_mesh.radial_segments = 8
	arm_mesh.rings = 3
	_drawing_arm.mesh = arm_mesh
	_drawing_arm.material_override = _material(body_color.darkened(0.06))
	_drawing_effector.add_child(_drawing_arm)
	_drawing_hand = Node3D.new()
	_drawing_hand.name = "Hand"
	_drawing_hand.position = _drawing_rest_local
	_drawing_effector.add_child(_drawing_hand)
	var palm := MeshInstance3D.new()
	palm.name = "Palm"
	var palm_mesh := SphereMesh.new()
	palm_mesh.radius = 0.11
	palm_mesh.height = 0.22
	palm_mesh.radial_segments = 8
	palm_mesh.rings = 5
	palm.mesh = palm_mesh
	palm.material_override = _material(body_color.lightened(0.08))
	_drawing_hand.add_child(palm)
	var charcoal := MeshInstance3D.new()
	charcoal.name = "CharcoalTip"
	var charcoal_mesh := CylinderMesh.new()
	charcoal_mesh.top_radius = 0.018
	charcoal_mesh.bottom_radius = 0.035
	charcoal_mesh.height = 0.28
	charcoal_mesh.radial_segments = 6
	charcoal.mesh = charcoal_mesh
	charcoal.position = Vector3(0.0, -0.04, -0.16)
	charcoal.rotation.x = -PI * 0.5
	_drawing_tip_material = _material(Color(0.34, 0.28, 0.20))
	charcoal.material_override = _drawing_tip_material
	_drawing_hand.add_child(charcoal)
	_update_drawing_arm()


func _update_drawing_arm() -> void:
	if _drawing_arm == null or _drawing_hand == null:
		return
	var shoulder := Vector3(0.34, 1.22, -0.34)
	var direction := _drawing_hand.position - shoulder
	var length := maxf(0.08, direction.length())
	_drawing_arm.position = shoulder + direction * 0.5
	_drawing_arm.rotation = Quaternion(Vector3.UP, direction.normalized()).get_euler()
	_drawing_arm.scale = Vector3(1.0, length, 1.0)


func _front_surface_point(x: float, y: float, outward_offset: float = 0.0) -> Vector3:
	var radii := HEAD_SIZE * SPHERE_RADIUS
	var normalized_x := (x - HEAD_POSITION.x) / radii.x
	var normalized_y := (y - HEAD_POSITION.y) / radii.y
	var remaining := maxf(0.0, 1.0 - normalized_x * normalized_x - normalized_y * normalized_y)
	var front_z := HEAD_POSITION.z - radii.z * sqrt(remaining)
	return Vector3(x, y, front_z - outward_offset)


func _add_sphere(label: String, at: Vector3, scale_value: Vector3, material: Material, segments: int, rings: int) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = label
	var sphere := SphereMesh.new()
	sphere.radius = SPHERE_RADIUS
	sphere.height = 1.0
	sphere.radial_segments = segments
	sphere.rings = rings
	mesh_instance.mesh = sphere
	mesh_instance.position = at
	mesh_instance.scale = scale_value
	mesh_instance.material_override = material
	if _visual_root != null:
		_visual_root.add_child(mesh_instance)
	else:
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
	var excluded: Array[RID] = [get_rid()]
	if is_inside_tree():
		for node: Node in get_tree().get_nodes_in_group("norn_actors"):
			if node != self and node is NornActor:
				excluded.append((node as NornActor).get_rid())
	var query := PhysicsRayQueryParameters3D.create(from, to, 3, excluded)
	query.collide_with_areas = false
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return not result.is_empty() and result.get("collider") == item


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	return material
