extends SceneTree

const HabitatScene = preload("res://scenes/main.tscn")
const HabitatWorldScript = preload("res://scripts/albia_world.gd")
const Biochemistry = preload("res://scripts/norn_biochemistry.gd")
const Cognition = preload("res://scripts/norn_cognition.gd")
const NornLifecycle = preload("res://scripts/norn_lifecycle.gd")
const SAVE_PATH := "user://albia_norn_save.json"

var _world: Node
var _previous_save_exists := false
var _previous_save_text := ""
var _save_backup_ready := false
var _captured_gaze_head_transform := Transform3D.IDENTITY


func _initialize() -> void:
	call_deferred("_record_preview")


func _record_preview() -> void:
	if not _backup_user_save():
		_fail("The existing local save could not be backed up safely.")
		return
	if not _verify_language_rules():
		return
	_world = HabitatScene.instantiate()
	root.add_child(_world)
	await process_frame
	if not _verify_starting_layout(_world):
		return
	var moss_actor: NornActor = _world.get("moss")
	var mallow_actor: NornActor = _world.get("norn")
	if moss_actor != null:
		moss_actor.set_physics_process(false)
	if not _world.has_method("toggle_recording") or not _world.has_method("is_recording"):
		_fail("The habitat recording controls are unavailable.")
		return
	if not _world.has_method("guide_to") or not _world.has_method("give_feedback"):
		_fail("The habitat interaction controls are unavailable.")
		return

	_world.call("toggle_recording")
	if not bool(_world.call("is_recording")):
		_fail("The recording did not start.")
		return
	if not _press_hud_button("Pause"):
		return
	if not await _run_face_closeup_demo():
		return
	if not await _run_teaching_walkthrough():
		return
	for frame in range(24):
		await process_frame
	if not _press_hud_button("Cancel teaching") or bool(_world.get("teaching_mode")):
		_fail("Teach mode did not close from the HUD.")
		return
	for frame in range(12):
		await process_frame
	if not _press_hud_button("Resume"):
		return
	if moss_actor != null:
		moss_actor.set_physics_process(false)
	if not await _run_foot_planting_walkthrough():
		return
	if not await _run_action_pose_gaze_walkthrough():
		return
	for frame in range(12):
		await process_frame
	if not _press_hud_button("Guide to fruit"):
		return
	var reached_fruit: bool = await _wait_for_status("ate honey fruit", 360)
	if not reached_fruit:
		_fail("Mallow did not reach the guided fruit during the recording: %s" % str(_world.get("last_status")))
		return
	if not _interaction_pose_is_active(mallow_actor, "eat"):
		_fail("The completed fruit action did not start its eating pose through the world action hook.")
		return
	for frame in range(3):
		await process_frame
	await create_timer(0.75).timeout
	if not str(_world.get("last_status")).contains("Mallow said “Apple”"):
		_fail("Mallow did not use the taught fruit word after reaching its confidence threshold.")
		return
	if not bool(_world.get("feedback_available")):
		_fail("Praise was not available after eating the fruit.")
		return
	if not _press_hud_button("Praise") or not str(_world.get("last_status")).contains("Mallow was praised"):
		_fail("The fruit praise response was not applied.")
		return
	if not str(_world.get("last_status")).contains("Mallow said “good”"):
		_fail("Mallow did not use the taught Praise word.")
		return
	var language_state: Dictionary = _world.get("language_state")
	var taught_words: Dictionary = language_state["words"]
	if not is_equal_approx(float(taught_words["apple"]["confidence"]), 0.90):
		_fail("Praise did not reinforce the fruit word confidence.")
		return
	for frame in range(24):
		await process_frame

	if not _press_hud_button("Guide to spinner"):
		return
	var reached_spinner: bool = await _wait_for_status("played with the spinner", 1800)
	if not reached_spinner:
		_fail("Mallow did not reach the guided spinner during the recording.")
		return
	if not _interaction_pose_is_active(mallow_actor, "play"):
		_fail("The completed spinner action did not start its play pose through the world action hook.")
		return
	for frame in range(3):
		await process_frame
	await create_timer(0.75).timeout
	if not str(_world.get("last_status")).contains("Mallow said “toy”"):
		_fail("Mallow did not use the taught spinner word after reaching its confidence threshold.")
		return
	if not bool(_world.get("feedback_available")):
		_fail("Scold was not available after playing with the spinner.")
		return
	if not _press_hud_button("Scold") or not str(_world.get("last_status")).contains("Mallow was scolded"):
		_fail("The spinner scold response was not applied.")
		return
	if not str(_world.get("last_status")).contains("Mallow said “bad”"):
		_fail("Mallow did not use the taught Scold word.")
		return
	language_state = _world.get("language_state")
	taught_words = language_state["words"]
	if not is_equal_approx(float(taught_words["toy"]["confidence"]), 0.62):
		_fail("Scold did not lower the spinner word confidence by 0.14.")
		return
	for frame in range(24):
		await process_frame
	if not await _show_resting_biochemistry():
		return

	if not _press_hud_button("Pause"):
		return
	var time_at_pause := float(_world.get("simulation_time"))
	for frame in range(30):
		await process_frame
	if not is_equal_approx(time_at_pause, float(_world.get("simulation_time"))):
		_fail("The simulation clock advanced while paused.")
		return
	if not _press_hud_button("Resume"):
		return
	for frame in range(20):
		await process_frame

	var cognition: Dictionary = _world.get("cognition_state")
	var fruit_association_before_save := float(cognition["actionAssociations"]["fruit"])
	language_state = _world.get("language_state")
	var expected_words: Dictionary = language_state["words"].duplicate(true)
	var moss_profile = _world.call("profile_for", "moss")
	var moss_cognition: Dictionary = moss_profile.get("cognition_state")
	var moss_biochemistry: Dictionary = moss_profile.get("biochemistry_state")
	var expected_moss_episodes: Array = moss_cognition["episodes"].duplicate(true)
	var expected_moss_compounds := Biochemistry.read_compounds(moss_biochemistry)
	var expected_moss_words: Dictionary = moss_profile.get("language_state")["words"].duplicate(true)
	var expected_moss_associations: Dictionary = moss_cognition["actionAssociations"].duplicate(true)
	if not _press_hud_button("Moss"):
		return
	if not await _teach_via_hud("fern", "spinner"):
		return
	expected_moss_episodes = moss_cognition["episodes"].duplicate(true)
	expected_moss_compounds = Biochemistry.read_compounds(moss_profile.get("biochemistry_state"))
	expected_moss_words = moss_profile.get("language_state")["words"].duplicate(true)
	var expected_moss_vocabulary_size := expected_moss_words.size()
	if not _press_hud_button("Save"):
		return
	cognition["actionAssociations"]["fruit"] = 0.99
	var words_before_reload: Dictionary = language_state["words"]
	words_before_reload["apple"]["confidence"] = 0.01
	words_before_reload.erase("toy")
	moss_cognition["actionAssociations"]["spinner"] = 0.99
	(moss_profile.get("language_state")["words"] as Dictionary).clear()
	var changed_moss_compounds: Dictionary = Biochemistry.read_compounds(moss_biochemistry)
	changed_moss_compounds["glucose"] = 1.0
	moss_biochemistry["compounds"] = changed_moss_compounds
	if not _press_hud_button("Load"):
		return
	var restored_cognition: Dictionary = _world.get("cognition_state")
	if not is_equal_approx(float(restored_cognition["actionAssociations"]["fruit"]), fruit_association_before_save):
		_fail("The recorded save/load interaction did not restore the fruit association.")
		return
	var restored_language: Dictionary = _world.get("language_state")
	var words_after_reload: Dictionary = restored_language["words"]
	if words_after_reload.size() != expected_words.size():
		_fail("The recorded save/load interaction did not restore the full vocabulary.")
		return
	for normalized_word: String in expected_words.keys():
		var expected_entry: Dictionary = expected_words[normalized_word]
		var restored_entry: Dictionary = words_after_reload[normalized_word]
		if str(restored_entry.get("word", "")) != str(expected_entry.get("word", "")) or str(restored_entry.get("targetId", "")) != str(expected_entry.get("targetId", "")) or not is_equal_approx(float(restored_entry.get("confidence", -1.0)), float(expected_entry.get("confidence", -2.0))):
			_fail("The recorded save/load interaction did not restore %s exactly." % normalized_word)
			return
	moss_profile = _world.call("profile_for", "moss")
	moss_cognition = moss_profile.get("cognition_state")
	var restored_moss_words: Dictionary = moss_profile.get("language_state")["words"]
	if _world.get("focused_norn_id") != "moss" or moss_profile.get("actor_id") != "moss":
		_fail("The recorded save/load interaction did not restore Moss focus.")
		return
	if moss_cognition["episodes"].size() != expected_moss_episodes.size() or not _number_maps_match(moss_cognition["actionAssociations"], expected_moss_associations, Cognition.get_action_ids()):
		_fail("The recorded save/load interaction did not restore Moss's independent cognition.")
		return
	if not _number_maps_match(Biochemistry.read_compounds(moss_profile.get("biochemistry_state")), expected_moss_compounds, Biochemistry.COMPOUND_IDS):
		_fail("The recorded save/load interaction did not restore Moss's compounds.")
		return
	if restored_moss_words.size() != expected_moss_vocabulary_size or restored_moss_words != expected_moss_words:
		_fail("The recorded save/load interaction did not restore Moss's vocabulary.")
		return
	if not await _run_action_utility_walkthrough():
		return
	if not await _run_social_observation_walkthrough():
		return
	if not await _run_family_lifespan_walkthrough():
		return
	for frame in range(30):
		await process_frame

	_world.call("toggle_recording")
	await process_frame
	if bool(_world.call("is_recording")):
		_fail("The recording did not stop.")
		return
	var frame_count := int(_world.get("recorded_frame_count"))
	var video_path := str(_world.get("last_recording_path"))
	if frame_count < 2:
		_fail("Expected at least two recorded frames; got %d." % frame_count)
		return
	if video_path.is_empty() or not FileAccess.file_exists(video_path):
		_fail("The recording file was not created: %s" % video_path)
		return
	var video := FileAccess.open(video_path, FileAccess.READ)
	if video == null or video.get_length() < 12:
		_fail("The recording file is empty or could not be opened.")
		return
	var video_size := video.get_length()
	video.seek(4)
	var riff_size := video.get_32()
	video.seek(48)
	var header_frame_count := video.get_32()
	video.seek(64)
	var video_width := video.get_32()
	var video_height := video.get_32()
	video.seek(0)
	var riff := video.get_buffer(4).get_string_from_ascii()
	video.seek(8)
	var avi := video.get_buffer(4).get_string_from_ascii()
	video.close()
	if riff != "RIFF" or avi != "AVI ":
		_fail("The recording does not have a RIFF AVI signature.")
		return
	if riff_size != video_size - 8 or header_frame_count != frame_count or video_width != 1280 or video_height != 720:
		_fail("The finalized AVI header does not match its frames or 1280x720 capture size.")
		return

	if not _verify_legacy_save_migration():
		return
	_restore_user_save()
	print("VIDEO_CAPTURE_OK frames=%d path=%s flow=teach-fruit-food-spinner-activity-praise-scold-rest-action-utility-social-observation-family-egg-hatch-stage-death-archive-save-load-migrations-action-poses-gaze" % [frame_count, video_path])
	quit()


func _run_face_closeup_demo() -> bool:
	var mallow = _world.call("profile_for", "mallow")
	var actor: NornActor = mallow.get("actor") if mallow != null else null
	var camera := _world.get("_camera") as Camera3D
	var model := actor.get_node_or_null("LifeStageVisuals/MeshyNornModel") as Node3D if actor != null else null
	if actor == null or camera == null or model == null or _count_model_meshes(model) == 0:
		_fail("The Norn close-up could not find Mallow's active model or the habitat camera.")
		return false
	var previous_rotation := actor.rotation
	var previous_physics_enabled := actor.is_physics_processing()
	var previous_camera_target: Vector3 = _world.get("_camera_target")
	var previous_camera_offset: Vector3 = _world.get("_camera_offset")
	var previous_camera_follow_enabled := bool(_world.get("_camera_follow_enabled"))
	actor.set_physics_process(false)
	actor.rotation.y = 0.0
	_world.set("_camera_target", actor.global_position + Vector3(0.0, 1.78, 0.0))
	_world.set("_camera_offset", Vector3(0.0, 0.08, -2.6))
	_world.set("_camera_follow_enabled", false)
	_world.call("_update_camera")
	var model_focus := actor.global_position + Vector3(0.0, 1.78, 0.0)
	var model_top := actor.global_position + Vector3(0.0, 2.25, 0.0)
	var projected_focus := camera.unproject_position(model_focus)
	var focus_visible := _closeup_point_is_visible(camera, model_focus) and _closeup_point_is_visible(camera, model_top)
	var capture_failure := ""
	var projected_quarter_focus := Vector2.ZERO
	if not focus_visible:
		capture_failure = "Mallow's active Norn model did not project into the clear frontal close-up view."
	else:
		for frame in range(24):
			await process_frame
		actor.rotation.y = 0.32
		_world.call("_update_camera")
		projected_quarter_focus = camera.unproject_position(model_focus)
		var quarter_model_visible := _closeup_point_is_visible(camera, model_focus) and _closeup_point_is_visible(camera, model_top)
		if not quarter_model_visible:
			capture_failure = "Mallow's active Norn model did not project into the clear three-quarter close-up view."
		else:
			for frame in range(24):
				await process_frame
	actor.rotation = previous_rotation
	actor.set_physics_process(previous_physics_enabled)
	_world.set("_camera_target", previous_camera_target)
	_world.set("_camera_offset", previous_camera_offset)
	_world.set("_camera_follow_enabled", previous_camera_follow_enabled)
	_world.call("_update_camera")
	if not actor.rotation.is_equal_approx(previous_rotation) or actor.is_physics_processing() != previous_physics_enabled or not camera.global_position.is_equal_approx(previous_camera_target + previous_camera_offset):
		_fail("The face close-up did not restore Mallow's rotation, physics state, and habitat camera.")
		return false
	if not capture_failure.is_empty():
		_fail(capture_failure)
		return false
	print("NORN_MODEL_CLOSEUP_CAPTURE_OK actor=%s frontalFocus=(%.1f,%.1f) threeQuarterFocus=(%.1f,%.1f) meshCount=%d frames=48" % [actor.display_name, projected_focus.x, projected_focus.y, projected_quarter_focus.x, projected_quarter_focus.y, _count_model_meshes(model)])
	return true


func _count_model_meshes(node: Node) -> int:
	var mesh_count := 1 if node is MeshInstance3D else 0
	for child: Node in node.get_children():
		mesh_count += _count_model_meshes(child)
	return mesh_count


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


func _closeup_point_is_visible(camera: Camera3D, point: Vector3) -> bool:
	if camera.is_position_behind(point):
		return false
	var projected := camera.unproject_position(point)
	return projected.x >= 400.0 and projected.x <= 880.0 and projected.y >= 100.0 and projected.y <= 620.0


func _run_foot_planting_walkthrough() -> bool:
	var profile = _world.call("profile_for", "mallow")
	var actor: NornActor = profile.get("actor") if profile != null else null
	var moss_profile = _world.call("profile_for", "moss")
	var moss_actor: NornActor = moss_profile.get("actor") if moss_profile != null else null
	var camera := _world.get("_camera") as Camera3D
	var model := actor.get_node_or_null("LifeStageVisuals/MeshyNornModel") as Node3D if actor != null else null
	var skeleton := _find_first_node_of_type(model, "Skeleton3D") as Skeleton3D if model != null else null
	if actor == null or camera == null or skeleton == null or skeleton.get_node_or_null("LeftFootIK") == null or skeleton.get_node_or_null("RightFootIK") == null:
		_fail("The foot-planting walkthrough could not find Mallow's runtime leg IK.")
		return false

	var previous_position := actor.global_position
	var previous_rotation := actor.rotation
	var previous_target: Node3D = actor.target
	var previous_action := actor.current_action
	var previous_reason := actor.action_reason
	var previous_target_id := actor.target_id
	var moss_visuals := moss_actor.get_node_or_null("LifeStageVisuals") as Node3D if moss_actor != null else null
	var previous_moss_visuals_visible := moss_visuals.visible if moss_visuals != null else true
	var previous_camera_target: Vector3 = _world.get("_camera_target")
	var previous_camera_offset: Vector3 = _world.get("_camera_offset")
	var previous_camera_follow_enabled := bool(_world.get("_camera_follow_enabled"))
	var previous_status := str(_world.get("last_status"))
	var had_straight_walk := false
	var had_turn := false
	var had_response := false
	var resumed_walking := false
	var success := true

	actor.reset_position(previous_position)
	actor.rotation = previous_rotation
	if moss_visuals != null:
		moss_visuals.visible = false
	_world.set("_camera_follow_enabled", false)
	_world.set("last_status", "Foot planting review: straight walk, turn, response, and resumed walk.")
	_world.call("_refresh_ui")
	var forward := -actor.global_transform.basis.z.normalized()
	var side := Vector3.ZERO
	var first_destination := actor.global_position + forward * 5.5
	if await _record_foot_plant_segment(actor, first_destination, 240):
		had_straight_walk = true
	else:
		_fail("Mallow did not complete the straight foot-planting walk segment.")
		success = false

	if success:
		side = actor.global_transform.basis.x.normalized()
		var second_destination := actor.global_position + side * 5.5
		if await _record_foot_plant_segment(actor, second_destination, 240):
			had_turn = true
		else:
			_fail("Mallow did not complete the turning foot-planting walk segment.")
			success = false

	if success:
		var animation_player := _find_first_node_of_type(model, "AnimationPlayer") as AnimationPlayer
		actor.play_response_animation("praise")
		had_response = animation_player != null and animation_player.current_animation == "praised"
		var response_length: float = animation_player.get_animation("praised").length if animation_player != null else 1.0
		for frame in range(ceili(response_length * 60.0) + 6):
			_update_foot_planting_camera(actor)
			await process_frame
		var resumed_destination := actor.global_position - side * 3.0 + forward * 2.0
		if await _record_foot_plant_segment(actor, resumed_destination, 240):
			resumed_walking = true
		else:
			_fail("Mallow did not resume walking after the response animation.")
			success = false

	actor.reset_position(previous_position)
	actor.rotation = previous_rotation
	if moss_visuals != null:
		moss_visuals.visible = previous_moss_visuals_visible
	if previous_target != null and is_instance_valid(previous_target):
		actor.set_action_target(previous_target, previous_action, previous_reason, previous_target_id)
	else:
		actor.current_action = previous_action
		actor.action_reason = previous_reason
	_world.set("_camera_target", previous_camera_target)
	_world.set("_camera_offset", previous_camera_offset)
	_world.set("_camera_follow_enabled", previous_camera_follow_enabled)
	_world.set("last_status", previous_status)
	_world.call("_update_camera")
	_world.call("_refresh_ui")
	if not had_straight_walk or not had_turn or not had_response or not resumed_walking:
		if success:
			_fail("The foot-planting capture did not cover every gait segment.")
		return false
	print("FOOT_PLANTING_CAPTURE_OK straight=true turn=true stopped=true response=true resumed=true ik=%d" % [2])
	return success


func _run_action_pose_gaze_walkthrough() -> bool:
	var profile = _world.call("profile_for", "mallow")
	var actor: NornActor = profile.get("actor") if profile != null else null
	var peer_profile = _world.call("profile_for", "moss")
	var peer: NornActor = peer_profile.get("actor") if peer_profile != null else null
	var camera := _world.get("_camera") as Camera3D
	var model := actor.get_node_or_null("LifeStageVisuals/MeshyNornModel") as Node3D if actor != null else null
	var skeleton := _find_first_node_of_type(model, "Skeleton3D") as Skeleton3D if model != null else null
	var pose_modifier := skeleton.get_node_or_null("ActionPoseModifier") as SkeletonModifier3D if skeleton != null else null
	var gaze_modifier := skeleton.get_node_or_null("HeadLookAt") as LookAtModifier3D if skeleton != null else null
	var gaze_target := actor.get_node_or_null("GazeTarget") as Node3D if actor != null else null
	if actor == null or peer == null or camera == null or skeleton == null or pose_modifier == null or gaze_modifier == null or gaze_target == null:
		_fail("The action-pose and gaze recording could not find both actors and their runtime skeleton modifiers.")
		return false
	var capture_gaze_pose := Callable(self, "_capture_gaze_head_pose").bind(skeleton)
	gaze_modifier.modification_processed.connect(capture_gaze_pose)

	var previous_actor_position := actor.global_position
	var previous_actor_rotation := actor.rotation
	var previous_actor_target: Node3D = actor.target
	var previous_actor_target_id := actor.target_id
	var previous_actor_action := actor.current_action
	var previous_actor_reason := actor.action_reason
	var previous_actor_physics := actor.is_physics_processing()
	var previous_peer_position := peer.global_position
	var previous_peer_rotation := peer.rotation
	var previous_peer_target: Node3D = peer.target
	var previous_peer_target_id := peer.target_id
	var previous_peer_action := peer.current_action
	var previous_peer_reason := peer.action_reason
	var previous_peer_physics := peer.is_physics_processing()
	var previous_paused := bool(_world.get("paused"))
	var previous_camera_target: Vector3 = _world.get("_camera_target")
	var previous_camera_offset: Vector3 = _world.get("_camera_offset")
	var previous_camera_follow := bool(_world.get("_camera_follow_enabled"))
	var previous_status := str(_world.get("last_status"))
	var preview_origin := Vector3(6.0, 0.0, 0.0)
	var capture_frame_start := int(_world.get("recorded_frame_count"))
	var failure := ""
	var gaze_alignment := -1.0

	_world.set("paused", true)
	actor.set_physics_process(true)
	peer.set_physics_process(false)
	actor.reset_position(preview_origin)
	actor.rotation.y = 0.0
	peer.reset_position(preview_origin + Vector3(1.55, 0.0, 0.0))
	peer.rotation.y = 0.15
	_world.set("_camera_target", preview_origin + Vector3(0.0, 1.32, 0.0))
	_world.set("_camera_offset", Vector3(0.0, 0.0, -5.2))
	_world.set("_camera_follow_enabled", false)
	camera.make_current()
	_world.call("_update_camera")
	if camera.global_position.distance_to(preview_origin + Vector3(0.0, 1.32, -5.2)) > 0.001 or not _closeup_point_is_visible(camera, actor.global_position + Vector3(0.0, 1.78, 0.0)):
		failure = "The action-pose camera did not frame Mallow's upper body."
	var action_pairs := [["fruit", "eat"], ["forage", "forage"], ["drink", "drink"], ["spinner", "play"]]
	for pair: Array in action_pairs:
		if not failure.is_empty():
			break
		var action_id := str(pair[0])
		var expected_pose := str(pair[1])
		var focus_position := actor.global_position + Vector3(0.0, 0.30, -0.72)
		_world.set("last_status", "Action-pose preview: Mallow %s." % expected_pose)
		_world.call("_refresh_ui")
		if not actor.play_interaction_animation(action_id, focus_position):
			failure = "The %s preview gesture could not be started." % action_id
			break
		for frame in range(12):
			await process_frame
		if str(pose_modifier.call("get_active_action_id")) != expected_pose or float(pose_modifier.get("influence")) <= 0.0:
			failure = "The live %s pose did not produce a visible runtime gesture." % action_id
			break
		if action_id == "fruit":
			await RenderingServer.frame_post_draw
			var preview_image := root.get_texture().get_image()
			var preview_path := OS.get_environment("TEMP").path_join("albia-action-pose-gaze-preview.png")
			var preview_error := preview_image.save_png(preview_path)
			if preview_error != OK:
				failure = "Could not save the temporary rendered action-pose inspection frame."
				break
		for frame in range(22):
			await process_frame

	if failure.is_empty():
		for frame in range(60):
			await physics_frame
			await process_frame
		var head_forward_before_gaze := _captured_gaze_head_transform.basis.z.normalized()
		actor.set_action_target(peer, "observe_peer", "Looking toward Moss", peer.actor_id)
		actor.set_action_target(null, "observe_peer", "Watching a nearby peer", peer.actor_id)
		var expected_gaze: Vector3 = actor.call("_bounded_gaze_position", peer.global_position + Vector3.UP * 1.5)
		_world.set("_camera_target", preview_origin + Vector3(0.78, 1.48, 0.0))
		_world.set("_camera_offset", Vector3(0.0, 0.18, -5.4))
		_world.set("last_status", "Gaze preview: Mallow turns to look at Moss.")
		_world.call("_refresh_ui")
		_world.call("_update_camera")
		for frame in range(90):
			await physics_frame
			await process_frame
		var head_global_after := _captured_gaze_head_transform
		var target_direction := (gaze_target.global_position - head_global_after.origin).normalized()
		var head_forward_after_gaze := head_global_after.basis.z.normalized()
		gaze_alignment = head_forward_after_gaze.dot(target_direction)
		if gaze_target.global_position.distance_to(expected_gaze) > 0.02:
			failure = "The live peer-gaze target did not stay within its bounded range."
		elif head_forward_before_gaze.angle_to(head_forward_after_gaze) < deg_to_rad(10.0):
			failure = "The live head-look modifier did not visibly turn toward Moss."
		elif gaze_alignment < 0.9:
			failure = "The live Norn head forward axis did not turn toward the peer target (alignment=%.2f)." % gaze_alignment
		elif not _closeup_point_is_visible(camera, actor.global_position + Vector3(0.0, 1.4, 0.0)) or not _closeup_point_is_visible(camera, peer.global_position + Vector3(0.0, 1.4, 0.0)):
			failure = "The peer-gaze recording camera did not frame both Norns."
		else:
			await RenderingServer.frame_post_draw
			var peer_image := root.get_texture().get_image()
			var peer_image_path := OS.get_environment("TEMP").path_join("albia-peer-gaze-preview.png")
			if peer_image.save_png(peer_image_path) != OK:
				failure = "Could not save the temporary rendered peer-gaze inspection frame."
	if gaze_modifier.modification_processed.is_connected(capture_gaze_pose):
		gaze_modifier.modification_processed.disconnect(capture_gaze_pose)

	actor.reset_position(previous_actor_position)
	actor.rotation = previous_actor_rotation
	if previous_actor_target != null and is_instance_valid(previous_actor_target):
		actor.set_action_target(previous_actor_target, previous_actor_action, previous_actor_reason, previous_actor_target_id)
	else:
		actor.set_action_target(null, previous_actor_action, previous_actor_reason, previous_actor_target_id)
	peer.reset_position(previous_peer_position)
	peer.rotation = previous_peer_rotation
	if previous_peer_target != null and is_instance_valid(previous_peer_target):
		peer.set_action_target(previous_peer_target, previous_peer_action, previous_peer_reason, previous_peer_target_id)
	else:
		peer.set_action_target(null, previous_peer_action, previous_peer_reason, previous_peer_target_id)
	actor.set_physics_process(previous_actor_physics)
	peer.set_physics_process(previous_peer_physics)
	_world.set("paused", previous_paused)
	_world.set("_camera_target", previous_camera_target)
	_world.set("_camera_offset", previous_camera_offset)
	_world.set("_camera_follow_enabled", previous_camera_follow)
	_world.set("last_status", previous_status)
	_world.call("_update_camera")
	_world.call("_refresh_ui")
	if not failure.is_empty():
		_fail(failure)
		return false
	print("ACTION_POSES_AND_GAZE_CAPTURE_OK actions=fruit,eat;forage,forage;drink,drink;spinner,play peer_gaze=true alignment=%.2f recordingFrames=%d-%d" % [gaze_alignment, capture_frame_start, int(_world.get("recorded_frame_count"))])
	return true


func _interaction_pose_is_active(actor: NornActor, expected_pose: String) -> bool:
	if actor == null:
		return false
	var model := actor.get_node_or_null("LifeStageVisuals/MeshyNornModel") as Node3D
	var skeleton := _find_first_node_of_type(model, "Skeleton3D") as Skeleton3D if model != null else null
	var modifier := skeleton.get_node_or_null("ActionPoseModifier") as SkeletonModifier3D if skeleton != null else null
	return modifier != null and str(modifier.call("get_active_action_id")) == expected_pose


func _capture_gaze_head_pose(skeleton: Skeleton3D) -> void:
	var head_index := skeleton.find_bone("head")
	if head_index >= 0:
		_captured_gaze_head_transform = skeleton.get_global_transform_interpolated() * skeleton.get_bone_global_pose(head_index)


func _record_foot_plant_segment(actor: NornActor, destination: Vector3, max_frames: int) -> bool:
	var waypoint := Node3D.new()
	waypoint.name = "FootPlantingWaypoint"
	_world.add_child(waypoint)
	waypoint.global_position = destination
	actor.set_action_target(waypoint, "foot_planting_preview", "Walking through the foot-planting preview", "foot_planting_preview")
	var reached := false
	for frame in range(max_frames):
		_update_foot_planting_camera(actor)
		await physics_frame
		await process_frame
		if actor.target == null and not actor.is_walking:
			reached = true
			break
	waypoint.queue_free()
	return reached


func _update_foot_planting_camera(actor: NornActor) -> void:
	_world.set("_camera_target", actor.global_position + Vector3.UP * 0.9)
	_world.set("_camera_offset", Vector3(6.0, 2.2, 0.0))
	_world.call("_update_camera")


func _run_family_lifespan_walkthrough() -> bool:
	if not _press_hud_button("Mallow"):
		return false
	var mallow_profile = _world.call("profile_for", "mallow")
	var moss_profile = _world.call("profile_for", "moss")
	if mallow_profile == null or moss_profile == null:
		_fail("The family walkthrough could not find the two living founders.")
		return false
	var mallow_actor: NornActor = mallow_profile.get("actor")
	var moss_actor: NornActor = moss_profile.get("actor")
	mallow_actor.set_physics_process(false)
	moss_actor.set_physics_process(false)
	mallow_actor.reset_position(Vector3(1.75, 0.0, 1.8))
	moss_actor.reset_position(Vector3(5.1, 0.0, 1.8))
	var selector := _world.find_child("SecondParentSelector", true, false) as OptionButton
	if selector == null or selector.item_count != 1 or selector.selected < 0 or str(selector.get_item_metadata(selector.selected)) != "moss":
		_fail("The family HUD did not select Moss as Mallow's other living adult parent.")
		return false
	var start_simulation_time := float(_world.get("simulation_time"))
	if not _press_hud_button("Start family egg"):
		return false
	if _world.get("eggs").size() != 1:
		_fail("The family HUD did not create the founders' egg.")
		return false
	var egg_record: Dictionary = _world.get("eggs")[0]
	if egg_record.get("parentIds", []) != ["mallow", "moss"] or float(egg_record.get("remainingSeconds", -1.0)) != 45.0:
		_fail("The new family egg did not record both founders and the full incubation timer.")
		return false
	var egg_progress_label := _world.find_child("EggProgressLabel", true, false) as Label
	if egg_progress_label == null or not egg_progress_label.text.contains(str(egg_record.get("displayName", ""))) or not egg_progress_label.text.contains("45.0 s"):
		_fail("The family HUD did not show the named egg and its starting incubation progress.")
		return false
	for frame in range(24):
		await process_frame
	if not egg_progress_label.text.contains("%") or egg_progress_label.text.contains("0%") or float((_world.get("eggs") as Array)[0].get("remainingSeconds", 45.0)) >= 45.0:
		_fail("The recorded family HUD did not show incubation progress advancing.")
		return false
	var speed := float(_world.get("simulation_speed"))
	for attempt in range(3):
		if is_equal_approx(speed, 2.0):
			break
		if not _press_hud_button("Speed %.1f×" % speed):
			return false
		speed = float(_world.get("simulation_speed"))
	if not is_equal_approx(speed, 2.0):
		_fail("The family walkthrough could not set 2× simulation speed.")
		return false
	var hatch_deadline := Time.get_ticks_msec() + 180000
	var child = null
	while Time.get_ticks_msec() < hatch_deadline:
		await process_frame
		child = _world.call("profile_for", "norn-1")
		if child != null:
			break
	var incubation_elapsed := float(_world.get("simulation_time")) - start_simulation_time
	if child == null or incubation_elapsed < 44.999 or not (_world.get("eggs") as Array).is_empty():
		_fail("The egg did not complete its full 45 in-game-second incubation at 2× speed (elapsed %.3f)." % incubation_elapsed)
		return false
	if child.get("parent_ids") != ["mallow", "moss"] or child.get("generation") != 1:
		_fail("The hatched child lost its founder lineage or generation.")
		return false
	var child_actor: NornActor = child.get("actor")
	_settled_needs(child)
	_world.call("_run_decision", child)
	var follow_choice_deadline := Time.get_ticks_msec() + 5000
	var following_parent = _world.call("_nearest_living_parent", child)
	while Time.get_ticks_msec() < follow_choice_deadline and (following_parent == null or child_actor.current_action != "observe_peer" or child_actor.target != following_parent.get("actor") or child_actor.target_id != str(following_parent.get("actor_id"))):
		await physics_frame
		await process_frame
		following_parent = _world.call("_nearest_living_parent", child)
	if str(child.get("life_stage")) != "baby" or following_parent == null or child_actor.current_action != "observe_peer" or child_actor.target != following_parent.get("actor") or child_actor.target_id != str(following_parent.get("actor_id")):
		_fail("The hatched baby did not begin following a living parent.")
		return false
	var follow_deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < follow_deadline and (child_actor.target != null or child_actor.is_walking or child_actor.global_position.distance_to(following_parent.get("actor").global_position) > 2.2):
		await physics_frame
		await process_frame
	var baby_parent_distance := child_actor.global_position.distance_to(following_parent.get("actor").global_position)
	if child_actor.target != null or child_actor.is_walking or baby_parent_distance > 2.2:
		_fail("The baby did not visibly settle beside its living parent at the peer stop distance.")
		return false
	if not _press_hud_button(str(child.get("display_name"))):
		return false
	for frame in range(24):
		await process_frame
	var action_label: Label = _world.get("_ui").get("_action_label") as Label
	if action_label == null or not action_label.text.contains("Following their parent, %s" % following_parent.get("display_name")):
		_fail("The focused HUD did not show the baby's parent-following behavior.")
		return false
	print("BABY_FOLLOW_CAPTURE_OK child=%s parent=%s settledDistance=%.2f" % [child.get("display_name"), following_parent.get("display_name"), baby_parent_distance])
	if not _press_hud_button("Mallow"):
		return false
	var child_seed := int(child.get("cognition_state").get("seed", -1))
	var child_life: Dictionary = NornLifecycle.create_state(child_seed, 59.95)
	if child_life.is_empty():
		_fail("Could not place the hatched child just before its saved child-stage threshold.")
		return false
	child.set("life_state", child_life)
	_world.call("_refresh_ui")
	var stage_deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < stage_deadline and str(child.get("life_stage")) != "child":
		await process_frame
	var child_stage_label := child.get("actor").find_child("LifeStageLabel", true, false) as Label3D
	var child_name_label := child.get("actor").find_child("NameLabel", true, false) as Label3D
	if str(child.get("life_stage")) != "child" or child_stage_label == null or child_stage_label.text != "Child" or child_name_label == null or child_name_label.text != str(child.get("display_name")):
		_fail("The ordinary world tick did not advance the child through the 60-second stage boundary.")
		return false
	if not _press_hud_button(str(child.get("display_name"))):
		return false
	for frame in range(36):
		await process_frame
	var focus_age_label := _world.find_child("FocusAgeStageLabel", true, false) as Label
	var child_age := float(child.get("life_state").get("ageSeconds", -1.0))
	var child_age_text := "Age %.1f s" % child_age
	if focus_age_label == null or not focus_age_label.text.contains(child_age_text) or not focus_age_label.text.contains("Child") or child_age < 60.0 or child_age >= 62.0:
		_fail("The focused HUD did not show the hatched child's age and new life stage.")
		return false
	if not await _run_child_observation_demo(child):
		return false
	if not await _run_adolescent_independence_demo(child):
		return false
	var mallow = _world.call("profile_for", "mallow")
	if mallow == null or not _press_hud_button("Mallow"):
		return false
	var saved_lifespan := float(mallow.get("life_state").get("lifespanSeconds", -1.0))
	var death_fixture: Dictionary = NornLifecycle.create_state(int(mallow.get("cognition_state").get("seed", -1)), saved_lifespan - 0.25)
	if death_fixture.is_empty():
		_fail("Could not place Mallow just before its saved old-age limit.")
		return false
	mallow.set("life_state", death_fixture)
	_world.call("_refresh_ui")
	var death_deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < death_deadline and bool(mallow.get("life_state").get("alive", true)):
		await process_frame
	if bool(mallow.get("life_state").get("alive", true)) or mallow.get("actor") != null:
		_fail("The normal world tick did not remove Mallow at the saved old-age lifespan.")
		return false
	if str(_world.get("focused_norn_id")) != "moss":
		_fail("Focus did not move from Mallow to the next living founder after death.")
		return false
	var archive_panel := _world.find_child("FamilyArchive", true, false) as PanelContainer
	var archive_label := _world.find_child("FamilyArchiveText", true, false) as Label
	var death_notice := str(_world.get("last_status"))
	var hatch_parent_ids: Array = child.get("parent_ids")
	if archive_panel == null or not archive_panel.visible or archive_label == null or not archive_label.text.contains("Mallow") or not death_notice.contains("Mallow reached old age and died") or hatch_parent_ids != ["mallow", "moss"]:
		_fail("The deceased archive did not retain Mallow alongside the child's family lineage.")
		return false
	var saved_file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var saved_value: Variant = JSON.parse_string(saved_file.get_as_text()) if saved_file != null else null
	if saved_file != null:
		saved_file.close()
	var saved_record: Dictionary = saved_value if saved_value is Dictionary else {}
	var saved_norns: Dictionary = saved_record.get("norns", {})
	var saved_mallow: Dictionary = saved_norns.get("mallow", {})
	var saved_child: Dictionary = saved_norns.get("norn-1", {})
	var saved_death: Dictionary = saved_mallow.get("lifeState", {}).get("death", {})
	if int(saved_record.get("version", -1)) != HabitatWorldScript.SAVE_VERSION:
		_fail("The rendered family sequence did not save version-8 lineage state.")
		return false
	if saved_death.get("cause", "") != "old-age" or saved_child.get("parentIds", []) != ["mallow", "moss"] or str(saved_record.get("focusedNornId", "")) != "moss":
		_fail("The saved family did not retain Mallow's death, the child's parents, and focus fallback.")
		return false
	_world.set("paused", true)
	_world.call("_refresh_ui")
	var hud_scroll := _world.find_child("HUDScrollContainer", true, false) as ScrollContainer
	var status_label := _world.find_child("StatusLabel", true, false) as Label
	if hud_scroll == null or status_label == null:
		_fail("The rendered HUD could not bring the old-age notification into view.")
		return false
	hud_scroll.scroll_vertical = int(hud_scroll.get_v_scroll_bar().max_value)
	for frame in range(45):
		await process_frame
	var status_rect := status_label.get_global_rect()
	var death_notice_visible := status_label.text.contains(death_notice) and status_label.is_visible_in_tree() and status_rect.position.y >= 0.0 and status_rect.end.y <= 720.0
	if not death_notice_visible:
		_fail("The old-age notification was not visible inside the rendered HUD after scrolling to the status line.")
		return false
	print("FAMILY_LIFESPAN_CAPTURE_OK incubation=%.3fs childAge=%.1fs stage=%s death=%s noticeVisible=%s focus=%s archive=%s childParents=%s" % [incubation_elapsed, child_age, child.get("life_stage"), str(saved_death.get("cause", "")), death_notice_visible, str(_world.get("focused_norn_id")), archive_label.text, str(hatch_parent_ids)])
	return true


func _run_adolescent_independence_demo(adolescent: Object) -> bool:
	var mallow = _world.call("profile_for", "mallow")
	var moss = _world.call("profile_for", "moss")
	if adolescent == null or mallow == null or moss == null:
		_fail("The adolescent walkthrough could not find Sprout and both founders.")
		return false
	if not _press_hud_button("Mallow"):
		return false
	var second_parent_selector := _world.find_child("SecondParentSelector", true, false) as OptionButton
	if second_parent_selector == null or second_parent_selector.selected < 0 or str(second_parent_selector.get_item_metadata(second_parent_selector.selected)) != "moss":
		_fail("The second family egg did not select Moss as Mallow's other parent.")
		return false
	if int(_world.call("population_count")) != 3 or not _press_hud_button("Start family egg"):
		_fail("The family controls could not start a second egg for the three living Norns.")
		return false
	if (_world.get("eggs") as Array).size() != 1 or int(_world.call("population_count")) != 4:
		_fail("The second family egg exceeded the four-slot living-plus-egg limit.")
		return false
	var sibling = null
	var hatch_deadline := Time.get_ticks_msec() + 90000
	while Time.get_ticks_msec() < hatch_deadline:
		await process_frame
		sibling = _world.call("profile_for", "norn-2")
		if sibling != null:
			break
	if sibling == null or not (_world.get("eggs") as Array).is_empty() or int(_world.call("population_count")) != 4:
		_fail("The second 45-second egg did not hatch its sibling within the four-Norn population cap.")
		return false
	if sibling.get("parent_ids") != ["mallow", "moss"]:
		_fail("The hatched sibling did not retain Mallow and Moss as its parents.")
		return false
	var adolescent_seed := int(adolescent.get("cognition_state").get("seed", -1))
	var adolescent_life: Dictionary = NornLifecycle.create_state(adolescent_seed, 179.95)
	if adolescent_life.is_empty():
		_fail("Could not place Sprout just before the 180-second adolescent stage boundary.")
		return false
	adolescent.set("life_state", adolescent_life)
	_world.call("_refresh_ui")
	var stage_deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < stage_deadline and str(adolescent.get("life_stage")) != "adolescent":
		await physics_frame
		await process_frame
	var adolescent_actor: NornActor = adolescent.get("actor")
	var sibling_actor: NornActor = sibling.get("actor")
	var mallow_actor: NornActor = mallow.get("actor")
	var moss_actor: NornActor = moss.get("actor")
	var adolescent_stage_label := adolescent_actor.find_child("LifeStageLabel", true, false) as Label3D
	if str(adolescent.get("life_stage")) != "adolescent" or adolescent_stage_label == null or adolescent_stage_label.text != "Adolescent":
		_fail("The normal lifecycle tick did not advance Sprout into the adolescent stage.")
		return false
	adolescent_actor.set_physics_process(false)
	sibling_actor.set_physics_process(false)
	mallow_actor.set_physics_process(false)
	moss_actor.set_physics_process(false)
	adolescent_actor.reset_position(Vector3.ZERO)
	mallow_actor.reset_position(Vector3(0.0, 0.0, 3.0))
	sibling_actor.reset_position(Vector3(4.2, 0.0, 0.0))
	moss_actor.reset_position(Vector3(-8.0, 0.0, -8.0))
	_settled_needs(adolescent)
	var adolescent_cognition: Dictionary = adolescent.get("cognition_state")
	var adolescent_traits: Dictionary = adolescent_cognition.get("traits", {})
	adolescent_traits["sociability"] = 1.0
	adolescent_cognition["traits"] = adolescent_traits
	adolescent.set("cognition_state", adolescent_cognition)
	var visibility_deadline := Time.get_ticks_msec() + 2000
	var sensed_peers: Array[Dictionary] = _world.call("_sense_peers", adolescent)
	var parent_is_visible := _contains_sensed_peer(sensed_peers, str(mallow.get("actor_id")))
	var sibling_is_visible := _contains_sensed_peer(sensed_peers, str(sibling.get("actor_id")))
	while (not sibling_is_visible or not parent_is_visible) and Time.get_ticks_msec() < visibility_deadline:
		await physics_frame
		sensed_peers = _world.call("_sense_peers", adolescent)
		parent_is_visible = _contains_sensed_peer(sensed_peers, str(mallow.get("actor_id")))
		sibling_is_visible = _contains_sensed_peer(sensed_peers, str(sibling.get("actor_id")))
	_world.call("_run_decision", adolescent)
	var parent_distance := adolescent_actor.global_position.distance_to(mallow_actor.global_position)
	var peer_distance := adolescent_actor.global_position.distance_to(sibling_actor.global_position)
	var neutral_decision: Dictionary = adolescent.get("current_decision")
	var neutral_selection: Dictionary = neutral_decision.get("peerSelection", {})
	if not parent_is_visible or not sibling_is_visible or adolescent_actor.current_action != "observe_peer" or adolescent_actor.target != sibling_actor or adolescent_actor.target_id != str(sibling.get("actor_id")) or parent_distance >= peer_distance or str(neutral_selection.get("peerId", "")) != str(sibling.get("actor_id")) or not adolescent_actor.action_reason.contains(str(sibling.get("display_name"))):
		_fail("The adolescent did not choose its visible sibling beyond its closer parent.")
		return false
	if not _press_hud_button(str(adolescent.get("display_name"))):
		return false
	for frame in range(24):
		await process_frame
	var action_label: Label = _world.get("_ui").get("_action_label") as Label
	if action_label == null or not action_label.text.contains("Observing peer %s beyond the family" % sibling.get("display_name")):
		_fail("The focused adolescent HUD did not show its non-parent peer choice.")
		return false
	print("ADOLESCENT_INDEPENDENCE_CAPTURE_OK adolescent=%s peer=%s parentDistance=%.2f peerDistance=%.2f reasonVisible=true" % [adolescent.get("display_name"), sibling.get("display_name"), parent_distance, peer_distance])
	for _memory_index in range(6):
		var memory_result: Dictionary = Cognition.record_outcome(adolescent_cognition, {
			"eventType": "observe",
			"actorId": str(mallow.get("actor_id")),
			"actionId": "observe_peer",
			"time": float(_world.get("simulation_time")),
			"peerCount": 1,
			"sociability": 1.0,
			"salience": 0.55,
			"text": "Positive peer observation with Mallow"
		})
		if memory_result.is_empty():
			_fail("Could not create a recent positive peer-memory episode for Mallow.")
			return false
	adolescent.set("cognition_state", adolescent_cognition)
	_world.call("_run_decision", adolescent)
	var remembered_decision: Dictionary = adolescent.get("current_decision")
	var remembered_selection: Dictionary = remembered_decision.get("peerSelection", {})
	var remembered_score := 0.0
	for score_value: Variant in remembered_selection.get("scores", []):
		if score_value is Dictionary and str(score_value.get("peerId", "")) == str(mallow.get("actor_id")):
			remembered_score = float(score_value.get("memory", 0.0))
			break
	if adolescent_actor.current_action != "observe_peer" or adolescent_actor.target != mallow_actor or adolescent_actor.target_id != str(mallow.get("actor_id")) or str(remembered_selection.get("peerId", "")) != str(mallow.get("actor_id")) or str(remembered_selection.get("reasonKey", "")) != "positive_memory" or remembered_score < 0.3 or not adolescent_actor.action_reason.contains(str(mallow.get("display_name"))):
		_fail("Recent positive peer memories did not overcome the adolescent's non-parent preference for Mallow.")
		return false
	if not _press_hud_button(str(adolescent.get("display_name"))):
		return false
	for frame in range(24):
		await process_frame
	if action_label == null or not action_label.text.contains("Remembering positive experiences with %s" % mallow.get("display_name")):
		_fail("The focused adolescent HUD did not explain its memory-driven choice of Mallow.")
		return false
	print("ADOLESCENT_MEMORY_OVERRIDE_CAPTURE_OK adolescent=%s peer=%s memory=%.2f reasonVisible=true" % [adolescent.get("display_name"), mallow.get("display_name"), remembered_score])
	return true


func _contains_sensed_peer(sensed_peers: Array[Dictionary], actor_id: String) -> bool:
	for sensed_peer: Dictionary in sensed_peers:
		if str(sensed_peer.get("id", "")) == actor_id:
			return true
	return false


func _run_child_observation_demo(child: Object) -> bool:
	var mallow = _world.call("profile_for", "mallow")
	var moss = _world.call("profile_for", "moss")
	if child == null or mallow == null or moss == null:
		_fail("The child-observation walkthrough could not find the child and both founders.")
		return false
	var child_actor: NornActor = child.get("actor")
	var mallow_actor: NornActor = mallow.get("actor")
	var moss_actor: NornActor = moss.get("actor")
	var fruit: Interactable = (_world.get("objects") as Dictionary).get("fruit", null)
	if child_actor == null or mallow_actor == null or moss_actor == null or fruit == null:
		_fail("The child-observation walkthrough could not find its actors or fruit.")
		return false
	mallow_actor.set_physics_process(true)
	moss_actor.set_physics_process(false)
	moss_actor.reset_position(Vector3(40.0, 0.0, 40.0))
	fruit.set_available(true)
	mallow_actor.reset_position(fruit.global_position + Vector3(0.75, 0.0, 0.0))
	child_actor.reset_position(mallow_actor.global_position + Vector3(0.0, 0.0, 2.0))
	_settled_needs(child)
	var child_cognition: Dictionary = child.get("cognition_state")
	child_cognition["traits"]["sociability"] = 1.0
	child.set("cognition_state", child_cognition)
	await physics_frame
	_world.call("_run_decision", child)
	if child_actor.current_action != "observe_peer" or child_actor.target != null or child_actor.is_walking or child_actor.global_position.distance_to(mallow_actor.global_position) > 2.1:
		_fail("The child did not settle to observe its visible parent before the witnessed event.")
		return false
	if not _press_hud_button(str(mallow.get("display_name"))):
		return false
	var learning_before: Dictionary = child_cognition.duplicate(true)
	var chemistry_before: Dictionary = Biochemistry.read_signals(child.get("biochemistry_state"))
	var expected_biochemistry: Dictionary = child.get("biochemistry_state").duplicate(true)
	if Biochemistry.apply_event(expected_biochemistry, "social").is_empty():
		_fail("Could not prepare the expected child observation chemistry.")
		return false
	var chemistry_after: Dictionary = Biochemistry.read_signals(expected_biochemistry)
	var expected_child_cognition: Dictionary = learning_before.duplicate(true)
	var baseline_cognition: Dictionary = learning_before.duplicate(true)
	Cognition.sync_chemistry(expected_child_cognition, chemistry_after)
	Cognition.sync_chemistry(baseline_cognition, chemistry_after)
	var witnessed_event := {
		"eventType": "observe", "actorId": "mallow", "actionId": "fruit", "targetId": "fruit",
		"time": float(_world.get("simulation_time")), "peerCount": 1,
		"sociability": float(child_cognition["traits"].get("sociability", 0.5)), "learningMultiplier": 1.5
	}
	var adult_baseline_event: Dictionary = witnessed_event.duplicate(true)
	adult_baseline_event["learningMultiplier"] = 1.0
	var external_chemistry := {"before": chemistry_before, "after": chemistry_after}
	var child_learning: Dictionary = Cognition.record_outcome(expected_child_cognition, witnessed_event, external_chemistry)
	var baseline_learning: Dictionary = Cognition.record_outcome(baseline_cognition, adult_baseline_event, external_chemistry)
	if not is_equal_approx(float(child_learning.get("learningDelta", 0.0)), float(baseline_learning.get("learningDelta", 0.0)) * 1.5):
		_fail("The deterministic child learning fixture did not produce a 1.5× adult comparison.")
		return false
	if not _press_hud_button("Guide to fruit") or not await _wait_for_status("Mallow ate honey fruit", 90):
		_fail("Mallow did not complete the fruit event while the child was attending.")
		return false
	var observed_episode: Dictionary = {}
	for episode_value: Variant in child.get("cognition_state")["episodes"]:
		if episode_value is Dictionary and episode_value.get("eventType", "") == "observe" and episode_value.get("actorId", "") == "mallow" and episode_value.get("actionId", "") == "fruit":
			observed_episode = episode_value
	if observed_episode.is_empty():
		_fail("The child did not remember the parent's witnessed fruit event.")
		return false
	var actual_association := float(child.get("cognition_state")["actionAssociations"]["fruit"])
	var expected_association := float(expected_child_cognition["actionAssociations"]["fruit"])
	var baseline_association := float(baseline_cognition["actionAssociations"]["fruit"])
	if not is_equal_approx(actual_association, expected_association) or actual_association <= baseline_association:
		_fail("The child's witnessed fruit association did not match its 1.5× learning update above the adult baseline.")
		return false
	_world.call("_run_decision", child)
	if not _press_hud_button(str(child.get("display_name"))):
		return false
	for frame in range(24):
		await process_frame
	var recall_label := _world.find_child("RememberedMomentsLabel", true, false) as Label
	if recall_label == null or not recall_label.text.contains("observed Mallow fruit"):
		_fail("The child's witnessed parent event was not visible in its remembered moments.")
		return false
	print("CHILD_OBSERVATION_CAPTURE_OK child=%s observed=Mallow fruit childDelta=%.3f adultDelta=%.3f association=%.3f memoryVisible=true" % [child.get("display_name"), float(child_learning["learningDelta"]), float(baseline_learning["learningDelta"]), actual_association])
	return true


func _run_social_observation_walkthrough() -> bool:
	var mallow = _world.call("profile_for", "mallow")
	var moss = _world.call("profile_for", "moss")
	if mallow == null or moss == null:
		_fail("The social walkthrough could not find both Norn profiles.")
		return false
	var mallow_actor: NornActor = mallow.get("actor")
	var moss_actor: NornActor = moss.get("actor")
	moss_actor.set_physics_process(true)
	var moss_cognition := Cognition.create_state(4181997, {"curiosity": 0.50, "sociability": 0.85}, {"hunger": 0.0, "curiosity": 0.0, "fatigue": 2.0})
	var moss_biochemistry := Biochemistry.create_state(moss_cognition["chemistry"])
	Cognition.sync_chemistry(moss_cognition, Biochemistry.read_signals(moss_biochemistry))
	moss.set("cognition_state", moss_cognition)
	moss.set("biochemistry_state", moss_biochemistry)
	moss.set("language_state", _world.get("_language").call("create_state"))
	moss.set("feedback_available", false)
	moss.set("feedback_action", "")
	moss.set("feedback_target", "")
	moss.set("feedback_time", -1000.0)
	moss.get("guidance").clear()
	moss.get("current_decision").clear()
	moss.get("recalled_moments").clear()
	_settled_needs(moss)
	_settled_needs(mallow)
	mallow.get("guidance").clear()
	mallow.set("feedback_available", false)
	mallow_actor.reset_position(Vector3(1.75, 0.0, 1.8))
	moss_actor.reset_position(Vector3(5.1, 0.0, 1.8))
	var objects: Dictionary = _world.get("objects")
	for item: Interactable in objects.values():
		item.set_available(true)
	(_world.get("_respawn_times") as Dictionary).clear()
	await process_frame
	await physics_frame
	_world.call("_sync_mallow_compatibility")
	_world.call("select_norn", "moss")
	_world.call("_run_decision", moss)
	if moss_actor.current_action != "observe_peer" or moss_actor.target != mallow_actor:
		_fail("Moss did not decide to approach Mallow to observe.")
		return false
	var moss_start_position := moss_actor.global_position
	var settled := false
	for frame in range(90):
		await physics_frame
		await process_frame
		if moss_actor.target == null and not moss_actor.is_walking and moss_actor.current_action == "observe_peer":
			settled = true
			break
	if not settled or moss_actor.global_position.distance_to(moss_start_position) < 0.5 or moss_actor.global_position.distance_to(mallow_actor.global_position) > 2.2:
		_fail("Moss did not visibly approach and settle near Mallow before the event.")
		return false
	moss_actor.global_position = mallow_actor.global_position + Vector3(1.8, 0.0, 0.0)
	await physics_frame
	_world.call("_run_decision", moss)
	if moss_actor.target != null or moss_actor.is_walking:
		_fail("Moss did not remain settled close enough to observe Mallow.")
		return false
	var social_comfort_before := float(Biochemistry.read_compounds(moss.get("biochemistry_state"))["socialComfort"])
	var fruit_association_before := float(moss.get("cognition_state")["actionAssociations"]["fruit"])
	if not _press_hud_button("Mallow") or not _press_hud_button("Guide to fruit"):
		return false
	if not await _wait_for_status("ate honey fruit", 240):
		_fail("Mallow did not complete the observed fruit action: %s" % str(_world.get("last_status")))
		return false
	await process_frame
	if not str(_world.get("last_status")).contains("Mallow ate honey fruit"):
		_fail("The recorded observed fruit event did not name Mallow.")
		return false
	var observer_episodes: Array = moss.get("cognition_state")["episodes"]
	var observation_episode: Dictionary = {}
	for episode: Dictionary in observer_episodes:
		if episode.get("eventType", "") == "observe" and episode.get("actorId", "") == "mallow" and episode.get("actionId", "") == "fruit":
			observation_episode = episode
			break
	var social_comfort_after := float(Biochemistry.read_compounds(moss.get("biochemistry_state"))["socialComfort"])
	var fruit_association_after := float(moss.get("cognition_state")["actionAssociations"]["fruit"])
	if observation_episode.is_empty() or float(observation_episode.get("sociability", -1.0)) != 0.85:
		_fail("Moss did not record the witnessed fruit event with its observer identity and sociability.")
		return false
	if social_comfort_after < social_comfort_before + 1.0 or fruit_association_after <= fruit_association_before:
		_fail("The observed fruit action did not update Moss's social chemistry and fruit association.")
		return false
	if not _world.get("feedback_available") or not _press_hud_button("Praise") or not str(_world.get("last_status")).contains("Mallow was praised"):
		_fail("Focused Praise was not applied to Mallow after the observed action.")
		return false
	if not _press_hud_button("Moss"):
		return false
	var recall_label := _world.find_child("RememberedMomentsLabel", true, false) as Label
	var recall_contains_observation := false
	for recalled: Dictionary in moss.get("recalled_moments"):
		if str(recalled.get("text", "")).contains("observed Mallow fruit"):
			recall_contains_observation = true
			break
	if recall_label == null or not recall_label.text.contains("Moss's remembered moments") or not recall_contains_observation:
		_fail("Moss's observed fruit memory was not visible in the focused HUD.")
		return false
	for frame in range(45):
		await process_frame
	print("SOCIAL_OBSERVATION_OK approach=%.2f socialComfort=%.2f->%.2f fruitAssociation=%.2f->%.2f focusedFeedback=Mallow praised memoryVisible=true" % [moss_start_position.distance_to(moss_actor.global_position), social_comfort_before, social_comfort_after, fruit_association_before, fruit_association_after])
	return true


func _run_action_utility_walkthrough() -> bool:
	var mallow = _world.call("profile_for", "mallow")
	if mallow == null:
		_fail("The action-utility walkthrough could not find Mallow.")
		return false
	var actor: NornActor = mallow.get("actor")
	var objects: Dictionary = _world.get("objects")
	var fruit: Interactable = objects.get("fruit")
	var spinner: Interactable = objects.get("spinner")
	var curiosity_marker: Interactable = objects.get("route_marker_1")
	var ui_value: Variant = _world.get("_ui")
	var action_label: Label = ui_value.get("_action_label") as Label if ui_value is Object else null
	if actor == null or fruit == null or spinner == null or curiosity_marker == null or action_label == null:
		_fail("The action-utility walkthrough could not find Mallow, the target objects, or the action HUD label.")
		return false

	var previous_cognition: Dictionary = (mallow.get("cognition_state") as Dictionary).duplicate(true)
	var previous_decision: Dictionary = (mallow.get("current_decision") as Dictionary).duplicate(true)
	var previous_recalled: Array = (mallow.get("recalled_moments") as Array).duplicate(true)
	var previous_position := actor.global_position
	var previous_spinner_position := spinner.global_position
	var previous_curiosity_marker_position := curiosity_marker.global_position
	var previous_rotation := actor.rotation
	var previous_velocity := actor.velocity
	var previous_target: Node3D = actor.target
	var previous_action := actor.current_action
	var previous_reason := actor.action_reason
	var previous_target_id := actor.target_id
	var previous_walking := actor.is_walking
	var previous_physics := actor.is_physics_processing()
	var previous_paused := bool(_world.get("paused"))
	var previous_time := float(_world.get("simulation_time"))
	var previous_focus := str(_world.get("focused_norn_id"))
	var previous_status := str(_world.get("last_status"))
	var previous_fruit_available := fruit.available
	var previous_spinner_available := spinner.available
	var respawn_times: Dictionary = _world.get("_respawn_times")
	var previous_respawn_times := respawn_times.duplicate(true)
	var capture_failure := ""

	_world.set("paused", true)
	actor.set_physics_process(false)
	actor.reset_position(Vector3(4.4, 0.0, -0.3))
	spinner.global_position = Vector3(6.0, 0.0, -0.3)
	curiosity_marker.global_position = Vector3(-10.0, 0.0, -8.0)
	fruit.set_available(true)
	spinner.set_available(true)
	respawn_times.clear()
	_world.set("_respawn_times", respawn_times)
	_world.call("select_norn", "mallow")
	var test_traits: Dictionary = previous_cognition["traits"].duplicate(true)
	var test_state: Dictionary = Cognition.create_state(int(previous_cognition.get("seed", 4181996)), test_traits, {
		"hunger": 10.0,
		"curiosity": 100.0,
		"fatigue": 5.0
	})
	mallow.set("cognition_state", test_state)
	_world.call("_sync_mallow_compatibility")
	var start_time := float(_world.get("simulation_time"))
	_world.set("simulation_time", start_time)
	_world.call("_update_camera")
	await process_frame
	await physics_frame
	var sensed_objects: Array[Dictionary] = _world.call("_sense_objects", mallow)
	var fruit_sensed := sensed_objects.any(func(entry: Dictionary) -> bool: return str(entry.get("id", "")) == "fruit")
	var spinner_sensed := sensed_objects.any(func(entry: Dictionary) -> bool: return str(entry.get("id", "")) == "spinner")
	if not fruit_sensed or not spinner_sensed:
		capture_failure = "The controlled Mallow position could not sense both safety-test interactables."
	else:
		_world.call("_run_decision", mallow)
		var initial_decision: Dictionary = mallow.get("current_decision")
		var initial_commitment := float(mallow.get("cognition_state").get("commitmentUntil", 0.0))
		if str(initial_decision.get("actionId", "")) != "spinner" or actor.target != spinner or initial_commitment <= start_time:
			capture_failure = "The controlled high-curiosity state did not establish a visible spinner commitment (action=%s target=%s commitment=%.2f reason=%s scores=%s)." % [str(initial_decision.get("actionId", "")), actor.target_id, initial_commitment, str(initial_decision.get("reason", "")), str(initial_decision.get("actionScores", {}))]
		else:
			for frame in range(30):
				await process_frame
			var urgent_state: Dictionary = mallow.get("cognition_state")
			var urgent_chemistry: Dictionary = urgent_state["chemistry"].duplicate(true)
			urgent_chemistry["hunger"] = 90.0
			urgent_chemistry["glucose"] = 10.0
			urgent_state["chemistry"] = urgent_chemistry
			mallow.set("cognition_state", urgent_state)
			_world.set("simulation_time", start_time + 0.5)
			_world.call("_run_decision", mallow)
			var urgent_decision: Dictionary = mallow.get("current_decision")
			var expected_reason := "Urgent hunger or low glucose is calling for food"
			_world.call("_refresh_ui")
			if str(urgent_decision.get("actionId", "")) != "fruit" or str(urgent_decision.get("safetyOverride", "")) != "fruit" or actor.current_action != "fruit" or actor.target != fruit or str(urgent_decision.get("reason", "")) != expected_reason:
				capture_failure = "Urgent hunger did not override Mallow's live spinner commitment in the world decision path."
			elif not action_label.text.contains("Mallow is fruit.") or not action_label.text.contains(expected_reason):
				capture_failure = "The HUD did not show Mallow's urgent fruit choice and its reason."
			else:
				for frame in range(300):
					await process_frame

	# Restore the temporary simulation fixture before reporting either success or failure.
	mallow.set("cognition_state", previous_cognition)
	mallow.set("current_decision", previous_decision)
	mallow.set("recalled_moments", previous_recalled)
	actor.global_position = previous_position
	spinner.global_position = previous_spinner_position
	curiosity_marker.global_position = previous_curiosity_marker_position
	actor.rotation = previous_rotation
	actor.velocity = previous_velocity
	actor.set_action_target(previous_target, previous_action, previous_reason, previous_target_id)
	actor.is_walking = previous_walking
	actor.set_physics_process(previous_physics)
	fruit.set_available(previous_fruit_available)
	spinner.set_available(previous_spinner_available)
	respawn_times.clear()
	respawn_times.merge(previous_respawn_times, true)
	_world.set("_respawn_times", respawn_times)
	_world.set("simulation_time", previous_time)
	_world.set("paused", previous_paused)
	_world.call("_sync_mallow_compatibility")
	_world.call("select_norn", previous_focus)
	_world.set("last_status", previous_status)
	_world.call("_refresh_ui")
	_world.call("_update_camera")
	if not actor.global_position.is_equal_approx(previous_position) or actor.is_physics_processing() != previous_physics or not is_equal_approx(float(_world.get("simulation_time")), previous_time) or bool(_world.get("paused")) != previous_paused:
		_fail("The action-utility walkthrough did not restore Mallow and the habitat clock safely.")
		return false
	if not capture_failure.is_empty():
		_fail(capture_failure)
		return false
	print("ACTION_UTILITY_CAPTURE_OK prior=spinner urgent=fruit safetyOverride=fruit hudVisible=true frames=300 stateRestored=true")
	return true


func _settled_needs(profile: Object) -> void:
	var biochemistry: Dictionary = profile.get("biochemistry_state")
	var compounds: Dictionary = Biochemistry.read_compounds(biochemistry)
	compounds["hunger"] = 0.0
	compounds["curiosity"] = 0.0
	compounds["fatigue"] = 4.0
	compounds["socialComfort"] = 20.0
	compounds["glucose"] = 100.0
	compounds["satiety"] = 100.0
	biochemistry["compounds"] = compounds
	Cognition.sync_chemistry(profile.get("cognition_state"), Biochemistry.read_signals(biochemistry))
	var cognition: Dictionary = profile.get("cognition_state")
	var associations: Dictionary = cognition["actionAssociations"]
	associations["fruit"] = 0.5
	associations["spinner"] = 0.5
	cognition["actionAssociations"] = associations
	var contexts: Dictionary = cognition["contextAssociations"]
	for action_id: String in Cognition.ACTION_IDS:
		contexts[action_id] = {}
		for context_id: String in Cognition.CONTEXT_IDS:
			contexts[action_id][context_id] = 0.5
	cognition["contextAssociations"] = contexts
	profile.set("biochemistry_state", biochemistry)
	profile.set("cognition_state", cognition)


func _show_resting_biochemistry() -> bool:
	var biochemical_state: Dictionary = _world.get("biochemistry_state")
	var compounds: Dictionary = Biochemistry.read_compounds(biochemical_state)
	compounds["fatigue"] = 100.0
	compounds["hunger"] = 0.0
	compounds["curiosity"] = 0.0
	biochemical_state["compounds"] = compounds
	_world.set("biochemistry_state", biochemical_state)

	var cognition: Dictionary = _world.get("cognition_state")
	var associations: Dictionary = cognition["actionAssociations"]
	associations["fruit"] = 0.5
	associations["spinner"] = 0.5
	cognition["actionAssociations"] = associations
	if not Cognition.sync_chemistry(cognition, Biochemistry.read_signals(biochemical_state)):
		_fail("Could not prepare the high-fatigue inspection scenario.")
		return false
	_world.set("cognition_state", cognition)
	var mallow_profile = _world.call("profile_for", "mallow")
	mallow_profile.guidance.clear()
	_world.call("_sync_mallow_compatibility")
	_world.call("_run_decision", mallow_profile)
	if str(_world.get("current_decision").get("actionId", "")) != "rest" or str(_world.get("norn").get("current_action")) != "rest":
		_fail("The high-fatigue inspection scenario did not choose rest.")
		return false
	var starting_fatigue := float(compounds["fatigue"])
	_world.set("last_status", "Mallow is tired, so the habitat is giving them time to rest.")
	_world.call("_refresh_ui")
	if not _press_hud_button("Biochemistry"):
		return false
	for frame in range(72):
		await process_frame
	var resting_compounds: Dictionary = Biochemistry.read_compounds(_world.get("biochemistry_state"))
	var ending_fatigue := float(resting_compounds["fatigue"])
	if ending_fatigue >= starting_fatigue or str(_world.get("norn").get("current_action")) != "rest":
		_fail("The recorded rest scenario did not recover fatigue while resting (%.2f → %.2f)." % [starting_fatigue, ending_fatigue])
		return false
	var fatigue_label := _world.find_child("BiochemistryCompound_fatigue", true, false) as Label
	var flux_label := _world.find_child("ReactionFluxesLabel", true, false) as Label
	if fatigue_label == null or not fatigue_label.text.contains("%.1f" % ending_fatigue) or flux_label == null or flux_label.text.is_empty() or flux_label.text == "No reaction flux this step" or flux_label.text.split("\n").size() > 6:
		_fail("The open inspector did not keep current fatigue and the bounded reaction flux list visible.")
		return false
	print("REST_INSPECTOR_OK fatigue=%.2f->%.2f compounds=%d" % [starting_fatigue, ending_fatigue, Biochemistry.COMPOUND_IDS.size()])
	return true


func _verify_starting_layout(world: Node) -> bool:
	var hud := world.find_child("HabitatHUD", true, false) as Control
	if hud == null or hud.get_child_count() == 0:
		_fail("The habitat HUD panel could not be found.")
		return false
	for control_name: String in ["NornRoster", "FamilyPanel", "SecondParentSelector", "StartEggButton", "FamilyArchive", "ExtinctionPanel", "FocusAgeStageLabel"]:
		if world.find_child(control_name, true, false) == null:
			_fail("The family and lifespan HUD control %s is missing." % control_name)
			return false
	var panel := hud.get_child(0) as Control
	if panel.size.x > 390.0:
		_fail("The HUD panel is too wide for the gameplay view (%d px)." % int(panel.size.x))
		return false
	var teach_input := world.find_child("TeachWordInput", true, false) as LineEdit
	var teach_mode_button := world.find_child("TeachModeButton", true, false) as Button
	if teach_input == null or teach_mode_button == null:
		_fail("The typed teaching field and Teach word control are missing from the HUD.")
		return false
	var panel_right := panel.position.x + panel.size.x
	var biochemistry_button := world.find_child("BiochemistryButton", true, false) as Button
	var biochemistry_panel := world.find_child("BiochemistryPanel", true, false) as Control
	if biochemistry_button == null or biochemistry_panel == null or biochemistry_panel.visible:
		_fail("The closed Biochemistry inspector toggle and panel are missing from the HUD.")
		return false
	var inspector_rect := biochemistry_panel.get_global_rect()
	if not is_equal_approx(inspector_rect.size.x, 340.0) or not is_equal_approx(inspector_rect.size.y, 600.0):
		_fail("The Biochemistry inspector must remain 340 by 600 pixels (got %s)." % str(inspector_rect.size))
		return false
	if inspector_rect.position.x < panel_right + 32.0 or inspector_rect.end.x > 1280.0 or inspector_rect.end.y > 720.0:
		_fail("The right-docked Biochemistry inspector overlaps the HUD or viewport edge.")
		return false
	world.set_process(false)
	world.set("_chemistry_accumulator", 0.0)
	world.call("_process", 0.1)
	world.set_process(true)
	biochemistry_button.emit_signal("pressed")
	if not biochemistry_panel.visible:
		_fail("The Biochemistry button did not open its inspector.")
		return false
	for compound_id: String in Biochemistry.COMPOUND_IDS:
		var compound_label := world.find_child("BiochemistryCompound_" + compound_id, true, false) as Label
		if compound_label == null or not compound_label.text.begins_with(compound_id + " "):
			_fail("The inspector did not list compound %s." % compound_id)
			return false
	var flux_label := world.find_child("ReactionFluxesLabel", true, false) as Label
	if flux_label == null or flux_label.text.is_empty() or flux_label.text == "No reaction flux this step" or flux_label.text.split("\n").size() > 6:
		_fail("The inspector did not display up to six non-zero reaction fluxes from the latest step.")
		return false
	biochemistry_button.emit_signal("pressed")
	if biochemistry_panel.visible:
		_fail("The Biochemistry button did not close its inspector.")
		return false
	if not world.has_method("toggle_teaching_mode") or not world.has_method("teach_word"):
		_fail("The world does not expose typed word teaching yet.")
		return false
	var camera := world.get("_camera") as Camera3D
	var objects: Dictionary = world.get("objects")
	var visible_rect := world.get_viewport().get_visible_rect()
	for object_id: String in ["fruit"]:
		var item := objects.get(object_id) as Node3D
		var screen_position := camera.unproject_position(item.global_position + Vector3.UP)
		if screen_position.x < panel_right + 32.0 or screen_position.x > visible_rect.size.x - 32.0:
			_fail("The %s is too close to the HUD or screen edge (x=%d, panel=%d)." % [object_id, int(screen_position.x), int(panel_right)])
			return false
	if not objects.has("spinner"):
		_fail("The guided spinner destination is missing from the expanded habitat.")
		return false
	return true


func _verify_language_rules() -> bool:
	var language_script := load("res://scripts/norn_language.gd") as Script
	if language_script == null:
		_fail("The scene-independent word model is missing.")
		return false
	var language_model: RefCounted = language_script.new()
	var state: Dictionary = language_model.call("create_state")
	var blank: Dictionary = language_model.call("teach_word", state, "   ", "fruit")
	var phrase: Dictionary = language_model.call("teach_word", state, "two words", "fruit")
	var too_long: Dictionary = language_model.call("teach_word", state, "abcdefghijklmnopqrstuvwxy", "fruit")
	if bool(blank.get("ok", true)) or bool(phrase.get("ok", true)) or bool(too_long.get("ok", true)):
		_fail("The word model accepted blank, phrase, or overlong input.")
		return false
	var first: Dictionary = language_model.call("teach_word", state, "Apple", "fruit")
	var premature: Dictionary = language_model.call("word_for_target", state, "fruit")
	var repeated: Dictionary = language_model.call("teach_word", state, "APPLE", "fruit")
	var conflict: Dictionary = language_model.call("teach_word", state, "apple", "spinner")
	if not bool(first.get("ok", false)) or not is_equal_approx(float(first.get("confidence", 0.0)), 0.38):
		_fail("A first object word did not begin at 0.38 confidence.")
		return false
	if not premature.is_empty():
		_fail("A word below 0.60 confidence was used before it was learned twice.")
		return false
	if not bool(repeated.get("ok", false)) or not is_equal_approx(float(repeated.get("confidence", 0.0)), 0.76):
		_fail("Repeating a case-variant word did not raise confidence to 0.76.")
		return false
	if bool(conflict.get("ok", true)):
		_fail("The word model allowed one word to map to conflicting targets.")
		return false
	var reinforced: Array = language_model.call("adjust_target", state, "fruit", 0.14)
	var spoken: Dictionary = language_model.call("word_for_target", state, "fruit")
	if reinforced.is_empty() or not is_equal_approx(float(spoken.get("confidence", 0.0)), 0.90):
		_fail("Praise reinforcement or the utterance threshold lookup failed.")
		return false
	var serialized: Dictionary = language_model.call("serialize_state", state)
	var restored: Dictionary = language_model.call("restore_state", serialized)
	var restored_word: Dictionary = language_model.call("word_for_target", restored, "fruit")
	if restored.is_empty() or str(restored_word.get("word", "")) != "Apple":
		_fail("The language model did not preserve display spelling in its save state.")
		return false
	var capped_state: Dictionary = language_model.call("create_state")
	for index in range(32):
		var added: Dictionary = language_model.call("teach_word", capped_state, "word%d" % index, "fruit")
		if not bool(added.get("ok", false)):
			_fail("The vocabulary cap rejected entry %d before the 32-word limit." % index)
			return false
	var over_cap: Dictionary = language_model.call("teach_word", capped_state, "word32", "fruit")
	if bool(over_cap.get("ok", true)):
		_fail("The language model accepted more than 32 words.")
		return false
	return true


func _run_teaching_walkthrough() -> bool:
	if not await _teach_via_hud("Apple", "fruit"):
		return false
	if not await _teach_via_hud("apple", "fruit"):
		return false
	var language_state: Dictionary = _world.get("language_state")
	if not is_equal_approx(float(language_state["words"]["apple"]["confidence"]), 0.76):
		_fail("Teaching a case-variant fruit word did not raise confidence to 0.76.")
		return false
	if not await _teach_via_hud("APPLE", "spinner"):
		return false
	if not str(_world.get("last_status")).contains("already means"):
		_fail("The HUD did not report a conflicting word target.")
		return false
	if not await _teach_via_hud("two words", "fruit"):
		return false
	if not str(_world.get("last_status")).contains("one word at a time"):
		_fail("The HUD did not reject a multiword phrase.")
		return false
	if not await _teach_via_hud("toy", "spinner") or not await _teach_via_hud("TOY", "spinner"):
		return false
	if not await _teach_via_hud("good", "praise") or not await _teach_via_hud("GOOD", "praise"):
		return false
	if not await _teach_via_hud("bad", "scold") or not await _teach_via_hud("BAD", "scold"):
		return false
	language_state = _world.get("language_state")
	var words: Dictionary = language_state["words"]
	for expected_word: String in ["apple", "toy", "good", "bad"]:
		if not words.has(expected_word):
			_fail("The HUD did not save the taught word %s in vocabulary." % expected_word)
			return false
	if bool(_world.get("feedback_available")) or not str(_world.get("feedback_action")).is_empty():
		_fail("Teaching Praise or Scold incorrectly applied behavior feedback.")
		return false
	return true


func _teach_via_hud(word: String, target_id: String) -> bool:
	if not bool(_world.get("teaching_mode")):
		if not _press_hud_button("Teach word"):
			return false
	var input := _world.find_child("TeachWordInput", true, false) as LineEdit
	if input == null:
		_fail("The typed teaching field could not be found.")
		return false
	input.text = word
	await create_timer(0.25).timeout
	var target_label := "Teach " + ("Praise" if target_id == "praise" else "Scold" if target_id == "scold" else target_id)
	if not _press_hud_button(target_label):
		return false
	await create_timer(0.25).timeout
	if word.strip_edges().contains(" "):
		return true
	if word.to_lower() == "apple" and target_id == "spinner":
		return true
	if not str(_world.get("last_status")).contains("Taught “"):
		_fail("The HUD did not teach %s to %s: %s" % [word, target_id, str(_world.get("last_status"))])
		return false
	return true


func _press_hud_button(button_text: String) -> bool:
	if _world == null:
		_fail("Cannot press a HUD control before the habitat is ready.")
		return false
	for candidate: Node in _world.find_children("*", "Button", true, false):
		var button := candidate as Button
		if button != null and button.text == button_text:
			if button.disabled:
				_fail("HUD button is disabled unexpectedly: %s" % button_text)
				return false
			button.emit_signal("pressed")
			return true
	_fail("Could not find the HUD button: %s" % button_text)
	return false


func _verify_legacy_save_migration() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		_fail("The walkthrough did not leave a local save to check.")
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		_fail("The saved family record could not be read for migration checks.")
		return false
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK or not (parser.data is Dictionary):
		_fail("The saved version-8 family record was not valid JSON.")
		return false
	var version8_record: Dictionary = parser.data
	var version8_norns: Variant = version8_record.get("norns", null)
	if int(version8_record.get("version", -1)) != HabitatWorldScript.SAVE_VERSION or not (version8_norns is Dictionary):
		_fail("The rendered family sequence did not leave a version-8 family save.")
		return false
	var legacy_norns: Dictionary = {}
	for founder_id: String in ["mallow", "moss"]:
		var founder_value: Variant = (version8_norns as Dictionary).get(founder_id, null)
		if not (founder_value is Dictionary):
			_fail("The version-8 family save is missing founder %s." % founder_id)
			return false
		var founder_record: Dictionary = (founder_value as Dictionary).duplicate(true)
		for metadata_key: String in ["displayName", "generation", "parentIds", "bodyColor", "lifeState", "position", "exploredLandmarks"]:
			founder_record.erase(metadata_key)
		legacy_norns[founder_id] = founder_record
	var record: Dictionary = version8_record.duplicate(true)
	record["version"] = 4
	record["norns"] = legacy_norns
	record.erase("nextNornNumber")
	record.erase("eggs")
	var norns = record.get("norns", null)
	if int(record.get("version", -1)) != 4 or not (norns is Dictionary) or norns.size() != 2 or not norns.has("mallow") or not norns.has("moss") or str(record.get("focusedNornId", "")) != "moss":
		_fail("The version-8 family save could not be reduced to a version-4 founder migration fixture.")
		return false
	var saved_mallow: Dictionary = norns["mallow"]
	var saved_moss: Dictionary = norns["moss"]
	var saved_biochemistry: Dictionary = saved_mallow.get("biochemistry", {})
	var saved_compounds: Dictionary = saved_biochemistry.get("compounds", {})
	var expected_compounds: Dictionary = Biochemistry.read_compounds(Biochemistry.restore_state(saved_biochemistry))
	if not _number_maps_match(saved_compounds, expected_compounds, Biochemistry.COMPOUND_IDS):
		_fail("The version-4 migration fixture did not contain all 19 Mallow compound concentrations.")
		return false
	var expected_signals: Dictionary = Biochemistry.read_signals(Biochemistry.restore_state(saved_biochemistry))
	var saved_cognition: Dictionary = saved_mallow.get("cognition", {})
	var saved_language: Dictionary = saved_mallow.get("language", {})
	var expected_word_count: int = saved_language["words"].size()
	var expected_association := float(saved_cognition["actionAssociations"]["fruit"])
	var expected_episode_count: int = saved_cognition["episodes"].size()
	var moss_cognition: Dictionary = Cognition.restore_state(saved_moss.get("cognition", {}))
	var moss_biochemistry: Dictionary = Biochemistry.restore_state(saved_moss.get("biochemistry", null))
	var moss_language: Dictionary = saved_moss.get("language", {})
	var moss_words: Variant = moss_language.get("words", null)
	if moss_cognition.is_empty() or int(moss_cognition.get("seed", -1)) != 4181997 or moss_biochemistry.is_empty() or not (moss_words is Dictionary):
		_fail("The version-4 migration fixture did not preserve Moss's independent profile.")
		return false

	var version3_record := {
		"version": 3,
		"seed": record.get("seed", 4181996),
		"simulationTime": record.get("simulationTime", 0.0),
		"cognition": saved_cognition,
		"language": saved_language,
		"biochemistry": saved_biochemistry
	}
	if not _write_save_record(version3_record):
		_fail("Could not prepare the version-3 migration scenario.")
		return false
	_world.call("load_game")
	var version3_cognition: Dictionary = _world.get("cognition_state")
	var version3_words: Dictionary = _world.get("language_state")["words"]
	var version3_signals: Dictionary = Biochemistry.read_signals(_world.get("biochemistry_state"))
	var migrated_moss = _world.call("profile_for", "moss")
	var migrated_moss_cognition: Dictionary = migrated_moss.get("cognition_state")
	if version3_words.size() != expected_word_count or not is_equal_approx(float(version3_cognition["actionAssociations"]["fruit"]), expected_association) or version3_cognition["episodes"].size() != expected_episode_count or not _number_maps_match(version3_signals, expected_signals, Biochemistry.SIGNAL_IDS):
		_fail("Version-3 migration did not preserve Mallow's learning, vocabulary, and cognition signals.")
		return false
	if int(migrated_moss_cognition.get("seed", -1)) != 4181997 or not migrated_moss_cognition["episodes"].is_empty() or not migrated_moss.get("language_state")["words"].is_empty():
		_fail("Version-3 migration did not initialize clean Moss from the deterministic seed.")
		return false

	var version2_record: Dictionary = version3_record.duplicate(true)
	version2_record["version"] = 2
	version2_record.erase("biochemistry")
	if not _write_save_record(version2_record):
		_fail("Could not prepare the version-2 migration scenario.")
		return false
	_world.call("load_game")
	var version2_language: Dictionary = _world.get("language_state")
	var version2_cognition: Dictionary = _world.get("cognition_state")
	var version2_words: Dictionary = version2_language.get("words", {})
	var version2_signals: Dictionary = Biochemistry.read_signals(_world.get("biochemistry_state"))
	if version2_words.size() != expected_word_count or not is_equal_approx(float(version2_cognition["actionAssociations"]["fruit"]), expected_association) or version2_cognition["episodes"].size() != expected_episode_count or not _number_maps_match(version2_signals, expected_signals, Biochemistry.SIGNAL_IDS):
		_fail("Version-2 migration did not preserve Mallow's learning, vocabulary, and cognition signals.")
		return false

	var version1_record: Dictionary = version2_record.duplicate(true)
	version1_record["version"] = 1
	version1_record.erase("language")
	if not _write_save_record(version1_record):
		_fail("Could not prepare the version-1 migration scenario.")
		return false
	_world.call("load_game")
	var version1_language: Dictionary = _world.get("language_state")
	var version1_cognition: Dictionary = _world.get("cognition_state")
	var version1_words: Dictionary = version1_language.get("words", {})
	var version1_signals: Dictionary = Biochemistry.read_signals(_world.get("biochemistry_state"))
	if not version1_words.is_empty():
		_fail("A version-1 save did not initialize an empty vocabulary.")
		return false
	if not is_equal_approx(float(version1_cognition["actionAssociations"]["fruit"]), expected_association) or version1_cognition["episodes"].size() != expected_episode_count or not _number_maps_match(version1_signals, expected_signals, Biochemistry.SIGNAL_IDS):
		_fail("Version-1 migration did not preserve learning and cognition signals.")
		return false
	return true


func _write_save_record(record: Dictionary) -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(record, "\t"))
	file.close()
	return true


func _number_maps_match(actual: Dictionary, expected: Dictionary, keys: Array[String]) -> bool:
	if actual.size() != keys.size() or expected.size() != keys.size():
		return false
	for key: String in keys:
		if not actual.has(key) or not expected.has(key) or not is_equal_approx(float(actual[key]), float(expected[key])):
			return false
	return true


func _wait_for_status(text: String, max_frames: int) -> bool:
	for frame in range(max_frames):
		if str(_world.get("last_status")).contains(text):
			return true
		await process_frame
	return str(_world.get("last_status")).contains(text)


func _backup_user_save() -> bool:
	_previous_save_exists = FileAccess.file_exists(SAVE_PATH)
	if _previous_save_exists:
		var previous_file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if previous_file == null:
			return false
		_previous_save_text = previous_file.get_as_text()
		previous_file.close()
	_save_backup_ready = true
	return true


func _restore_user_save() -> void:
	if not _save_backup_ready:
		return
	if _previous_save_exists:
		var restore_file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if restore_file == null:
			push_error("Could not restore the previous local save.")
			return
		restore_file.store_string(_previous_save_text)
		restore_file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	_save_backup_ready = false


func _fail(message: String) -> void:
	if _world != null and _world.has_method("is_recording") and bool(_world.call("is_recording")):
		_world.call("toggle_recording")
	_restore_user_save()
	push_error("VIDEO_CAPTURE_FAILED: " + message)
	quit(1)
