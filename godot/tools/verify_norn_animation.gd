extends SceneTree

const NornActorScript = preload("res://scripts/norn_actor.gd")
const RIGGED_MODEL_PATH := "res://assets/generated/norns/albia-norn-rigged/model.glb"
const APPROVED_STATIC_MODEL_PATH := "res://assets/generated/norns/albia-norn/model.glb"
const REQUIRED_BONE_COUNT := 25
const REQUIRED_ANIMATIONS: Array[String] = ["idle", "walk", "curious", "praised", "scolded"]
const TEST_BODY_COLOR := Color(0.56, 0.31, 0.19)

var _failures: Array[String] = []
var _look_modifier_process_count := 0
var _look_modifier_skeleton: Skeleton3D
var _look_modifier_bone_index := -1
var _look_modifier_processed_head := Transform3D.IDENTITY


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var model_path := RIGGED_MODEL_PATH
	var user_args := OS.get_cmdline_user_args()
	if not user_args.is_empty():
		model_path = user_args[0]

	var model_resource := load(model_path) as PackedScene
	_expect(model_resource != null, "rigged Norn scene loads from %s" % model_path)
	if model_resource != null:
		var model := model_resource.instantiate()
		var skeleton := _find_first_node_of_type(model, "Skeleton3D")
		var animation_player := _find_first_node_of_type(model, "AnimationPlayer") as AnimationPlayer
		_expect(skeleton != null, "model contains a Skeleton3D skin rig")
		if skeleton is Skeleton3D:
			_expect(skeleton.get_bone_count() == REQUIRED_BONE_COUNT, "model contains exactly %d rig bones" % REQUIRED_BONE_COUNT)
		_expect(animation_player != null, "model contains an AnimationPlayer")
		if animation_player != null:
			for animation_name: String in REQUIRED_ANIMATIONS:
				_expect(animation_player.has_animation(animation_name), "animation '%s' is imported" % animation_name)
		model.free()
	test_missing_candidate_uses_static_fallback()
	await test_actor_animation_states()
	await test_foot_planting()
	await test_action_pose_and_gaze()

	if _failures.is_empty():
		print("NORN_RIG_CHECKS_OK model=%s clips=%s" % [model_path, ",".join(REQUIRED_ANIMATIONS)])
		quit(0)
		return

	for failure: String in _failures:
		push_error("NORN_RIG_CHECK_FAILED: " + failure)
	push_error("NORN_RIG_CHECKS_FAILED failures=%d" % _failures.size())
	quit(1)


func test_missing_candidate_uses_static_fallback() -> void:
	var actor = NornActorScript.new()
	_expect(actor.has_method("_instantiate_norn_model"), "actor exposes a model instantiator with a static fallback")
	if not actor.has_method("_instantiate_norn_model"):
		actor.free()
		return
	var fallback_instance := actor.call("_instantiate_norn_model", "res://assets/generated/norns/missing-candidate/model.glb") as Node3D
	_expect(fallback_instance != null, "a missing rigged candidate instantiates the approved static GLB")
	if fallback_instance != null:
		_expect(_find_first_node_of_type(fallback_instance, "MeshInstance3D") != null, "the static fallback still contains visible mesh geometry")
		fallback_instance.free()

	var invalid_root := Node3D.new()
	var invalid_scene := PackedScene.new()
	var pack_error := invalid_scene.pack(invalid_root)
	invalid_root.free()
	_expect(pack_error == OK, "malformed candidate fixture packs successfully")
	if pack_error == OK:
		var static_scene := load(APPROVED_STATIC_MODEL_PATH) as PackedScene
		var malformed_fallback := actor.call("_instantiate_model_scene_or_fallback", invalid_scene, static_scene) as Node3D
		_expect(malformed_fallback != null, "a loadable candidate without a usable rig instantiates the static fallback")
		if malformed_fallback != null:
			_expect(_find_first_node_of_type(malformed_fallback, "MeshInstance3D") != null, "malformed-candidate fallback contains visible static mesh geometry")
			malformed_fallback.free()
	actor.free()


func test_actor_animation_states() -> void:
	var actor = NornActorScript.new()
	actor.configure_identity("rig-check", "Rig Check", TEST_BODY_COLOR)
	root.add_child(actor)
	await process_frame
	var model := actor.get_node_or_null("LifeStageVisuals/MeshyNornModel") as Node3D
	var animation_player := _find_first_node_of_type(model, "AnimationPlayer") as AnimationPlayer if model != null else null
	_expect(animation_player != null, "runtime actor mounts the rigged Norn AnimationPlayer")
	if animation_player == null:
		actor.free()
		return

	_expect(animation_player.current_animation == "idle", "actor starts with the idle loop")
	actor.is_walking = true
	actor._process(1.0 / 60.0)
	_expect(animation_player.current_animation == "walk", "actor movement selects the walk loop")
	actor.is_walking = false
	actor.current_action = "observe_peer"
	actor._process(1.0 / 60.0)
	_expect(animation_player.current_animation == "curious", "peer observation selects the curiosity loop")

	_expect(actor.has_method("play_response_animation"), "actor exposes one-shot feedback animation playback")
	if actor.has_method("play_response_animation"):
		actor.call("play_response_animation", "praise")
		_expect(animation_player.current_animation == "praised", "praise plays the one-shot praised clip")
		var praise_animation := animation_player.get_animation("praised")
		animation_player.advance(praise_animation.length + 0.1)
		await process_frame
		_expect(animation_player.current_animation == "curious", "praise completion resumes the current curiosity loop")

		actor.call("play_response_animation", "scold")
		_expect(animation_player.current_animation == "scolded", "scold plays the one-shot scolded clip")
		var scold_animation := animation_player.get_animation("scolded")
		animation_player.advance(scold_animation.length + 0.1)
		await process_frame
		_expect(animation_player.current_animation == "curious", "scold completion resumes the current curiosity loop")
	actor.free()


func test_foot_planting() -> void:
	var actor = NornActorScript.new()
	actor.configure_identity("foot-check", "Foot Check", TEST_BODY_COLOR)
	root.add_child(actor)
	await process_frame
	var model := actor.get_node_or_null("LifeStageVisuals/MeshyNornModel") as Node3D
	var skeleton := _find_first_node_of_type(model, "Skeleton3D") as Skeleton3D if model != null else null
	_expect(skeleton != null, "foot-planting actor contains the rigged skeleton")
	if skeleton == null:
		actor.free()
		return

	var left_ik := skeleton.get_node_or_null("LeftFootIK") as TwoBoneIK3D
	var right_ik := skeleton.get_node_or_null("RightFootIK") as TwoBoneIK3D
	_expect(left_ik != null and right_ik != null, "both legs have runtime two-bone IK modifiers")
	var left_target := skeleton.get_node_or_null("LeftFootTarget") as Node3D
	var right_target := skeleton.get_node_or_null("RightFootTarget") as Node3D
	_expect(left_target != null and right_target != null, "each foot IK modifier has a target node")
	var left_pole := skeleton.get_node_or_null("LeftKneePole") as Node3D
	var right_pole := skeleton.get_node_or_null("RightKneePole") as Node3D
	_expect(left_pole != null and right_pole != null, "each foot IK modifier has a knee pole node")
	if left_ik != null and right_ik != null:
		_expect(left_ik.get_root_bone_name(0) == "leg_upper.L", "left IK starts at the left upper leg")
		_expect(left_ik.get_middle_bone_name(0) == "leg_lower.L", "left IK bends through the left lower leg")
		_expect(left_ik.get_end_bone_name(0) == "foot.L", "left IK ends at the left foot")
		_expect(right_ik.get_root_bone_name(0) == "leg_upper.R", "right IK starts at the right upper leg")
		_expect(right_ik.get_middle_bone_name(0) == "leg_lower.R", "right IK bends through the right lower leg")
		_expect(right_ik.get_end_bone_name(0) == "foot.R", "right IK ends at the right foot")
		_expect(left_ik.get_node_or_null(left_ik.get_target_node(0)) == left_target, "left IK target path resolves to its foot target")
		_expect(right_ik.get_node_or_null(right_ik.get_target_node(0)) == right_target, "right IK target path resolves to its foot target")
		_expect(left_ik.get_node_or_null(left_ik.get_pole_node(0)) == left_pole, "left IK pole path resolves to its knee pole")
		_expect(right_ik.get_node_or_null(right_ik.get_pole_node(0)) == right_pole, "right IK pole path resolves to its knee pole")

	_expect(actor.has_method("_update_foot_planting_targets"), "actor exposes the stance/swing target update")
	_expect(actor.has_method("_walk_speed_scale_for"), "actor derives walk playback from movement speed")
	if not actor.has_method("_update_foot_planting_targets") or not actor.has_method("_walk_speed_scale_for") or left_target == null:
		actor.free()
		return

	actor.is_walking = true
	actor.call("_update_foot_planting_targets", 0.0)
	var planted_left := left_target.global_position
	actor.global_position += Vector3(0.25, 0.0, 0.0)
	actor.call("_update_foot_planting_targets", 0.10)
	_expect(left_target.global_position.distance_to(planted_left) < 0.001, "left foot stays world-locked while its stance phase continues")
	actor.call("_update_foot_planting_targets", 0.48)
	_expect(left_target.global_position.distance_to(planted_left) < 0.001, "swing starts from the last stance contact without a target snap")
	actor.call("_update_foot_planting_targets", 0.70)
	_expect(left_target.global_position.y > planted_left.y + 0.05, "left foot lifts during the middle of its swing")
	actor.call("_update_foot_planting_targets", 0.99)
	var swing_landing := left_target.global_position
	actor.call("_update_foot_planting_targets", 1.0)
	_expect(left_target.global_position.distance_to(swing_landing) < 0.02, "swing landing joins the next stance without a target snap")

	var animation_player := _find_first_node_of_type(model, "AnimationPlayer") as AnimationPlayer
	var walk_length: float = animation_player.get_animation("walk").length
	var expected_slow_scale := walk_length * 1.4 / 1.2
	var expected_fast_scale := walk_length * 2.8 / 1.2
	_expect(is_equal_approx(actor.call("_walk_speed_scale_for", 1.4), expected_slow_scale), "walk playback scale matches 1.4 units per second")
	_expect(is_equal_approx(actor.call("_walk_speed_scale_for", 2.8), expected_fast_scale), "walk playback scale matches 2.8 units per second")
	actor.is_walking = false
	actor._process(0.2)
	_expect(is_equal_approx(animation_player.speed_scale, 1.0), "idle restores the normal animation playback speed")
	actor.call("play_response_animation", "praise")
	actor._process(0.2)
	_expect(is_equal_approx(animation_player.speed_scale, 1.0), "response clips retain their authored playback speed")
	if left_ik != null and right_ik != null:
		_expect(is_zero_approx(left_ik.influence) and is_zero_approx(right_ik.influence), "foot IK fades out while the actor is stationary")
	actor.free()


func test_action_pose_and_gaze() -> void:
	var actor = NornActorScript.new()
	actor.configure_identity("action-pose-check", "Action Pose Check", TEST_BODY_COLOR)
	root.add_child(actor)
	await process_frame
	var model := actor.get_node_or_null("LifeStageVisuals/MeshyNornModel") as Node3D
	var skeleton := _find_first_node_of_type(model, "Skeleton3D") as Skeleton3D if model != null else null
	_expect(skeleton != null, "action-pose actor keeps the rigged skeleton")
	if skeleton == null:
		actor.free()
		return

	var look_modifier := skeleton.get_node_or_null("HeadLookAt") as LookAtModifier3D
	var gaze_target := actor.get_node_or_null("GazeTarget") as Node3D
	if look_modifier != null:
		_look_modifier_process_count = 0
		_look_modifier_skeleton = skeleton
		_look_modifier_bone_index = skeleton.find_bone("head")
		look_modifier.modification_processed.connect(_on_look_modifier_processed)
	_expect(look_modifier != null, "rig creates a head LookAtModifier3D")
	_expect(gaze_target != null, "rig creates an actor-local gaze target")
	if look_modifier != null and gaze_target != null:
		_expect(look_modifier.bone_name == "head", "gaze modifier uses the existing head bone")
		_expect(look_modifier.use_angle_limitation, "head gaze has an angular safety limit")
		_expect(not look_modifier.symmetry_limitation, "head gaze has explicit positive and negative angular limits")
		_expect(look_modifier.primary_positive_limit_angle <= deg_to_rad(40.0) and look_modifier.primary_negative_limit_angle <= deg_to_rad(40.0), "head yaw stays within comfortable bounds")
		_expect(look_modifier.secondary_positive_limit_angle <= deg_to_rad(30.0) and look_modifier.secondary_negative_limit_angle <= deg_to_rad(30.0), "head pitch stays within comfortable bounds")
		_expect(look_modifier.get_node_or_null(look_modifier.target_node) == gaze_target, "head gaze target path resolves to the actor-local target")

	var object_target := Node3D.new()
	object_target.name = "PoseObjectTarget"
	root.add_child(object_target)
	object_target.global_position = Vector3(1.5, 0.0, -2.0)
	actor.call("set_action_target", object_target, "fruit", "Watching a fruit target", "fruit")
	for frame in range(90):
		await physics_frame
	if gaze_target != null:
		var object_gaze: Vector3 = actor.call("_bounded_gaze_position", object_target.global_position + Vector3.UP * 0.45)
		_expect(gaze_target.global_position.distance_to(object_gaze) < 0.02, "head gaze follows the selected object within its comfortable turn range")

	var peer := NornActorScript.new()
	peer.configure_identity("pose-peer-check", "Pose Peer", TEST_BODY_COLOR)
	root.add_child(peer)
	await process_frame
	actor.set_physics_process(false)
	actor.reset_position(Vector3.ZERO)
	actor.rotation = Vector3.ZERO
	peer.global_position = Vector3(2.2, 0.0, 0.0)
	actor.set_physics_process(true)
	await physics_frame
	actor.call("set_action_target", peer, "observe_peer", "Watching a peer", peer.actor_id)
	actor.call("set_action_target", null, "observe_peer", "Observing a nearby peer", peer.actor_id)
	for frame in range(90):
		await physics_frame
	if gaze_target != null:
		var peer_gaze: Vector3 = actor.call("_bounded_gaze_position", peer.global_position + Vector3.UP * 1.5)
		_expect(gaze_target.global_position.distance_to(peer_gaze) < 0.02, "peer remains the gaze target after observation movement stops")
	var processed_head := _look_modifier_processed_head
	var peer_gaze_direction := (gaze_target.global_position - processed_head.origin).normalized() if gaze_target != null else Vector3.ZERO
	var peer_gaze_alignment := processed_head.basis.z.normalized().dot(peer_gaze_direction)
	_expect(_look_modifier_process_count > 0, "head gaze modifier processes the rig pose")
	_expect(look_modifier != null and look_modifier.is_target_within_limitation(), "bounded peer target stays within the head-turn limits")
	_expect(peer_gaze_alignment > 0.9, "head forward axis turns toward the remembered peer gaze target (alignment=%.2f)" % peer_gaze_alignment)
	_expect(processed_head.basis.z.normalized().dot(-actor.global_transform.basis.z.normalized()) < 0.95, "peer gaze produces a visible head turn instead of staying fully forward")
	actor.call("set_action_target", null, "idle", "Looking around")
	for frame in range(90):
		await physics_frame
	if gaze_target != null:
		var neutral_gaze: Vector3 = actor.global_position - actor.global_transform.basis.z.normalized() * 2.0 + Vector3.UP * 1.7
		var bounded_neutral: Vector3 = actor.call("_bounded_gaze_position", neutral_gaze)
		_expect(gaze_target.global_position.distance_to(bounded_neutral) < 0.02, "idle gaze returns to a neutral forward point")

	var pose_modifier := skeleton.get_node_or_null("ActionPoseModifier")
	_expect(pose_modifier != null, "rig creates the additive action-pose modifier")
	_expect(actor.has_method("play_interaction_animation"), "actor exposes action-specific interaction poses")
	if pose_modifier != null and actor.has_method("play_interaction_animation"):
		var expected_actions := {"fruit": "eat", "forage": "forage", "drink": "drink", "spinner": "play"}
		for source_action: String in expected_actions:
			var started: bool = actor.call("play_interaction_animation", source_action, object_target.global_position)
			_expect(started, "%s interaction starts an action pose" % source_action)
			_expect(str(pose_modifier.call("get_active_action_id")) == str(expected_actions[source_action]), "%s maps to its expected gesture" % source_action)
			var head_index := skeleton.find_bone("head")
			var head_before := skeleton.get_bone_pose_rotation(head_index)
			pose_modifier.call("_process_modification_with_delta", 0.25)
			var head_during := skeleton.get_bone_pose_rotation(head_index)
			_expect(float(pose_modifier.get("influence")) > 0.0, "%s gesture becomes visible during its one-shot" % source_action)
			_expect(head_before.angle_to(head_during) > 0.001, "%s gesture changes the head pose" % source_action)
			pose_modifier.call("_process_modification_with_delta", 2.0)
			_expect(is_zero_approx(float(pose_modifier.get("influence"))), "%s gesture fades back to neutral" % source_action)

		actor.call("play_interaction_animation", "fruit", object_target.global_position)
		var runtime_head_before := skeleton.get_bone_pose_rotation(skeleton.find_bone("head"))
		for frame in range(8):
			await process_frame
		var runtime_head_during := skeleton.get_bone_pose_rotation(skeleton.find_bone("head"))
		_expect(str(pose_modifier.call("get_active_action_id")) == "eat", "the live Skeleton3D callback advances an active interaction pose")
		_expect(float(pose_modifier.get("influence")) > 0.0, "the live Skeleton3D callback advances the pose fade envelope")
		_expect(runtime_head_before.angle_to(runtime_head_during) > 0.001, "the live Skeleton3D callback visibly changes the head pose")

		actor.call("play_interaction_animation", "fruit", object_target.global_position)
		actor.call("play_response_animation", "praise")
		_expect(is_zero_approx(float(pose_modifier.get("influence"))), "Praise supersedes an active interaction gesture")
		_expect(str(pose_modifier.call("get_active_action_id")).is_empty(), "Praise clears the active interaction pose")
		var animation_player := _find_first_node_of_type(model, "AnimationPlayer") as AnimationPlayer
		_expect(animation_player != null and animation_player.current_animation == "praised", "Praise retains its authored one-shot clip")
		actor.call("play_interaction_animation", "spinner", object_target.global_position)
		actor.call("play_response_animation", "scold")
		_expect(is_zero_approx(float(pose_modifier.get("influence"))), "Scold supersedes an active interaction gesture")
		_expect(animation_player != null and animation_player.current_animation == "scolded", "Scold retains its authored one-shot clip")
	else:
		_expect(false, "interaction poses expose the tested modifier contract")

	actor.free()
	peer.free()
	object_target.free()


func _find_first_node_of_type(node: Node, type_name: String) -> Node:
	if node == null:
		return null
	if node.is_class(type_name):
		return node
	for child: Node in node.get_children():
		var found := _find_first_node_of_type(child, type_name)
		if found != null:
			return found
	return null


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _on_look_modifier_processed() -> void:
	_look_modifier_process_count += 1
	if _look_modifier_skeleton != null and _look_modifier_bone_index >= 0:
		_look_modifier_processed_head = _look_modifier_skeleton.get_global_transform_interpolated() * _look_modifier_skeleton.get_bone_global_pose(_look_modifier_bone_index)
