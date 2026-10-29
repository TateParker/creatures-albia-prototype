extends SceneTree

const HabitatScene = preload("res://scenes/main.tscn")
const Lifecycle = preload("res://scripts/norn_lifecycle.gd")

var _failures: Array[String] = []
var _lifecycle_script: Script


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	if not FileAccess.file_exists("res://scripts/norn_lifecycle.gd"):
		_fail("NornLifecycle script is available")
		_finish()
		return
	var loaded_script = load("res://scripts/norn_lifecycle.gd")
	if loaded_script == null or not (loaded_script is Script):
		_fail("NornLifecycle script is available")
	else:
		_lifecycle_script = loaded_script
		test_stage_thresholds()
		test_lifespan_is_seeded_and_bounded()
		test_age_advances_and_reports_stage_change()
		test_death_is_recorded_once()
		test_lifecycle_restore_rejects_malformed_state()
		test_founder_save_metadata()
	_finish()


func test_stage_thresholds() -> void:
	var cases: Array[Array] = [
		[0.0, "baby"], [59.999, "baby"],
		[60.0, "child"], [179.999, "child"],
		[180.0, "adolescent"], [419.999, "adolescent"],
		[420.0, "adult"], [2999.999, "adult"],
		[3000.0, "elder"]
	]
	for test_case: Array in cases:
		var stage: String = str(_lifecycle_script.call("stage_for_age", float(test_case[0])))
		_expect(stage == str(test_case[1]), "age %.3f maps to %s (got %s)" % [float(test_case[0]), str(test_case[1]), stage])


func test_lifespan_is_seeded_and_bounded() -> void:
	var first: Dictionary = _lifecycle_script.call("create_state", 42, 0.0)
	var repeated: Dictionary = _lifecycle_script.call("create_state", 42, 0.0)
	var high_seed: Dictionary = _lifecycle_script.call("create_state", 600, 0.0)
	_expect(not first.is_empty() and float(first.get("lifespanSeconds", -1.0)) == 3342.0, "seed 42 produces the hand-calculated 3342-second lifespan")
	_expect(first.get("lifespanSeconds", -1.0) == repeated.get("lifespanSeconds", -2.0), "same seed produces the same lifespan")
	_expect(float(first.get("lifespanSeconds", -1.0)) >= 3300.0 and float(first.get("lifespanSeconds", -1.0)) <= 3900.0, "lifespan stays within 3300–3900 seconds")
	_expect(float(high_seed.get("lifespanSeconds", -1.0)) == 3900.0, "seed 600 produces the upper lifespan boundary")
	_expect(_lifecycle_script.call("create_state", 42, -1.0).is_empty(), "negative starting age is rejected")
	_expect(_lifecycle_script.call("create_state", 42, NAN).is_empty(), "non-finite starting age is rejected")
	_expect(_lifecycle_script.call("create_state", -1, 0.0).is_empty(), "negative seed is rejected")
	_expect(_lifecycle_script.call("create_state", 42, 3342.0).is_empty(), "new state cannot start at or beyond its lifespan limit")


func test_age_advances_and_reports_stage_change() -> void:
	var state: Dictionary = _lifecycle_script.call("create_state", 42, 59.0)
	var result: Dictionary = _lifecycle_script.call("advance", state, 1.0, 1.0)
	_expect(bool(result.get("ok", false)), "valid age advancement succeeds")
	_expect(bool(result.get("stageChanged", false)), "crossing the 60-second boundary reports one stage change")
	_expect(str(result.get("previousStage", "")) == "baby" and str(result.get("stage", "")) == "child", "stage transition reports baby to child")
	_expect(is_equal_approx(float(state.get("ageSeconds", -1.0)), 60.0), "age advances by the supplied in-game duration")
	_expect(not bool(result.get("died", true)), "ordinary stage transition does not report death")
	var invalid_delta: Dictionary = _lifecycle_script.call("advance", state, -1.0, 1.0)
	_expect(not bool(invalid_delta.get("ok", true)), "negative age delta is rejected")
	_expect(is_equal_approx(float(state.get("ageSeconds", -1.0)), 60.0), "rejected delta does not mutate age")
	var non_finite_time: Dictionary = _lifecycle_script.call("advance", state, 1.0, INF)
	_expect(not bool(non_finite_time.get("ok", true)), "non-finite simulation timestamp is rejected")


func test_death_is_recorded_once() -> void:
	var state: Dictionary = _lifecycle_script.call("create_state", 42, 0.0)
	var lifespan := float(state.get("lifespanSeconds", 0.0))
	var before_death: Dictionary = _lifecycle_script.call("advance", state, lifespan - 1.0, 100.0)
	_expect(bool(before_death.get("ok", false)) and not bool(before_death.get("died", true)), "Norn remains alive before its lifespan limit")
	var terminal: Dictionary = _lifecycle_script.call("advance", state, 1.0, 101.0)
	_expect(bool(terminal.get("ok", false)) and bool(terminal.get("died", false)), "reaching the lifespan limit reports death")
	_expect(not bool(state.get("alive", true)), "terminal age marks the lifecycle state deceased")
	var death: Dictionary = state.get("death", {})
	_expect(str(death.get("cause", "")) == "old-age", "terminal death cause is old age")
	_expect(is_equal_approx(float(death.get("ageSeconds", -1.0)), lifespan), "death record stores the terminal age")
	_expect(is_equal_approx(float(death.get("simulationTime", -1.0)), 101.0), "death record stores the supplied simulation time")
	_expect(is_equal_approx(float(state.get("ageSeconds", -1.0)), lifespan), "terminal age is clamped to the lifespan limit")
	var repeated: Dictionary = _lifecycle_script.call("advance", state, 1.0, 102.0)
	_expect(bool(repeated.get("ok", false)) and not bool(repeated.get("died", true)), "a deceased Norn does not die a second time")
	_expect(is_equal_approx(float(death.get("simulationTime", -1.0)), 101.0), "repeat advancement leaves the original death timestamp unchanged")


func test_lifecycle_restore_rejects_malformed_state() -> void:
	var state: Dictionary = _lifecycle_script.call("create_state", 42, 600.0)
	var serialized: Dictionary = _lifecycle_script.call("serialize_state", state)
	_expect(not _lifecycle_script.call("restore_state", serialized).is_empty(), "valid lifecycle state restores")
	var negative_age: Dictionary = serialized.duplicate(true)
	negative_age["ageSeconds"] = -1.0
	_expect(_lifecycle_script.call("restore_state", negative_age).is_empty(), "restore rejects negative age")
	var non_finite_lifespan: Dictionary = serialized.duplicate(true)
	non_finite_lifespan["lifespanSeconds"] = INF
	_expect(_lifecycle_script.call("restore_state", non_finite_lifespan).is_empty(), "restore rejects non-finite lifespan")
	var inconsistent_living: Dictionary = serialized.duplicate(true)
	inconsistent_living["death"] = {"cause": "old-age", "ageSeconds": 3342.0, "simulationTime": 101.0}
	_expect(_lifecycle_script.call("restore_state", inconsistent_living).is_empty(), "restore rejects death data on a living state")


func test_founder_save_metadata() -> void:
	const save_path := "user://albia_norn_save.json"
	var previous_exists := FileAccess.file_exists(save_path)
	var previous_text := ""
	if previous_exists:
		var previous_file := FileAccess.open(save_path, FileAccess.READ)
		if previous_file != null:
			previous_text = previous_file.get_as_text()
			previous_file.close()
	var world: AlbiaWorld = HabitatScene.instantiate()
	root.add_child(world)
	world.save_game()
	var saved_file := FileAccess.open(save_path, FileAccess.READ)
	var saved: Variant = JSON.parse_string(saved_file.get_as_text()) if saved_file != null else null
	if saved_file != null:
		saved_file.close()
	_expect(saved is Dictionary and int((saved as Dictionary).get("version", -1)) == 5, "founder save uses version 5")
	if saved is Dictionary:
		var record: Dictionary = saved
		var profiles: Dictionary = record.get("norns", {})
		_expect(profiles.size() == 2 and profiles.has("mallow") and profiles.has("moss"), "version-5 save contains stable starter IDs")
		for actor_id: String in ["mallow", "moss"]:
			var profile: Dictionary = profiles.get(actor_id, {})
			var expected_name := "Mallow" if actor_id == "mallow" else "Moss"
			var expected_color := [0.43, 0.27, 0.16, 1.0] if actor_id == "mallow" else [0.24, 0.42, 0.34, 1.0]
			var expected_seed := 4181996 if actor_id == "mallow" else 4181997
			var expected_life: Dictionary = Lifecycle.create_state(expected_seed, 600.0)
			_expect(profile.get("displayName", "") == expected_name, "%s retains its stable display name" % actor_id)
			_expect(int(profile.get("generation", -1)) == 0 and profile.get("parentIds", []) == [], "%s starts with no ancestry" % actor_id)
			_expect(_color_arrays_equal(profile.get("bodyColor", []), expected_color), "%s retains its established coat color" % actor_id)
			var life: Dictionary = profile.get("lifeState", {})
			_expect(is_equal_approx(float(life.get("ageSeconds", -1.0)), 600.0), "%s starts as a 600-second adult" % actor_id)
			_expect(is_equal_approx(float(life.get("lifespanSeconds", -1.0)), float(expected_life.get("lifespanSeconds", -2.0))), "%s receives deterministic lifespan from its cognition seed" % actor_id)
			_expect(profile.has("cognition") and profile.has("biochemistry") and profile.has("language"), "%s keeps existing learning and biochemical state" % actor_id)
		_expect(record.get("eggs", null) is Array and (record.get("eggs", []) as Array).is_empty(), "version-5 founder save starts with an empty egg list")
		_expect(int(record.get("nextNornNumber", 0)) == 1, "version-5 founder save starts child numbering at one")
	world.queue_free()
	if previous_exists and not previous_text.is_empty():
		var restore_file := FileAccess.open(save_path, FileAccess.WRITE)
		if restore_file != null:
			restore_file.store_string(previous_text)
			restore_file.close()
	elif not previous_exists:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _color_arrays_equal(actual: Variant, expected: Array) -> bool:
	if not (actual is Array) or actual.size() != expected.size():
		return false
	for index in range(expected.size()):
		if not is_equal_approx(float(actual[index]), float(expected[index])):
			return false
	return true


func _fail(message: String) -> void:
	_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("FAMILY_SYSTEM_CHECKS_OK")
		quit(0)
		return
	for failure: String in _failures:
		push_error("FAMILY_SYSTEM_CHECKS_FAILED: " + failure)
	quit(1)
