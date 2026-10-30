class_name NornActor
extends CharacterBody3D

const NornActionPoseModifierScript = preload("res://scripts/norn_action_pose_modifier.gd")

signal action_completed(actor_id: String, action_id: String, target_id: String)

const WALK_SPEED := 2.8
const WALK_CYCLE_DISTANCE := 1.2
const FOOT_STANCE_FRACTION := 0.48
const FOOT_SWING_LIFT := 0.14
const FOOT_IK_BLEND_TIME := 0.12
const ARRIVAL_DISTANCE := 1.05
const OBSERVATION_STOP_DISTANCE := 2.1
const SPHERE_RADIUS := 0.5
const WORLD_MIN_X := -11.5
const WORLD_MAX_X := 59.5
const WORLD_MIN_Z := -8.5
const WORLD_MAX_Z := 8.5
const RIGGED_NORN_MODEL_PATH := "res://assets/generated/norns/albia-norn-rigged/model.glb"
const NORN_MODEL_PATH := "res://assets/generated/norns/albia-norn/model.glb"
const REQUIRED_RIG_BONE_COUNT := 25
const REQUIRED_RIG_ANIMATIONS: Array[String] = ["idle", "walk", "curious", "praised", "scolded"]
const GAZE_OBJECT_TARGET_HEIGHT := 0.45
const GAZE_PEER_TARGET_HEIGHT := 1.5
const GAZE_NEUTRAL_DISTANCE := 2.0
const GAZE_ORIGIN_HEIGHT := 1.52
const GAZE_YAW_LIMIT := deg_to_rad(32.0)
const GAZE_PITCH_LIMIT := deg_to_rad(18.0)
const INTERACTION_GAZE_DURATION := 0.9
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
var _animation_player: AnimationPlayer
var _response_animation_active: bool = false
var _skeleton: Skeleton3D
var _head_look_modifier: LookAtModifier3D
var _gaze_target: Node3D
var _gaze_focus: Node3D
var _interaction_gaze_position := Vector3.ZERO
var _interaction_gaze_remaining := 0.0
var _action_pose_modifier: SkeletonModifier3D
var _foot_ik_modifiers: Array[TwoBoneIK3D] = []
var _foot_targets: Array[Node3D] = []
var _foot_poles: Array[Node3D] = []
var _foot_bone_indices: Array[int] = []
var _foot_local_offsets: Array[Vector3] = []
var _foot_planted_positions: Array[Vector3] = []
var _foot_was_in_stance: Array[bool] = []
var _walk_travel_distance: float = 0.0
var _walk_gait_phase: float = 0.0
var _measured_horizontal_speed: float = 0.0
var _movement_direction: Vector3 = Vector3.ZERO
var _last_foot_plant_direction: Vector3 = Vector3.ZERO
var _foot_planting_was_walking: bool = false
var _foot_ik_blend: float = 0.0
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
	if target_node != null:
		_gaze_focus = target_node
		_interaction_gaze_remaining = 0.0
	elif action_id == "observe_peer":
		if not is_instance_valid(_gaze_focus):
			_gaze_focus = _find_norn_target(target_id_value)
	else:
		_gaze_focus = null
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
	_measured_horizontal_speed = 0.0
	_walk_travel_distance = 0.0
	_walk_gait_phase = 0.0
	_gaze_focus = null
	_interaction_gaze_remaining = 0.0


func _physics_process(delta: float) -> void:
	_update_head_gaze(delta)
	if target == null or not is_instance_valid(target):
		velocity = Vector3.ZERO
		_measured_horizontal_speed = 0.0
		is_walking = false
		return
	if target is Interactable and not (target as Interactable).available:
		target = null
		target_id = ""
		velocity = Vector3.ZERO
		_measured_horizontal_speed = 0.0
		is_walking = false
		return
	var direction := target.global_position - global_position
	direction.y = 0.0
	var arrival_distance := OBSERVATION_STOP_DISTANCE if current_action == "observe_peer" else ARRIVAL_DISTANCE
	if direction.length() <= arrival_distance:
		if current_action == "draw":
			velocity = Vector3.ZERO
			_measured_horizontal_speed = 0.0
			is_walking = false
			return
		var completed_target := target
		var completed_action := current_action
		var completed_target_id := target_id
		target = null
		target_id = ""
		velocity = Vector3.ZERO
		_measured_horizontal_speed = 0.0
		is_walking = false
		if completed_target is Interactable:
			action_completed.emit(actor_id, completed_action, completed_target_id)
		return
	var forward := direction.normalized()
	velocity.x = forward.x * WALK_SPEED
	velocity.z = forward.z * WALK_SPEED
	velocity.y = 0.0
	is_walking = true
	if _action_pose_modifier != null:
		_action_pose_modifier.call("cancel_action")
	_movement_direction = forward
	look_at(global_position + forward, Vector3.UP)
	var previous_position := global_position
	move_and_slide()
	global_position.x = clampf(global_position.x, WORLD_MIN_X, WORLD_MAX_X)
	global_position.z = clampf(global_position.z, WORLD_MIN_Z, WORLD_MAX_Z)
	var horizontal_displacement := global_position - previous_position
	horizontal_displacement.y = 0.0
	_measured_horizontal_speed = horizontal_displacement.length() / maxf(delta, 0.0001)
	_walk_travel_distance += horizontal_displacement.length()
	_walk_gait_phase = fposmod(_walk_travel_distance / WALK_CYCLE_DISTANCE, 1.0)


func _process(delta: float) -> void:
	_update_model_animation()
	_update_foot_planting(delta)
	if _drawing_hand == null or _drawing_arm == null:
		return
	var blend := 1.0 - exp(-maxf(0.0, delta) * 15.0)
	_drawing_hand.position = _drawing_hand.position.lerp(_drawing_target_local, blend)
	_update_drawing_arm()


func play_response_animation(feedback: String) -> void:
	if _animation_player == null:
		return
	var animation_name := "praised" if feedback == "praise" else "scolded" if feedback == "scold" else ""
	if animation_name.is_empty() or not _animation_player.has_animation(animation_name):
		return
	if _action_pose_modifier != null:
		_action_pose_modifier.call("cancel_action")
	_gaze_focus = null
	_interaction_gaze_remaining = 0.0
	_response_animation_active = true
	_animation_player.speed_scale = 1.0
	_animation_player.play(animation_name)


func play_interaction_animation(action_id: String, target_position: Vector3) -> bool:
	if _action_pose_modifier == null or _response_animation_active:
		return false
	var pose_by_action := {"fruit": "eat", "forage": "forage", "drink": "drink", "spinner": "play"}
	var pose_id := str(pose_by_action.get(action_id, ""))
	if pose_id.is_empty() or not bool(_action_pose_modifier.call("play_action", pose_id)):
		return false
	_gaze_focus = null
	_interaction_gaze_position = target_position + Vector3.UP * GAZE_OBJECT_TARGET_HEIGHT
	_interaction_gaze_remaining = INTERACTION_GAZE_DURATION
	return true


func _update_model_animation() -> void:
	if _animation_player == null or _response_animation_active:
		return
	var animation_name := "walk" if is_walking else "idle"
	if not is_walking and current_action in ["observe_peer", "explore"]:
		animation_name = "curious"
	if not _animation_player.has_animation(animation_name):
		animation_name = "idle"
	_animation_player.speed_scale = _walk_speed_scale_for(_measured_horizontal_speed) if animation_name == "walk" else 1.0
	if _animation_player.current_animation != animation_name or not _animation_player.is_playing():
		_animation_player.play(animation_name)


func _walk_speed_scale_for(speed: float) -> float:
	if _animation_player == null or not _animation_player.has_animation("walk") or speed <= 0.0:
		return 0.0
	var walk_animation := _animation_player.get_animation("walk")
	return walk_animation.length * speed / WALK_CYCLE_DISTANCE


func _configure_action_pose_modifier(skeleton: Skeleton3D) -> void:
	if skeleton == null:
		return
	for bone_name: String in ["head", "neck", "chest", "arm_upper.L", "arm_lower.L", "arm_upper.R", "arm_lower.R"]:
		if skeleton.find_bone(bone_name) < 0:
			return
	_action_pose_modifier = NornActionPoseModifierScript.new() as SkeletonModifier3D
	_action_pose_modifier.name = "ActionPoseModifier"
	skeleton.add_child(_action_pose_modifier)


func _configure_head_gaze(skeleton: Skeleton3D) -> void:
	if skeleton == null or skeleton.find_bone("head") < 0:
		return
	_gaze_target = Node3D.new()
	_gaze_target.name = "GazeTarget"
	add_child(_gaze_target)
	_gaze_target.global_position = _neutral_gaze_point()
	_head_look_modifier = LookAtModifier3D.new()
	_head_look_modifier.name = "HeadLookAt"
	_head_look_modifier.bone_name = "head"
	_head_look_modifier.forward_axis = LookAtModifier3D.BONE_AXIS_PLUS_Z
	_head_look_modifier.relative = false
	_head_look_modifier.use_angle_limitation = true
	_head_look_modifier.symmetry_limitation = false
	_head_look_modifier.primary_positive_limit_angle = deg_to_rad(35.0)
	_head_look_modifier.primary_negative_limit_angle = deg_to_rad(35.0)
	_head_look_modifier.secondary_positive_limit_angle = deg_to_rad(22.0)
	_head_look_modifier.secondary_negative_limit_angle = deg_to_rad(22.0)
	_head_look_modifier.duration = 0.0
	_head_look_modifier.active = true
	skeleton.add_child(_head_look_modifier)
	_head_look_modifier.target_node = _head_look_modifier.get_path_to(_gaze_target)


func _update_head_gaze(delta: float) -> void:
	if _gaze_target == null or not is_instance_valid(_gaze_target):
		return
	var desired_gaze_position := _neutral_gaze_point()
	if _interaction_gaze_remaining > 0.0:
		desired_gaze_position = _interaction_gaze_position
		_interaction_gaze_remaining = maxf(0.0, _interaction_gaze_remaining - maxf(delta, 0.0))
	elif is_instance_valid(_gaze_focus):
		var target_height := GAZE_PEER_TARGET_HEIGHT if _gaze_focus is NornActor else GAZE_OBJECT_TARGET_HEIGHT
		desired_gaze_position = _gaze_focus.global_position + Vector3.UP * target_height
	desired_gaze_position = _bounded_gaze_position(desired_gaze_position)
	var blend := 1.0 - exp(-maxf(0.0, delta) * 9.0)
	_gaze_target.global_position = _gaze_target.global_position.lerp(desired_gaze_position, blend)


func _bounded_gaze_position(target_position: Vector3) -> Vector3:
	var forward := -global_transform.basis.z.normalized()
	var right := global_transform.basis.x.normalized()
	var up := global_transform.basis.y.normalized()
	var origin := global_position + up * GAZE_ORIGIN_HEIGHT
	var offset := target_position - origin
	var distance := maxf(offset.length(), 1.0)
	var direction := offset.normalized() if offset.length_squared() > 0.000001 else forward
	var yaw := clampf(atan2(direction.dot(right), direction.dot(forward)), -GAZE_YAW_LIMIT, GAZE_YAW_LIMIT)
	var pitch := clampf(asin(clampf(direction.dot(up), -1.0, 1.0)), -GAZE_PITCH_LIMIT, GAZE_PITCH_LIMIT)
	var horizontal := forward * cos(yaw) + right * sin(yaw)
	var bounded_direction := horizontal * cos(pitch) + up * sin(pitch)
	return origin + bounded_direction.normalized() * distance


func _neutral_gaze_point() -> Vector3:
	var forward := -global_transform.basis.z.normalized()
	return global_position + forward * GAZE_NEUTRAL_DISTANCE + Vector3.UP * 1.7


func _find_norn_target(target_actor_id: String) -> Node3D:
	if target_actor_id.is_empty() or not is_inside_tree():
		return null
	for candidate: Node in get_tree().get_nodes_in_group("norn_actors"):
		if candidate is NornActor and (candidate as NornActor).actor_id == target_actor_id:
			return candidate as Node3D
	return null


func _configure_foot_planting(skeleton: Skeleton3D) -> void:
	_skeleton = skeleton
	if skeleton == null:
		return
	for side: String in ["L", "R"]:
		for bone_name: String in ["leg_upper." + side, "leg_lower." + side, "foot." + side]:
			if skeleton.find_bone(bone_name) < 0:
				return

	for index: int in range(2):
		var side := "L" if index == 0 else "R"
		var label := "Left" if index == 0 else "Right"
		var foot_bone_name := "foot." + side
		var foot_bone_index := skeleton.find_bone(foot_bone_name)
		var foot_pose := skeleton.get_bone_global_pose(foot_bone_index)
		var foot_world_position := skeleton.global_transform * foot_pose.origin
		var foot_local_offset := global_transform.affine_inverse() * foot_world_position

		var foot_target := Node3D.new()
		foot_target.name = label + "FootTarget"
		skeleton.add_child(foot_target)
		foot_target.global_position = foot_world_position

		var knee_pole := Node3D.new()
		knee_pole.name = label + "KneePole"
		skeleton.add_child(knee_pole)
		knee_pole.global_position = foot_world_position + global_transform.basis.z.normalized() * 0.28 + Vector3.UP * 0.14

		var ik := TwoBoneIK3D.new()
		ik.name = label + "FootIK"
		skeleton.add_child(ik)
		ik.set_setting_count(1)
		ik.set_root_bone_name(0, "leg_upper." + side)
		ik.set_middle_bone_name(0, "leg_lower." + side)
		ik.set_end_bone_name(0, foot_bone_name)
		ik.set_target_node(0, ik.get_path_to(foot_target))
		ik.set_pole_node(0, ik.get_path_to(knee_pole))
		ik.influence = 0.0

		_foot_ik_modifiers.append(ik)
		_foot_targets.append(foot_target)
		_foot_poles.append(knee_pole)
		_foot_bone_indices.append(foot_bone_index)
		_foot_local_offsets.append(foot_local_offset)
		_foot_planted_positions.append(foot_world_position)
		_foot_was_in_stance.append(false)


func _update_foot_planting_targets(gait_phase: float) -> void:
	if _foot_targets.size() != 2:
		return
	for index: int in range(2):
		var phase_offset := 0.0 if index == 0 else 0.5
		var foot_phase := fposmod(gait_phase + phase_offset, 1.0)
		var in_stance := foot_phase < FOOT_STANCE_FRACTION
		var current_foot_position := global_transform * _foot_local_offsets[index]
		if in_stance:
			if not _foot_was_in_stance[index]:
				_foot_planted_positions[index] = current_foot_position
			_foot_targets[index].global_position = _foot_planted_positions[index]
		else:
			var swing_progress := (foot_phase - FOOT_STANCE_FRACTION) / (1.0 - FOOT_STANCE_FRACTION)
			var eased_progress := swing_progress * swing_progress * (3.0 - 2.0 * swing_progress)
			var target_position := _foot_planted_positions[index].lerp(current_foot_position, eased_progress)
			target_position.y += sin(swing_progress * PI) * FOOT_SWING_LIFT
			_foot_targets[index].global_position = target_position
		_foot_poles[index].global_position = _foot_targets[index].global_position + global_transform.basis.z.normalized() * 0.28 + Vector3.UP * 0.14
		_foot_was_in_stance[index] = in_stance


func _update_foot_planting(delta: float) -> void:
	if _foot_ik_modifiers.size() != 2:
		return
	var should_plant := is_walking and not _response_animation_active and _animation_player != null and _animation_player.current_animation == "walk"
	if should_plant:
		var direction := _movement_direction.normalized() if _movement_direction.length_squared() > 0.0001 else -global_transform.basis.z.normalized()
		if not _foot_planting_was_walking or _last_foot_plant_direction.dot(direction) < 0.5:
			_walk_travel_distance = 0.0
			_walk_gait_phase = 0.0
			for index: int in range(2):
				_foot_was_in_stance[index] = false
				_foot_planted_positions[index] = global_transform * _foot_local_offsets[index]
		_last_foot_plant_direction = direction
		_update_foot_planting_targets(_walk_gait_phase)
	else:
		_walk_travel_distance = 0.0
		_walk_gait_phase = 0.0
		for index: int in range(2):
			_foot_was_in_stance[index] = false
	_foot_planting_was_walking = should_plant
	_foot_ik_blend = move_toward(_foot_ik_blend, 1.0 if should_plant else 0.0, maxf(delta, 0.0) / FOOT_IK_BLEND_TIME)
	for ik: TwoBoneIK3D in _foot_ik_modifiers:
		ik.influence = _foot_ik_blend


func _on_model_animation_finished(animation_name: StringName) -> void:
	if str(animation_name) in ["praised", "scolded"]:
		_response_animation_active = false
		_update_model_animation()


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
	var model_instance := _instantiate_norn_model(RIGGED_NORN_MODEL_PATH)
	if model_instance != null:
		model_instance.name = "MeshyNornModel"
		model_instance.scale = Vector3.ONE * 2.4
		model_instance.position = Vector3(0.0, 1.14, 0.0)
		model_instance.rotation.y = PI
		_visual_root.add_child(model_instance)
		var skeleton := _find_first_node_of_type(model_instance, "Skeleton3D") as Skeleton3D
		_configure_foot_planting(skeleton)
		_configure_action_pose_modifier(skeleton)
		_configure_head_gaze(skeleton)
		_animation_player = _find_first_node_of_type(model_instance, "AnimationPlayer") as AnimationPlayer
		_configure_model_animations()
	else:
		_build_procedural_body_geometry()
	_build_drawing_effector()
	_apply_life_stage()


func _instantiate_norn_model(rigged_model_path: String) -> Node3D:
	var model_scene: PackedScene
	if ResourceLoader.exists(rigged_model_path):
		model_scene = load(rigged_model_path) as PackedScene
	var fallback_scene := load(NORN_MODEL_PATH) as PackedScene
	return _instantiate_model_scene_or_fallback(model_scene, fallback_scene)


func _instantiate_model_scene_or_fallback(candidate_scene: PackedScene, fallback_scene: PackedScene) -> Node3D:
	if candidate_scene != null:
		var candidate_instance := candidate_scene.instantiate()
		if _is_usable_rigged_model_instance(candidate_instance):
			return candidate_instance as Node3D
		if candidate_instance != null:
			candidate_instance.free()
	if fallback_scene == null:
		return null
	var fallback_instance := fallback_scene.instantiate()
	if fallback_instance is Node3D:
		return fallback_instance as Node3D
	if fallback_instance != null:
		fallback_instance.free()
	return null


func _is_usable_rigged_model_instance(model_instance: Node) -> bool:
	if not model_instance is Node3D:
		return false
	var skeleton := _find_first_node_of_type(model_instance, "Skeleton3D") as Skeleton3D
	var animation_player := _find_first_node_of_type(model_instance, "AnimationPlayer") as AnimationPlayer
	if skeleton == null or skeleton.get_bone_count() != REQUIRED_RIG_BONE_COUNT or animation_player == null:
		return false
	for animation_name: String in REQUIRED_RIG_ANIMATIONS:
		if not animation_player.has_animation(animation_name):
			return false
	return true


func _find_first_node_of_type(node: Node, type_name: String) -> Node:
	if node.is_class(type_name):
		return node
	for child: Node in node.get_children():
		var found := _find_first_node_of_type(child, type_name)
		if found != null:
			return found
	return null


func _configure_model_animations() -> void:
	if _animation_player == null:
		return
	for animation_name: String in ["idle", "walk", "curious"]:
		if _animation_player.has_animation(animation_name):
			_animation_player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
	for animation_name: String in ["praised", "scolded"]:
		if _animation_player.has_animation(animation_name):
			_animation_player.get_animation(animation_name).loop_mode = Animation.LOOP_NONE
	if not _animation_player.animation_finished.is_connected(_on_model_animation_finished):
		_animation_player.animation_finished.connect(_on_model_animation_finished)
	_response_animation_active = false
	_update_model_animation()


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
