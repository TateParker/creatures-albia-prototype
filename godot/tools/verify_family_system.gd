extends SceneTree

const HabitatScene = preload("res://scenes/main.tscn")
const Lifecycle = preload("res://scripts/norn_lifecycle.gd")
const Cognition = preload("res://scripts/norn_cognition.gd")

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
		test_family_system()
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


func test_family_system() -> void:
	const save_path := "user://albia_norn_save.json"
	var previous_exists := FileAccess.file_exists(save_path)
	var previous_text := ""
	if previous_exists:
		var previous_file := FileAccess.open(save_path, FileAccess.READ)
		if previous_file != null:
			previous_text = previous_file.get_as_text()
			previous_file.close()
	test_pairing_requires_distinct_living_adults()
	test_population_cap_includes_eggs_but_not_deceased()
	test_inheritance_is_reproducible()
	test_malformed_egg_records_rejected()
	test_generation_continues_past_three()
	test_family_events_record_neutral_memories()
	test_child_ids_are_monotonic()
	test_hatch_creates_fresh_independent_profile()
	if previous_exists and not previous_text.is_empty():
		var restore_file := FileAccess.open(save_path, FileAccess.WRITE)
		if restore_file != null:
			restore_file.store_string(previous_text)
			restore_file.close()
	elif not previous_exists:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


func test_pairing_requires_distinct_living_adults() -> void:
	var world := _new_family_world()
	_expect(world.has_method("living_profiles"), "family world exposes its ordered living roster")
	_expect(world.has_method("start_egg"), "family world exposes pairing")
	if world.has_method("start_egg"):
		var mallow: NornProfile = world.profile_for("mallow")
		var moss: NornProfile = world.profile_for("moss")
		mallow.life_state = Lifecycle.create_state(int(mallow.cognition_state["seed"]), 100.0)
		_expect(not bool(world.call("start_egg", "moss")), "a non-adult focused Norn cannot pair")
		mallow.life_state = Lifecycle.create_state(int(mallow.cognition_state["seed"]), 600.0)
		_expect(not bool(world.call("start_egg", "mallow")), "a Norn cannot pair with itself")
		_expect(bool(world.call("start_egg", "moss")), "two distinct adult Norns can start a clutch")
		_expect(world.eggs.size() == 1, "a valid pairing creates one egg")
	world.free()


func test_population_cap_includes_eggs_but_not_deceased() -> void:
	var world := _new_family_world()
	_expect(world.has_method("population_count"), "family world counts living Norns and pending eggs")
	if world.has_method("population_count") and world.has_method("start_egg"):
		_expect(int(world.call("population_count")) == 2, "founder Norns count toward population")
		_expect(bool(world.call("start_egg", "moss")), "first egg fits under population cap")
		_expect(bool(world.call("start_egg", "moss")), "second egg fills the four-slot population")
		var next_number_before := world.next_norn_number
		_expect(not bool(world.call("start_egg", "moss")), "a fifth Norn-or-egg slot is rejected")
		_expect(int(world.call("population_count")) == 4 and world.next_norn_number == next_number_before, "rejected pairing does not exceed capacity or allocate an ID")
		var mallow: NornProfile = world.profile_for("mallow")
		var dying_state: Dictionary = Lifecycle.create_state(int(mallow.cognition_state["seed"]), float(mallow.life_state["lifespanSeconds"]) - 1.0)
		Lifecycle.advance(dying_state, 1.0, 10.0)
		mallow.life_state = dying_state
		_expect(int(world.call("population_count")) == 3, "deceased Norns do not occupy a population slot")
	world.free()


func test_inheritance_is_reproducible() -> void:
	var first_world := _new_family_world()
	var second_world := _new_family_world()
	if first_world.has_method("start_egg") and second_world.has_method("start_egg"):
		first_world.call("start_egg", "moss")
		second_world.call("start_egg", "moss")
		_expect(first_world.eggs.size() == 1 and second_world.eggs.size() == 1, "pairing realizes an egg record")
		if first_world.eggs.size() == 1 and second_world.eggs.size() == 1:
			var first: Dictionary = first_world.eggs[0]
			var second: Dictionary = second_world.eggs[0]
			_expect(first == second, "identical world and parent state produce the same inherited traits and seed")
			var traits: Dictionary = first.get("traits", {})
			_expect(float(traits.get("curiosity", -1.0)) >= 0.05 and float(traits.get("curiosity", 2.0)) <= 0.95, "inherited curiosity stays in its bounded range")
			_expect(float(traits.get("sociability", -1.0)) >= 0.05 and float(traits.get("sociability", 2.0)) <= 0.95, "inherited sociability stays in its bounded range")
			var saved_file := FileAccess.open("user://albia_norn_save.json", FileAccess.READ)
			var saved: Variant = JSON.parse_string(saved_file.get_as_text()) if saved_file != null else null
			if saved_file != null:
				saved_file.close()
			var candidate: Dictionary = first_world.call("_restore_version5_record", saved, float(first_world.simulation_time)) if saved is Dictionary else {}
			var restored_eggs: Array = candidate.get("eggs", [])
			_expect(not candidate.is_empty() and restored_eggs.size() == 1 and _egg_records_equivalent(restored_eggs[0], first_world.eggs[0]), "version-5 restore preserves realized egg inheritance without rerolling")
	first_world.free()
	second_world.free()


func test_malformed_egg_records_rejected() -> void:
	var world := _new_family_world()
	if world.has_method("start_egg") and world.call("start_egg", "moss"):
		var save_file := FileAccess.open("user://albia_norn_save.json", FileAccess.READ)
		var saved: Variant = JSON.parse_string(save_file.get_as_text()) if save_file != null else null
		if save_file != null:
			save_file.close()
		_expect(saved is Dictionary, "a valid egg can be loaded as a version-5 candidate")
		if saved is Dictionary:
			var valid_record: Dictionary = saved
			var malformed: Array[Dictionary] = []
			var candidate := valid_record.duplicate(true)
			candidate["eggs"][0]["eggId"] = "egg-0"
			malformed.append(candidate)
			candidate = valid_record.duplicate(true)
			candidate["eggs"][0]["childId"] = "norn-2"
			malformed.append(candidate)
			candidate = valid_record.duplicate(true)
			candidate["eggs"].append((candidate["eggs"][0] as Dictionary).duplicate(true))
			malformed.append(candidate)
			candidate = valid_record.duplicate(true)
			candidate["eggs"][0]["parentIds"][0] = "missing-parent"
			malformed.append(candidate)
			candidate = valid_record.duplicate(true)
			candidate["eggs"][0]["generation"] = 2
			malformed.append(candidate)
			candidate = valid_record.duplicate(true)
			candidate["eggs"][0]["traits"]["curiosity"] = 1.0
			malformed.append(candidate)
			candidate = valid_record.duplicate(true)
			candidate["eggs"][0]["bodyColor"][0] = 1.1
			malformed.append(candidate)
			candidate = valid_record.duplicate(true)
			candidate["eggs"][0]["childSeed"] = 1
			malformed.append(candidate)
			candidate = valid_record.duplicate(true)
			candidate["eggs"][0]["remainingSeconds"] = -1.0
			malformed.append(candidate)
			candidate = valid_record.duplicate(true)
			candidate["eggs"][0]["remainingSeconds"] = 46.0
			malformed.append(candidate)
			var rejected_count := 0
			for malformed_record: Dictionary in malformed:
				if world.call("_restore_version5_record", malformed_record, float(world.simulation_time)).is_empty():
					rejected_count += 1
			_expect(rejected_count == malformed.size(), "malformed egg IDs, lineage, traits, colors, seeds, timers, and duplicates are rejected")
	world.free()


func test_generation_continues_past_three() -> void:
	var world := _new_family_world()
	if world.has_method("start_egg"):
		world.profile_for("mallow").generation = 3
		world.profile_for("moss").generation = 3
		world.call("start_egg", "moss")
		_expect(world.eggs.size() == 1 and int(world.eggs[0].get("generation", -1)) == 4, "family generations continue beyond three")
	world.free()


func test_family_events_record_neutral_memories() -> void:
	var world := _new_family_world()
	if world.has_method("start_egg"):
		var mallow: NornProfile = world.profile_for("mallow")
		var moss: NornProfile = world.profile_for("moss")
		var mallow_associations: Dictionary = mallow.cognition_state["actionAssociations"].duplicate(true)
		var moss_associations: Dictionary = moss.cognition_state["actionAssociations"].duplicate(true)
		world.call("start_egg", "moss")
		var mallow_episode: Dictionary = mallow.cognition_state["episodes"][-1]
		var moss_episode: Dictionary = moss.cognition_state["episodes"][-1]
		_expect(mallow_episode.get("eventType", "") == "family" and int(mallow_episode.get("valence", 9)) == 0 and mallow_episode.get("relatedNornIds", []) == ["moss", "norn-1"], "pairing gives Mallow a neutral, linked family memory")
		_expect(moss_episode.get("eventType", "") == "family" and int(moss_episode.get("valence", 9)) == 0 and moss_episode.get("relatedNornIds", []) == ["mallow", "norn-1"], "pairing gives Moss a neutral, linked family memory")
		_expect(mallow.cognition_state["actionAssociations"] == mallow_associations and moss.cognition_state["actionAssociations"] == moss_associations, "family memories do not reinforce food or play associations")
	world.free()


func test_child_ids_are_monotonic() -> void:
	var world := _new_family_world()
	if world.has_method("start_egg") and FileAccess.file_exists("res://scripts/norn_egg.gd"):
		world.call("start_egg", "moss")
		var first_egg_node: Node3D = world.get_node_or_null("egg-1") as Node3D
		if first_egg_node != null:
			var first_egg_record: Dictionary = first_egg_node.get("record")
			first_egg_record["remainingSeconds"] = 0.0
			first_egg_node.set("record", first_egg_record)
		world.call("_process", 0.0)
		_expect(world.profile_for("norn-1") != null, "first hatch reserves child ID norn-1")
		_expect(bool(world.call("start_egg", "moss")), "a later clutch can be created after a hatch")
		_expect(str(world.eggs[0].get("childId", "")) == "norn-2" and str(world.eggs[0].get("eggId", "")) == "egg-2" and world.next_norn_number == 3, "child and egg IDs advance monotonically")
	world.free()


func test_hatch_creates_fresh_independent_profile() -> void:
	var egg_script: Variant = load("res://scripts/norn_egg.gd") if FileAccess.file_exists("res://scripts/norn_egg.gd") else null
	_expect(egg_script is Script, "NornEgg scene-independent timer exists")
	if egg_script is Script:
		var egg = egg_script.new()
		egg.call("configure", {"eggId": "egg-1", "childId": "norn-1", "displayName": "Sprout", "parentIds": ["mallow", "moss"], "generation": 1, "traits": {"curiosity": 0.5, "sociability": 0.5}, "bodyColor": [0.3, 0.3, 0.3, 1.0], "childSeed": 123, "remainingSeconds": 45.0})
		_expect(not bool(egg.call("advance", 44.999)), "egg does not hatch before its full 45-second incubation")
		_expect(bool(egg.call("advance", 0.001)), "egg hatches at the end of its full incubation")
		_expect(not bool(egg.call("advance", 1.0)), "egg reports completion exactly once")
		(egg as Node).free()
	var world := _new_family_world()
	if world.has_method("start_egg") and FileAccess.file_exists("res://scripts/norn_egg.gd"):
		world.profile_for("moss").display_name = "Sprout"
		world.call("start_egg", "moss")
		var expected_focus := world.focused_norn_id
		for frame in range(90):
			world.call("_process", 0.5)
		var child: NornProfile = world.profile_for("norn-1")
		_expect(child != null and child.actor != null and child.generation == 1 and child.parent_ids == ["mallow", "moss"], "hatch creates a visible child with both parents")
		_expect(child != null and child.display_name == "Sprout 1", "living-name collision adds the child number")
		_expect(child != null and child.language_state.get("words", {}).is_empty(), "hatched Norn begins without inherited vocabulary")
		_expect(child != null and child.cognition_state["actionAssociations"] == {"fruit": 0.0, "spinner": 0.0, "rest": 0.0, "observe_peer": 0.0, "idle": 0.0}, "hatched Norn begins without inherited action associations")
		if child != null and not child.cognition_state["episodes"].is_empty():
			var birth_episode: Dictionary = child.cognition_state["episodes"][-1]
			_expect(birth_episode.get("eventType", "") == "birth" and birth_episode.get("relatedNornIds", []) == ["mallow", "moss"], "hatching records a birth memory linked to both parents")
		var mallow_episode: Dictionary = world.profile_for("mallow").cognition_state["episodes"][-1]
		var moss_episode: Dictionary = world.profile_for("moss").cognition_state["episodes"][-1]
		_expect(mallow_episode.get("eventType", "") == "family" and int(mallow_episode.get("valence", 9)) == 0 and mallow_episode.get("relatedNornIds", []) == ["moss", "norn-1"], "Mallow remembers the hatch neutrally with linked family IDs")
		_expect(moss_episode.get("eventType", "") == "family" and int(moss_episode.get("valence", 9)) == 0 and moss_episode.get("relatedNornIds", []) == ["mallow", "norn-1"], "Moss remembers the hatch neutrally with linked family IDs")
		_expect(world.focused_norn_id == expected_focus, "hatching leaves focus unchanged while living profiles remain")
	world.free()


func _new_family_world() -> AlbiaWorld:
	var world: AlbiaWorld = HabitatScene.instantiate()
	root.add_child(world)
	return world


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


func _egg_records_equivalent(actual: Variant, expected: Variant) -> bool:
	if not (actual is Dictionary) or not (expected is Dictionary):
		return false
	var actual_record: Dictionary = actual
	var expected_record: Dictionary = expected
	for key: String in ["eggId", "childId", "displayName", "parentIds"]:
		if actual_record.get(key) != expected_record.get(key):
			return false
	if int(actual_record.get("generation", -1)) != int(expected_record.get("generation", -2)) or int(actual_record.get("childSeed", -1)) != int(expected_record.get("childSeed", -2)):
		return false
	if not is_equal_approx(float(actual_record.get("remainingSeconds", -1.0)), float(expected_record.get("remainingSeconds", -2.0))):
		return false
	var actual_traits: Dictionary = actual_record.get("traits", {})
	var expected_traits: Dictionary = expected_record.get("traits", {})
	for trait_name: String in ["curiosity", "sociability"]:
		if not is_equal_approx(float(actual_traits.get(trait_name, -1.0)), float(expected_traits.get(trait_name, -2.0))):
			return false
	return _color_arrays_equal(actual_record.get("bodyColor", []), expected_record.get("bodyColor", []))


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
