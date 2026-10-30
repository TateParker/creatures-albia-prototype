extends SceneTree

const HabitatScene = preload("res://scenes/main.tscn")
const SAVE_PATH := "user://albia_norn_save.json"

var _failures: Array[String] = []
var _save_backup_ready := false
var _save_backup_exists := false
var _save_backup_text := ""


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	if not _backup_user_save():
		_failures.append("the original local save can be preserved")
		_finish()
		return
	var world: Node = HabitatScene.instantiate()
	root.add_child(world)
	await process_frame
	world.set_process(false)
	_set_actor_physics(world, false)
	test_version8_position_and_landmark_round_trip(world)
	test_version6_migration_uses_safe_defaults_and_keeps_learning(world)
	test_version7_migration_uses_safe_defaults(world)
	test_invalid_position_is_rejected(world)
	await test_exploration_is_single_use_and_saved(world)
	test_guidance_persists_and_clears(world)
	world.free()
	_finish()


func test_version8_position_and_landmark_round_trip(world: Node) -> void:
	var mallow: Variant = world.call("profile_for", "mallow")
	var moss: Variant = world.call("profile_for", "moss")
	var mallow_position := Vector3(31.25, 0.0, 2.75)
	var moss_position := Vector3(33.0, 0.0, 1.5)
	mallow.get("actor").global_position = mallow_position
	moss.get("actor").global_position = moss_position
	world.call("save_game")
	var saved := _read_save_record()
	var saved_norns: Dictionary = saved.get("norns", {})
	_expect(int(saved.get("version", -1)) == 8, "new saves use world-save version 8")
	_expect(_vector_array_matches(saved_norns.get("mallow", {}).get("position", null), mallow_position), "version-8 save stores Mallow's world position")
	_expect(_vector_array_matches(saved_norns.get("moss", {}).get("position", null), moss_position), "version-8 save stores Moss's world position")
	_expect(saved_norns.get("mallow", {}).get("exploredLandmarks", null) is Array, "version-8 save stores Mallow's exploration state")
	_expect(saved_norns.get("moss", {}).get("exploredLandmarks", null) is Array, "version-8 save stores Moss's exploration state")
	if int(saved.get("version", -1)) != 8:
		return
	mallow.get("actor").global_position = Vector3(3.0, 0.0, 2.0)
	moss.get("actor").global_position = Vector3(6.2, 0.0, 1.6)
	world.call("load_game")
	_set_actor_physics(world, false)
	mallow = world.call("profile_for", "mallow")
	moss = world.call("profile_for", "moss")
	_expect(mallow.get("actor").global_position.distance_to(mallow_position) < 0.001, "loading restores Mallow's expanded-world position")
	_expect(moss.get("actor").global_position.distance_to(moss_position) < 0.001, "loading restores Moss's expanded-world position")


func test_version6_migration_uses_safe_defaults_and_keeps_learning(world: Node) -> void:
	var mallow: Variant = world.call("profile_for", "mallow")
	mallow.get("cognition_state")["actionAssociations"]["fruit"] = 0.73
	world.call("save_game")
	var record := _read_save_record()
	if int(record.get("version", -1)) != 8:
		_expect(false, "version-6 migration starts from a current save fixture")
		return
	record["version"] = 6
	var norns: Dictionary = record.get("norns", {})
	for actor_id: String in ["mallow", "moss"]:
		var profile_record: Dictionary = norns.get(actor_id, {})
		profile_record.erase("position")
		profile_record.erase("exploredLandmarks")
		norns[actor_id] = profile_record
	if not _write_save_record(record):
		_expect(false, "version-6 migration fixture can be written")
		return
	world.call("load_game")
	_set_actor_physics(world, false)
	mallow = world.call("profile_for", "mallow")
	var moss: Variant = world.call("profile_for", "moss")
	var marker: Interactable = world.get("objects")["route_marker_1"]
	_expect(mallow.get("actor").global_position.distance_to(Vector3(3.0, 0.0, 2.0)) < 0.001, "version-6 migration gives Mallow the established starter position")
	_expect(moss.get("actor").global_position.distance_to(Vector3(6.2, 0.0, 1.6)) < 0.001, "version-6 migration gives Moss the established starter position")
	_expect(is_equal_approx(float(mallow.get("cognition_state")["actionAssociations"]["fruit"]), 0.73), "version-6 migration preserves learned action associations")
	_expect(mallow.get("explored_landmarks").is_empty() and moss.get("explored_landmarks").is_empty(), "version-6 migration starts each Norn with fresh landmark history")
	_expect(marker.available, "version-6 migration keeps every landmark available")


func test_version7_migration_uses_safe_defaults(world: Node) -> void:
	world.call("save_game")
	var record := _read_save_record()
	if int(record.get("version", -1)) != 8:
		return
	record["version"] = 7
	var norns: Dictionary = record.get("norns", {})
	for actor_id: String in ["mallow", "moss"]:
		var profile_record: Dictionary = norns[actor_id]
		profile_record.erase("position")
		profile_record.erase("exploredLandmarks")
		norns[actor_id] = profile_record
	if not _write_save_record(record):
		_expect(false, "version-7 migration fixture can be written")
		return
	world.call("load_game")
	_set_actor_physics(world, false)
	var mallow: Variant = world.call("profile_for", "mallow")
	var moss: Variant = world.call("profile_for", "moss")
	var marker: Interactable = world.get("objects")["route_marker_1"]
	_expect(mallow.get("explored_landmarks").is_empty() and moss.get("explored_landmarks").is_empty(), "version-7 migration starts each Norn with fresh landmark history")
	_expect(mallow.get("actor").global_position.distance_to(Vector3(3.0, 0.0, 2.0)) < 0.001, "version-7 migration gives Mallow the established starter position")
	_expect(moss.get("actor").global_position.distance_to(Vector3(6.2, 0.0, 1.6)) < 0.001, "version-7 migration gives Moss the established starter position")
	_expect(marker.available, "version-7 migration starts with no consumed landmark state")


func test_invalid_position_is_rejected(world: Node) -> void:
	world.call("save_game")
	var record := _read_save_record()
	if int(record.get("version", -1)) != 8:
		_expect(false, "invalid-position validation has a version-8 save fixture")
		return
	var norns: Dictionary = record.get("norns", {})
	(norns["mallow"] as Dictionary)["position"] = [9999.0, 0.0, 0.0]
	if not world.has_method("_restore_version8_record"):
		_expect(false, "world exposes version-8 validation for the malformed-position check")
		return
	var restored: Dictionary = world.call("_restore_version8_record", record, float(record.get("simulationTime", 0.0)))
	_expect(restored.is_empty(), "version-8 restore rejects an out-of-bounds Norn position")


func test_exploration_is_single_use_and_saved(world: Node) -> void:
	var mallow: Variant = world.call("profile_for", "mallow")
	var moss: Variant = world.call("profile_for", "moss")
	var marker: Interactable = world.get("objects")["route_marker_1"]
	marker.set_available(true)
	(mallow.get("explored_landmarks") as Dictionary).clear()
	(moss.get("explored_landmarks") as Dictionary).clear()
	mallow.get("actor").global_position = marker.global_position + Vector3(0.0, 0.0, 1.2)
	moss.get("actor").global_position = marker.global_position + Vector3(0.0, 0.0, -1.2)
	await physics_frame
	var mallow_sensed: Array = world.call("_sense_objects", mallow)
	var moss_sensed: Array = world.call("_sense_objects", moss)
	_expect(_sensed_has_target(mallow_sensed, "route_marker_1") and _sensed_has_target(moss_sensed, "route_marker_1"), "both Norns initially perceive the shared route marker")
	var mallow_episodes: Array = mallow.get("cognition_state")["episodes"]
	var moss_episodes: Array = moss.get("cognition_state")["episodes"]
	var mallow_initial_count := mallow_episodes.size()
	var moss_initial_count := moss_episodes.size()
	world.call("_on_action_completed", "mallow", "explore", "route_marker_1")
	var mallow_discovered_count := mallow_episodes.size()
	_expect(marker.available, "Mallow's discovery leaves the shared route marker available")
	mallow_sensed = world.call("_sense_objects", mallow)
	moss_sensed = world.call("_sense_objects", moss)
	_expect(not _sensed_has_target(mallow_sensed, "route_marker_1"), "Mallow stops considering a landmark after discovering it")
	_expect(_sensed_has_target(moss_sensed, "route_marker_1"), "Moss can still consider Mallow's shared landmark")
	_expect(mallow_discovered_count == mallow_initial_count + 1, "Mallow's first landmark discovery records one exploration outcome")
	world.call("_on_action_completed", "mallow", "explore", "route_marker_1")
	_expect(mallow_episodes.size() == mallow_discovered_count, "Mallow cannot receive a repeat exploration reward")
	world.call("_on_action_completed", "moss", "explore", "route_marker_1")
	var moss_discovered_count := moss_episodes.size()
	_expect(moss_discovered_count == moss_initial_count + 1, "Moss can receive the first reward from Mallow's shared landmark")
	world.call("save_game")
	var saved := _read_save_record()
	var saved_norns: Dictionary = saved.get("norns", {})
	_expect((saved_norns.get("mallow", {}).get("exploredLandmarks", []) as Array).has("route_marker_1"), "version-8 save stores Mallow's completed discovery")
	_expect((saved_norns.get("moss", {}).get("exploredLandmarks", []) as Array).has("route_marker_1"), "version-8 save stores Moss's completed discovery")
	world.call("load_game")
	_set_actor_physics(world, false)
	mallow = world.call("profile_for", "mallow")
	moss = world.call("profile_for", "moss")
	marker = world.get("objects")["route_marker_1"]
	_expect(marker.available, "a saved discovery does not hide the landmark from peers")
	mallow_episodes = mallow.get("cognition_state")["episodes"]
	moss_episodes = moss.get("cognition_state")["episodes"]
	mallow_discovered_count = mallow_episodes.size()
	moss_discovered_count = moss_episodes.size()
	world.call("_on_action_completed", "mallow", "explore", "route_marker_1")
	_expect(mallow_episodes.size() == mallow_discovered_count, "Mallow's saved discovery prevents a repeat reward after loading")
	world.call("_on_action_completed", "moss", "explore", "route_marker_1")
	_expect(moss_episodes.size() == moss_discovered_count, "Moss's saved discovery prevents a repeat reward after loading")
	world.call("select_norn", "mallow")
	world.call("guide_to", "route_marker_1")
	var episodes_before_known_guidance := mallow_episodes.size()
	world.call("_on_action_completed", "mallow", "explore", "route_marker_1")
	_expect(mallow.get("guidance").is_empty(), "reaching an already discovered landmark clears matching guidance")
	_expect(mallow_episodes.size() == episodes_before_known_guidance, "guided revisit of a known landmark does not record another outcome")


func _sensed_has_target(sensed: Array, target_id: String) -> bool:
	return sensed.any(func(entry: Dictionary) -> bool: return str(entry.get("id", "")) == target_id)


func test_guidance_persists_and_clears(world: Node) -> void:
	var mallow: Variant = world.call("profile_for", "mallow")
	var actor: NornActor = mallow.get("actor")
	actor.global_position = Vector3(28.0, 0.0, 3.0)
	world.call("guide_to", "spring")
	world.set("simulation_time", float(world.get("simulation_time")) + 20.0)
	world.call("_update_timed_state")
	world.call("_run_decision", mallow)
	_expect(str(mallow.get("guidance").get("objectId", "")) == "spring", "long-distance guidance remains active past the former seven-second limit")
	_expect(actor.target == world.get("objects")["spring"], "long-distance guidance still directs the Norn to the chosen spring")
	world.call("_on_action_completed", "mallow", "drink", "spring")
	_expect(mallow.get("guidance").is_empty(), "completed guidance clears after the target interaction")
	world.call("guide_to", "fruit")
	_expect(str(mallow.get("guidance").get("objectId", "")) == "fruit", "a new guidance command replaces the prior target")
	world.call("guide_to", "spinner")
	(world.get("objects")["spinner"] as Interactable).set_available(false)
	world.call("_update_timed_state")
	_expect(mallow.get("guidance").is_empty(), "guidance clears when its target becomes unavailable")


func _set_actor_physics(world: Node, enabled: bool) -> void:
	for actor_id: String in ["mallow", "moss"]:
		var profile = world.call("profile_for", actor_id)
		if profile != null and profile.get("actor") is Node:
			(profile.get("actor") as Node).set_physics_process(enabled)


func _vector_array_matches(value: Variant, expected: Vector3) -> bool:
	if not (value is Array) or value.size() != 3:
		return false
	for index: int in range(3):
		if not (value[index] is float or value[index] is int):
			return false
	return is_equal_approx(float(value[0]), expected.x) and is_equal_approx(float(value[1]), expected.y) and is_equal_approx(float(value[2]), expected.z)


func _backup_user_save() -> bool:
	_save_backup_exists = FileAccess.file_exists(SAVE_PATH)
	if _save_backup_exists:
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file == null:
			return false
		_save_backup_text = file.get_as_text()
		file.close()
	_save_backup_ready = true
	return true


func _restore_user_save() -> bool:
	if not _save_backup_ready:
		return false
	if _save_backup_exists:
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file == null:
			return false
		file.store_string(_save_backup_text)
		file.close()
	else:
		var absolute_path := ProjectSettings.globalize_path(SAVE_PATH)
		if FileAccess.file_exists(SAVE_PATH) and DirAccess.remove_absolute(absolute_path) != OK:
			return false
	_save_backup_ready = false
	return true


func _read_save_record() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	file.close()
	return parser.data if error == OK and parser.data is Dictionary else {}


func _write_save_record(record: Dictionary) -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(record, "\t"))
	file.close()
	return true


func _expect(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish() -> void:
	if not _restore_user_save():
		_failures.append("the original local save can be restored")
	if _failures.is_empty():
		print("STABILIZATION_CHECKS_OK")
		quit(0)
		return
	for failure: String in _failures:
		push_error("STABILIZATION_CHECK_FAILED: " + failure)
	quit(1)
