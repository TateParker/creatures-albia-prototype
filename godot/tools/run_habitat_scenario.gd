extends SceneTree

const HabitatScene = preload("res://scenes/main.tscn")
const Biochemistry = preload("res://scripts/norn_biochemistry.gd")
const NornLifecycle = preload("res://scripts/norn_lifecycle.gd")
const SAVE_PATH := "user://albia_norn_save.json"

var _scenario_failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_scenario")


func _run_scenario() -> void:
	var previous_save_exists := FileAccess.file_exists(SAVE_PATH)
	var previous_save := ""
	if previous_save_exists:
		var previous_file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if previous_file != null:
			previous_save = previous_file.get_as_text()
			previous_file.close()

	var world: AlbiaWorld = HabitatScene.instantiate()
	root.add_child(world)
	for frame in range(4):
		await process_frame
		await physics_frame
	if not _verify_world_biochemistry(world):
		quit(1)
		return

	var autonomous_fruit := await _wait_for_status(world, "ate honey fruit", 600)
	print("AUTONOMOUS FRUIT SEEKING: reached=%s; status=%s" % [autonomous_fruit, world.last_status])
	world.give_feedback("praise")
	print("PRAISE: %s; fruit association=%.2f" % [world.last_status, float(world.cognition_state["actionAssociations"]["fruit"])])

	var autonomous_spinner := await _wait_for_status(world, "played with the spinner", 600)
	print("AUTONOMOUS SPINNER SEEKING: reached=%s; status=%s" % [autonomous_spinner, world.last_status])
	if not autonomous_spinner:
		_scenario_failures.append("autonomous spinner seeking did not recover after the food event")
	if not autonomous_spinner:
		print("AUTONOMOUS SPINNER DIAGNOSTIC: time=%.2f; choice=%s; reason=%s; action=%s; target=%s; pos=%s; targetDist=%.2f; walking=%s; fruit=%s; spinner=%s; chemistry=%s" % [
			world.simulation_time,
			str(world.current_decision.get("actionId", "")),
			str(world.current_decision.get("reason", "")),
			world.norn.current_action,
			world.norn.target.object_id if world.norn.target != null else "none",
			str(world.norn.global_position),
			world.norn.global_position.distance_to(world.norn.target.global_position) if world.norn.target != null else -1.0,
			world.norn.is_walking,
			world.objects["fruit"].available,
			world.objects["spinner"].available,
			str(world.cognition_state["chemistry"])
		])
	var mallow_profile = world.profile_for("mallow")
	var moss_profile = world.profile_for("moss")
	var feedback_profile = mallow_profile if mallow_profile.feedback_available else moss_profile if moss_profile.feedback_available else null
	var spinner_scold_applied := false
	if feedback_profile != null:
		world.select_norn(feedback_profile.actor_id)
		world.give_feedback("scold")
		spinner_scold_applied = world.last_status.contains("was scolded")
	if not spinner_scold_applied:
		_scenario_failures.append("Scold did not apply to the Norn that played with the spinner")
	var spinner_association := float(feedback_profile.cognition_state["actionAssociations"]["spinner"]) if feedback_profile != null else -1.0
	print("SCOLD: applied=%s; status=%s; spinner association=%.2f" % [spinner_scold_applied, world.last_status, spinner_association])
	world.select_norn("mallow")

	world.reset_run()
	world.guide_to("fruit")
	var guided_fruit := await _wait_for_status(world, "ate honey fruit", 600)
	print("GUIDED FRUIT: reached=%s; status=%s" % [guided_fruit, world.last_status])
	world.give_feedback("praise")
	world.guide_to("spinner")
	var guided_spinner := await _wait_for_status(world, "played with the spinner", 600)
	print("GUIDED SPINNER: reached=%s; status=%s" % [guided_spinner, world.last_status])
	world.give_feedback("scold")

	world.select_norn("moss")
	world.toggle_teaching_mode()
	world.teach_word("sprig", "spinner")
	world.toggle_teaching_mode()
	var moss_focus_has_word: bool = world.focused_profile().language_state["words"].has("sprig")
	var mallow_vocabulary_isolated: bool = not world.profile_for("mallow").language_state["words"].has("sprig")
	world.select_norn("mallow")
	var mallow_focus_restored: bool = world.focused_profile().actor_id == "mallow"
	if not moss_focus_has_word or not mallow_vocabulary_isolated or not mallow_focus_restored:
		_scenario_failures.append("focus switching or per-Norn teaching failed")
	print("FOCUS AND TEACHING: Moss=%s; Mallow isolated=%s; restored=%s" % [moss_focus_has_word, mallow_vocabulary_isolated, mallow_focus_restored])

	world.toggle_pause()
	var time_at_pause := world.simulation_time
	for frame in range(8):
		await process_frame
	var pause_held := is_equal_approx(time_at_pause, world.simulation_time)
	world.toggle_pause()
	print("PAUSE/RESUME: paused clock held=%s; resumed=%s" % [pause_held, not world.paused])

	world.teaching_mode = true
	world.teach_word("Apple", "fruit")
	world.teaching_mode = false
	var fruit_association_before_save := float(world.cognition_state["actionAssociations"]["fruit"])
	var episodes_before_save: int = world.cognition_state["episodes"].size()
	var expected_compounds: Dictionary = Biochemistry.read_compounds(world.get("biochemistry_state"))
	var expected_signals: Dictionary = Biochemistry.read_signals(world.get("biochemistry_state"))
	var expected_language_words: Dictionary = world.language_state["words"].duplicate(true)
	moss_profile = world.profile_for("moss")
	var expected_moss_compounds: Dictionary = Biochemistry.read_compounds(moss_profile.biochemistry_state)
	var expected_moss_signals: Dictionary = Biochemistry.read_signals(moss_profile.biochemistry_state)
	var expected_moss_words: Dictionary = moss_profile.language_state["words"].duplicate(true)
	var expected_moss_association := float(moss_profile.cognition_state["actionAssociations"]["spinner"])
	var expected_moss_episodes: int = moss_profile.cognition_state["episodes"].size()
	world.save_game()
	var saved_file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var valid_saved_text := saved_file.get_as_text() if saved_file != null else ""
	if saved_file != null:
		saved_file.close()
	var saved_record = JSON.parse_string(valid_saved_text)
	if not (saved_record is Dictionary):
		_scenario_failures.append("save did not write a JSON object")
		saved_record = {}
	var saved_norns: Dictionary = saved_record.get("norns", {})
	if int(saved_record.get("version", -1)) != 5 or not saved_norns.has("mallow") or not saved_norns.has("moss"):
		_scenario_failures.append("save did not write both Norns in version-5 format")
	var saved_mallow: Dictionary = saved_norns.get("mallow", {})
	var saved_moss: Dictionary = saved_norns.get("moss", {})
	if saved_mallow.is_empty() or saved_moss.is_empty() or str(saved_record.get("focusedNornId", "")) != "mallow":
		_scenario_failures.append("version-5 save did not contain both profile records and focus")
	if int(saved_record.get("nextNornNumber", 0)) != 1 or not (saved_record.get("eggs", null) is Array) or not (saved_record.get("eggs", []) as Array).is_empty():
		_scenario_failures.append("version-5 save did not initialize its child number and egg list")
	for founder_id: String in ["mallow", "moss"]:
		var founder: Dictionary = saved_norns.get(founder_id, {})
		var founder_name := "Mallow" if founder_id == "mallow" else "Moss"
		var founder_color := [0.43, 0.27, 0.16, 1.0] if founder_id == "mallow" else [0.24, 0.42, 0.34, 1.0]
		var expected_seed := 4181996 if founder_id == "mallow" else 4181997
		var expected_life: Dictionary = NornLifecycle.create_state(expected_seed, 600.0)
		var founder_life: Dictionary = founder.get("lifeState", {})
		if str(founder.get("displayName", "")) != founder_name or int(founder.get("generation", -1)) != 0 or not (founder.get("parentIds", []) as Array).is_empty():
			_scenario_failures.append("version-5 save lost %s identity or founder ancestry" % founder_id)
		if not _number_arrays_equal(founder.get("bodyColor", []), founder_color) or not is_equal_approx(float(founder_life.get("ageSeconds", -1.0)), 600.0) or not is_equal_approx(float(founder_life.get("lifespanSeconds", -1.0)), float(expected_life["lifespanSeconds"])):
			_scenario_failures.append("version-5 save lost %s appearance or deterministic adult lifespan" % founder_id)
	if saved_mallow.has("biochemistry"):
		var saved_biochemistry: Dictionary = saved_mallow["biochemistry"]
		if not _number_maps_equal(saved_biochemistry.get("compounds", {}), expected_compounds, Biochemistry.COMPOUND_IDS):
			_scenario_failures.append("version-5 save did not preserve all Mallow compound concentrations")
	if saved_moss.has("biochemistry"):
		var saved_moss_biochemistry: Dictionary = saved_moss["biochemistry"]
		if not _number_maps_equal(saved_moss_biochemistry.get("compounds", {}), expected_moss_compounds, Biochemistry.COMPOUND_IDS):
			_scenario_failures.append("version-5 save did not preserve all Moss compound concentrations")
	if not saved_mallow.is_empty():
		var saved_mallow_cognition: Dictionary = saved_mallow.get("cognition", {})
		var saved_mallow_language: Dictionary = saved_mallow.get("language", {})
		var saved_mallow_biochemistry: Dictionary = saved_mallow.get("biochemistry", {})
		var saved_mallow_biochemistry_state: Dictionary = Biochemistry.restore_state(saved_mallow_biochemistry)
		if not is_equal_approx(float(saved_mallow_cognition.get("actionAssociations", {}).get("fruit", -1.0)), fruit_association_before_save) or saved_mallow_cognition.get("episodes", []).size() != episodes_before_save:
			_scenario_failures.append("version-5 save did not preserve Mallow's cognition and episode history")
		if saved_mallow_language.get("words", {}) != expected_language_words or saved_mallow_biochemistry_state.is_empty() or not _number_maps_equal(Biochemistry.read_signals(saved_mallow_biochemistry_state), expected_signals, Biochemistry.SIGNAL_IDS):
			_scenario_failures.append("version-5 save did not preserve Mallow's language or biochemical signals")
	if not saved_moss.is_empty():
		var saved_moss_cognition: Dictionary = saved_moss.get("cognition", {})
		var saved_moss_language: Dictionary = saved_moss.get("language", {})
		var saved_moss_biochemistry: Dictionary = saved_moss.get("biochemistry", {})
		var saved_moss_biochemistry_state: Dictionary = Biochemistry.restore_state(saved_moss_biochemistry)
		if not is_equal_approx(float(saved_moss_cognition.get("actionAssociations", {}).get("spinner", -1.0)), expected_moss_association) or saved_moss_cognition.get("episodes", []).size() != expected_moss_episodes:
			_scenario_failures.append("version-5 save did not preserve Moss's cognition and episode history")
		if saved_moss_language.get("words", {}) != expected_moss_words or saved_moss_biochemistry_state.is_empty() or not _number_maps_equal(Biochemistry.read_signals(saved_moss_biochemistry_state), expected_moss_signals, Biochemistry.SIGNAL_IDS):
			_scenario_failures.append("version-5 save did not preserve Moss's language or biochemical signals")
	var legacy_mallow: Dictionary = {
		"cognition": saved_mallow.get("cognition", {}),
		"language": saved_mallow.get("language", {}),
		"biochemistry": saved_mallow.get("biochemistry", {})
	}
	var version3_record: Dictionary = {
		"version": 3,
		"seed": saved_record.get("seed", 4181996),
		"simulationTime": saved_record.get("simulationTime", 0.0),
		"cognition": legacy_mallow["cognition"],
		"language": legacy_mallow["language"],
		"biochemistry": legacy_mallow["biochemistry"]
	}
	if not _write_saved_record(saved_record):
		_scenario_failures.append("could not prepare version-5 round-trip fixture")
	world.cognition_state["actionAssociations"]["fruit"] = 0.99
	world.language_state["words"].clear()
	var roundtrip_bio: Dictionary = world.get("biochemistry_state")
	var roundtrip_compounds: Dictionary = Biochemistry.read_compounds(roundtrip_bio)
	roundtrip_compounds["glucose"] = 1.0
	roundtrip_bio["compounds"] = roundtrip_compounds
	world.set("biochemistry_state", roundtrip_bio)
	moss_profile = world.profile_for("moss")
	moss_profile.cognition_state["actionAssociations"]["spinner"] = 0.99
	moss_profile.language_state["words"].clear()
	var moss_roundtrip_bio: Dictionary = moss_profile.biochemistry_state
	var moss_roundtrip_compounds: Dictionary = Biochemistry.read_compounds(moss_roundtrip_bio)
	moss_roundtrip_compounds["glucose"] = 2.0
	moss_roundtrip_bio["compounds"] = moss_roundtrip_compounds
	world.load_game()
	moss_profile = world.profile_for("moss")
	var v5_round_trip_ok := _number_maps_equal(Biochemistry.read_compounds(world.get("biochemistry_state")), expected_compounds, Biochemistry.COMPOUND_IDS)
	v5_round_trip_ok = v5_round_trip_ok and _number_maps_equal(Biochemistry.read_signals(world.get("biochemistry_state")), expected_signals, Biochemistry.SIGNAL_IDS)
	v5_round_trip_ok = v5_round_trip_ok and _number_maps_equal(Biochemistry.read_compounds(moss_profile.biochemistry_state), expected_moss_compounds, Biochemistry.COMPOUND_IDS)
	v5_round_trip_ok = v5_round_trip_ok and _number_maps_equal(Biochemistry.read_signals(moss_profile.biochemistry_state), expected_moss_signals, Biochemistry.SIGNAL_IDS)
	v5_round_trip_ok = v5_round_trip_ok and world.language_state["words"] == expected_language_words and moss_profile.language_state["words"] == expected_moss_words
	v5_round_trip_ok = v5_round_trip_ok and is_equal_approx(float(world.cognition_state["actionAssociations"]["fruit"]), fruit_association_before_save)
	v5_round_trip_ok = v5_round_trip_ok and is_equal_approx(float(moss_profile.cognition_state["actionAssociations"]["spinner"]), expected_moss_association)
	v5_round_trip_ok = v5_round_trip_ok and world.cognition_state["episodes"].size() == episodes_before_save and moss_profile.cognition_state["episodes"].size() == expected_moss_episodes
	v5_round_trip_ok = v5_round_trip_ok and _founder_defaults_are_valid(world) and world.focused_norn_id == "mallow"
	if not v5_round_trip_ok:
		_scenario_failures.append("version-5 round trip did not preserve both Norns' learning, biochemistry, and family defaults")
	print("VERSION-5 ROUND TRIP: both profiles=%s; focus=%s" % [v5_round_trip_ok, world.focused_norn_id])
	var changed_bio: Dictionary = world.get("biochemistry_state")
	var changed_compounds: Dictionary = Biochemistry.read_compounds(changed_bio)
	changed_compounds["glucose"] = 1.0
	changed_bio["compounds"] = changed_compounds
	world.set("biochemistry_state", changed_bio)
	world.cognition_state["actionAssociations"]["fruit"] = 0.99
	world.language_state["words"].clear()
	var moss_bio: Dictionary = moss_profile.biochemistry_state
	var moss_compounds: Dictionary = Biochemistry.read_compounds(moss_bio)
	moss_compounds["glucose"] = 2.0
	moss_bio["compounds"] = moss_compounds
	moss_profile.cognition_state["actionAssociations"]["spinner"] = 0.99
	moss_profile.language_state["words"].clear()
	var version4_record: Dictionary = saved_record.duplicate(true)
	version4_record["version"] = 4
	version4_record.erase("nextNornNumber")
	version4_record.erase("eggs")
	for founder_id: String in ["mallow", "moss"]:
		for metadata_key: String in ["displayName", "generation", "parentIds", "bodyColor", "lifeState"]:
			(version4_record["norns"][founder_id] as Dictionary).erase(metadata_key)
	if not _write_saved_record(version4_record):
		_scenario_failures.append("could not prepare the version-4 migration fixture")
	world.load_game()
	moss_profile = world.profile_for("moss")
	var restored_compounds: Dictionary = Biochemistry.read_compounds(world.get("biochemistry_state"))
	var restored_signals: Dictionary = Biochemistry.read_signals(world.get("biochemistry_state"))
	var restored_words: Dictionary = world.language_state["words"]
	var moss_restored_compounds: Dictionary = Biochemistry.read_compounds(moss_profile.biochemistry_state)
	var compounds_round_trip: bool = _number_maps_equal(restored_compounds, expected_compounds, Biochemistry.COMPOUND_IDS)
	var signals_round_trip: bool = _number_maps_equal(restored_signals, expected_signals, Biochemistry.SIGNAL_IDS)
	if not compounds_round_trip or not signals_round_trip:
		_scenario_failures.append("version-4 migration did not preserve Mallow's compounds and cognition signals")
	if not _number_maps_equal(moss_restored_compounds, expected_moss_compounds, Biochemistry.COMPOUND_IDS):
		_scenario_failures.append("version-4 migration did not preserve Moss's compounds")
	if not is_equal_approx(float(world.cognition_state["actionAssociations"]["fruit"]), fruit_association_before_save) or not is_equal_approx(float(moss_profile.cognition_state["actionAssociations"]["spinner"]), expected_moss_association):
		_scenario_failures.append("version-4 migration did not preserve both learned associations")
	if restored_words != expected_language_words or moss_profile.language_state["words"] != expected_moss_words:
		_scenario_failures.append("version-4 migration did not preserve both vocabularies")
	if world.cognition_state["episodes"].size() != episodes_before_save or moss_profile.cognition_state["episodes"].size() != expected_moss_episodes:
		_scenario_failures.append("version-4 migration did not preserve both episode histories")
	if not _founder_defaults_are_valid(world):
		_scenario_failures.append("version-4 migration did not supply adult founder defaults")
	print("VERSION-4 MIGRATION: mallow=%s; moss=%s; focus=%s; episodes=%d/%d" % [
		str(compounds_round_trip and signals_round_trip and restored_words == expected_language_words),
		str(_number_maps_equal(moss_restored_compounds, expected_moss_compounds, Biochemistry.COMPOUND_IDS) and moss_profile.language_state["words"] == expected_moss_words),
		str(world.get("focused_norn_id") == "mallow"),
		world.cognition_state["episodes"].size(),
		moss_profile.cognition_state["episodes"].size()
	])

	if not _write_saved_record(version3_record):
		_scenario_failures.append("could not prepare version-3 migration scenario")
	world.load_game()
	if not _number_maps_equal(Biochemistry.read_compounds(world.get("biochemistry_state")), expected_compounds, Biochemistry.COMPOUND_IDS) or not _founder_defaults_are_valid(world):
		_scenario_failures.append("version-3 migration did not preserve biochemistry or supply adult founder defaults")
	if world.language_state["words"] != expected_language_words or not is_equal_approx(float(world.cognition_state["actionAssociations"]["fruit"]), fruit_association_before_save) or world.cognition_state["episodes"].size() != episodes_before_save:
		_scenario_failures.append("version-3 migration did not preserve cognition and vocabulary")
	var version2_record: Dictionary = version3_record.duplicate(true)
	version2_record["version"] = 2
	version2_record.erase("biochemistry")
	_write_saved_record(version2_record)
	changed_bio = world.get("biochemistry_state")
	changed_compounds = Biochemistry.read_compounds(changed_bio)
	changed_compounds["glucose"] = 2.0
	changed_bio["compounds"] = changed_compounds
	world.set("biochemistry_state", changed_bio)
	world.load_game()
	var version2_signals: Dictionary = Biochemistry.read_signals(world.get("biochemistry_state"))
	if version2_signals != version2_record["cognition"]["chemistry"] or world.language_state["words"] != expected_language_words or not is_equal_approx(float(world.cognition_state["actionAssociations"]["fruit"]), fruit_association_before_save) or world.cognition_state["episodes"].size() != episodes_before_save or not _founder_defaults_are_valid(world):
		_scenario_failures.append("version-2 migration did not preserve cognition signals and vocabulary")
	print("VERSION-2 MIGRATION: signals=%s; vocabulary=%s" % [
		str(version2_signals == version2_record["cognition"]["chemistry"]),
		str(world.language_state["words"] == expected_language_words)
	])

	var version1_record: Dictionary = version2_record.duplicate(true)
	version1_record["version"] = 1
	version1_record.erase("language")
	_write_saved_record(version1_record)
	changed_bio = world.get("biochemistry_state")
	changed_compounds = Biochemistry.read_compounds(changed_bio)
	changed_compounds["glucose"] = 3.0
	changed_bio["compounds"] = changed_compounds
	world.set("biochemistry_state", changed_bio)
	world.load_game()
	var version1_signals: Dictionary = Biochemistry.read_signals(world.get("biochemistry_state"))
	var version1_words: Dictionary = world.language_state["words"]
	if version1_signals != version1_record["cognition"]["chemistry"] or not version1_words.is_empty() or not is_equal_approx(float(world.cognition_state["actionAssociations"]["fruit"]), fruit_association_before_save) or world.cognition_state["episodes"].size() != episodes_before_save or not _founder_defaults_are_valid(world):
		_scenario_failures.append("version-1 migration did not preserve cognition signals and initialize an empty vocabulary")
	print("VERSION-1 MIGRATION: signals=%s; vocabulary_empty=%s" % [
		str(version1_signals == version1_record["cognition"]["chemistry"]),
		str(version1_words.is_empty())
	])

	if not _write_saved_record(saved_record):
		_scenario_failures.append("could not prepare version-5 malformed-candidate checks")
	var live_mallow: NornProfile = world.profile_for("mallow")
	live_mallow.cognition_state["actionAssociations"]["fruit"] = 0.731
	var malformed_v5_records: Array[Dictionary] = _make_malformed_v5_records(saved_record)
	var malformed_labels: Array[String] = [
		"duplicate stable ID", "missing parent reference", "negative age", "lifespan below minimum",
		"alive with death data", "dead without old-age death", "invalid focus", "non-monotonic child number", "population above four"
	]
	var malformed_rejections := 0
	for index in range(malformed_v5_records.size()):
		var candidate_value: Variant
		if world.has_method("_restore_version5_record"):
			candidate_value = world.call("_restore_version5_record", malformed_v5_records[index], float(saved_record.get("simulationTime", 0.0)))
		var unchanged := is_equal_approx(float(live_mallow.cognition_state["actionAssociations"]["fruit"]), 0.731)
		if candidate_value is Dictionary and (candidate_value as Dictionary).is_empty() and unchanged:
			malformed_rejections += 1
		else:
			_scenario_failures.append("malformed v5 candidate was accepted or changed live state: %s" % malformed_labels[index])
	print("MALFORMED VERSION-5 CANDIDATES: rejected=%d/%d; live state unchanged=%s" % [malformed_rejections, malformed_v5_records.size(), is_equal_approx(float(live_mallow.cognition_state["actionAssociations"]["fruit"]), 0.731)])
	var safe_v5_fallback := false
	if not malformed_v5_records.is_empty():
		_write_saved_record(malformed_v5_records[0])
		world.load_game()
		safe_v5_fallback = is_equal_approx(float(world.cognition_state["actionAssociations"]["fruit"]), 0.0) and str(world.last_status).contains("started a clean seeded Norn")
		if not safe_v5_fallback:
			_scenario_failures.append("invalid version-5 candidate did not safely reset the live habitat")
	print("INVALID VERSION-5 FALLBACK: fresh=%s; status=%s" % [safe_v5_fallback, world.last_status])

	var invalid_version3: Dictionary = version3_record.duplicate(true)
	invalid_version3["biochemistry"]["compounds"]["ATP"] = 101.0
	_write_saved_record(invalid_version3)
	world.load_game()
	var invalid_fallback_is_fresh: bool = str(world.last_status).to_lower().contains("failed validation") and world.cognition_state["actionAssociations"]["fruit"] == 0.0
	if not invalid_fallback_is_fresh or Biochemistry.read_signals(world.get("biochemistry_state")) != world.cognition_state["chemistry"]:
		_scenario_failures.append("invalid version-3 biochemistry did not use the safe seeded fallback")
	print("INVALID VERSION-3 FALLBACK: fresh=%s; status=%s" % [invalid_fallback_is_fresh, world.last_status])

	var malformed_file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if malformed_file != null:
		malformed_file.store_string("{ malformed json")
		malformed_file.close()
	world.load_game()
	print("MALFORMED SAVE: episodes=%d; seed=%d; status=%s" % [world.cognition_state["episodes"].size(), int(world.cognition_state["seed"]), world.last_status])

	var restore_text := previous_save if previous_save_exists else valid_saved_text
	if not restore_text.is_empty():
		var restore_file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if restore_file != null:
			restore_file.store_string(restore_text)
			restore_file.close()
	print("SAVE RESTORED AFTER SCENARIO: %s" % (previous_save_exists or not valid_saved_text.is_empty()))
	if _scenario_failures.is_empty():
		print("HABITAT_SCENARIO_OK")
		quit(0)
		return
	for failure: String in _scenario_failures:
		push_error("HABITAT_SCENARIO_FAILED: " + failure)
	quit(1)


func _wait_for_status(world: AlbiaWorld, text: String, max_frames: int) -> bool:
	for frame in range(max_frames):
		if world.last_status.contains(text):
			return true
		await physics_frame
		await process_frame
	return world.last_status.contains(text)


func _write_saved_record(record: Dictionary) -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(record, "\t"))
	file.close()
	return true


func _founder_defaults_are_valid(world: AlbiaWorld) -> bool:
	if not world.has_method("ordered_profile_ids"):
		return false
	var ordered_ids: Variant = world.call("ordered_profile_ids")
	var egg_values: Variant = world.get("eggs")
	if world.norn_profiles.size() != 2 or not (ordered_ids is Array) or not (ordered_ids as Array).has("mallow") or not (ordered_ids as Array).has("moss"):
		return false
	for actor_id: String in ["mallow", "moss"]:
		var profile: NornProfile = world.profile_for(actor_id)
		if profile == null:
			return false
		var parents_value: Variant = profile.get("parent_ids")
		var life_value: Variant = profile.get("life_state")
		if int(profile.get("generation")) != 0 or not (parents_value is Array) or not (parents_value as Array).is_empty() or not (life_value is Dictionary):
			return false
		var expected_age := 600.0
		var expected_lifespan: Dictionary = NornLifecycle.create_state(int(profile.cognition_state.get("seed", -1)), expected_age)
		var profile_life: Dictionary = life_value
		if not is_equal_approx(float(profile_life.get("ageSeconds", -1.0)), expected_age) or not is_equal_approx(float(profile_life.get("lifespanSeconds", -1.0)), float(expected_lifespan.get("lifespanSeconds", -2.0))):
			return false
	return int(world.get("next_norn_number")) == 1 and egg_values is Array and (egg_values as Array).is_empty()


func _make_test_child_record(template: Dictionary, actor_id: String, parent_ids: Array[String]) -> Dictionary:
	var child: Dictionary = template.duplicate(true)
	child["actorId"] = actor_id
	child["displayName"] = "Child %s" % actor_id
	child["generation"] = 1
	child["parentIds"] = parent_ids.duplicate()
	child["bodyColor"] = [0.5, 0.4, 0.3, 1.0]
	return child


func _make_malformed_v5_records(valid_record: Dictionary) -> Array[Dictionary]:
	var malformed: Array[Dictionary] = []
	var candidate := valid_record.duplicate(true)
	candidate["norns"]["moss"]["actorId"] = "mallow"
	malformed.append(candidate)

	candidate = valid_record.duplicate(true)
	candidate["norns"]["norn-1"] = _make_test_child_record(candidate["norns"]["mallow"], "norn-1", ["mallow", "missing-parent"])
	candidate["nextNornNumber"] = 2
	malformed.append(candidate)

	candidate = valid_record.duplicate(true)
	var life_state: Dictionary = candidate["norns"]["mallow"].get("lifeState", {})
	life_state["ageSeconds"] = -1.0
	candidate["norns"]["mallow"]["lifeState"] = life_state
	malformed.append(candidate)

	candidate = valid_record.duplicate(true)
	life_state = candidate["norns"]["mallow"].get("lifeState", {})
	life_state["lifespanSeconds"] = NornLifecycle.MIN_LIFESPAN_SECONDS - 1.0
	candidate["norns"]["mallow"]["lifeState"] = life_state
	malformed.append(candidate)

	candidate = valid_record.duplicate(true)
	life_state = candidate["norns"]["mallow"].get("lifeState", {})
	life_state["death"] = {"cause": "old-age", "ageSeconds": 3342.0, "simulationTime": 1.0}
	candidate["norns"]["mallow"]["lifeState"] = life_state
	malformed.append(candidate)

	candidate = valid_record.duplicate(true)
	life_state = candidate["norns"]["mallow"].get("lifeState", {})
	life_state["alive"] = false
	life_state["death"] = {"cause": "starvation", "ageSeconds": 600.0, "simulationTime": 1.0}
	candidate["norns"]["mallow"]["lifeState"] = life_state
	malformed.append(candidate)

	candidate = valid_record.duplicate(true)
	candidate["focusedNornId"] = "missing"
	malformed.append(candidate)

	candidate = valid_record.duplicate(true)
	candidate["norns"]["norn-1"] = _make_test_child_record(candidate["norns"]["mallow"], "norn-1", ["mallow", "moss"])
	candidate["nextNornNumber"] = 1
	malformed.append(candidate)

	candidate = valid_record.duplicate(true)
	for child_number in range(1, 4):
		var child_id := "norn-%d" % child_number
		candidate["norns"][child_id] = _make_test_child_record(candidate["norns"]["mallow"], child_id, ["mallow", "moss"])
	candidate["nextNornNumber"] = 4
	malformed.append(candidate)
	return malformed


func _number_maps_equal(actual: Dictionary, expected: Dictionary, keys: Array[String]) -> bool:
	if actual.size() != keys.size() or expected.size() != keys.size():
		return false
	for key: String in keys:
		if not actual.has(key) or not expected.has(key):
			return false
		if not is_equal_approx(float(actual[key]), float(expected[key])):
			return false
	return true


func _number_arrays_equal(actual: Variant, expected: Array) -> bool:
	if not (actual is Array) or actual.size() != expected.size():
		return false
	for index in range(expected.size()):
		if not is_equal_approx(float(actual[index]), float(expected[index])):
			return false
	return true


func _verify_world_biochemistry(world: AlbiaWorld) -> bool:
	var has_state := false
	for property: Dictionary in world.get_property_list():
		if str(property.get("name", "")) == "biochemistry_state":
			has_state = true
			break
	if not has_state or not world.has_method("_apply_biochemistry_event"):
		push_error("WORLD_BIOCHEMISTRY_MISSING: AlbiaWorld must own biochemical state and route events through it")
		return false
	world.set_process(false)
	world.norn.set_physics_process(false)
	var biochemistry: Dictionary = world.get("biochemistry_state")
	var cognition: Dictionary = world.get("cognition_state")
	if biochemistry.is_empty() or cognition.is_empty():
		push_error("WORLD_BIOCHEMISTRY_MISSING: seeded world state is empty")
		return false
	if cognition["chemistry"] != Biochemistry.read_signals(biochemistry):
		push_error("WORLD_BIOCHEMISTRY_SYNC_FAILED: initial cognition signals differ from compounds")
		return false

	var before_signals: Dictionary = Biochemistry.read_signals(biochemistry)
	var before_compounds: Dictionary = Biochemistry.read_compounds(biochemistry)
	if not _apply_and_check_event(world, "food", {"eventType": "food", "actionId": "fruit", "targetId": "fruit", "time": 1.0}, before_signals):
		return false
	var after_food: Dictionary = Biochemistry.read_compounds(world.get("biochemistry_state"))
	if after_food["starch"] <= before_compounds["starch"] or after_food["hunger"] != before_compounds["hunger"]:
		push_error("WORLD_FOOD_PATHWAY_FAILED: food must add starch without directly editing hunger")
		return false

	before_signals = Biochemistry.read_signals(world.get("biochemistry_state"))
	before_compounds = Biochemistry.read_compounds(world.get("biochemistry_state"))
	if not _apply_and_check_event(world, "toy", {"eventType": "toy", "actionId": "spinner", "targetId": "spinner", "time": 2.0}, before_signals):
		return false
	var after_toy: Dictionary = Biochemistry.read_compounds(world.get("biochemistry_state"))
	if after_toy["curiosity"] >= before_compounds["curiosity"]:
		push_error("WORLD_TOY_INPUT_FAILED: toy use must satisfy curiosity")
		return false

	before_signals = Biochemistry.read_signals(world.get("biochemistry_state"))
	before_compounds = Biochemistry.read_compounds(world.get("biochemistry_state"))
	if not _apply_and_check_event(world, "praise", {"eventType": "praise", "actionId": "fruit", "targetId": "fruit", "time": 3.0}, before_signals):
		return false
	var after_praise: Dictionary = Biochemistry.read_compounds(world.get("biochemistry_state"))
	if after_praise["reward"] <= before_compounds["reward"]:
		push_error("WORLD_PRAISE_INPUT_FAILED: Praise must increase reward")
		return false

	before_signals = Biochemistry.read_signals(world.get("biochemistry_state"))
	before_compounds = Biochemistry.read_compounds(world.get("biochemistry_state"))
	if not _apply_and_check_event(world, "scold", {"eventType": "scold", "actionId": "spinner", "targetId": "spinner", "time": 4.0}, before_signals):
		return false
	var after_scold: Dictionary = Biochemistry.read_compounds(world.get("biochemistry_state"))
	if after_scold["punishment"] <= before_compounds["punishment"]:
		push_error("WORLD_SCOLD_INPUT_FAILED: Scold must increase punishment")
		return false

	before_signals = Biochemistry.read_signals(world.get("biochemistry_state"))
	before_compounds = Biochemistry.read_compounds(world.get("biochemistry_state"))
	if not _apply_and_check_event(world, "teach-word", {"eventType": "teach-word", "targetId": "fruit", "time": 5.0}, before_signals):
		return false
	var after_teaching: Dictionary = Biochemistry.read_compounds(world.get("biochemistry_state"))
	if after_teaching["socialComfort"] <= before_compounds["socialComfort"]:
		push_error("WORLD_TEACHING_INPUT_FAILED: word teaching must affect social comfort")
		return false

	world.norn.is_walking = true
	world.norn.current_action = "fruit"
	world.set("_chemistry_accumulator", 0.0)
	world.set("_decision_accumulator", 0.0)
	before_compounds = Biochemistry.read_compounds(world.get("biochemistry_state"))
	world._process(0.1)
	var after_activity: Dictionary = Biochemistry.read_compounds(world.get("biochemistry_state"))
	if after_activity["ADP"] <= before_compounds["ADP"] or after_activity["fatigue"] <= before_compounds["fatigue"]:
		push_error("WORLD_ACTIVITY_STIMULUS_FAILED: walking must consume ATP and raise fatigue")
		return false

	world.norn.is_walking = false
	world.norn.current_action = "rest"
	var rest_compounds: Dictionary = Biochemistry.read_compounds(world.get("biochemistry_state"))
	rest_compounds["fatigue"] = 70.0
	biochemistry = world.get("biochemistry_state")
	biochemistry["compounds"] = rest_compounds
	world.set("biochemistry_state", biochemistry)
	world.set("_decision_accumulator", 0.0)
	for _tick in range(10):
		world.set("_chemistry_accumulator", 0.0)
		world.set("_decision_accumulator", 0.0)
		world._process(0.1)
	var after_rest: Dictionary = Biochemistry.read_compounds(world.get("biochemistry_state"))
	if after_rest["fatigue"] >= rest_compounds["fatigue"]:
		push_error("WORLD_REST_STIMULUS_FAILED: resting must recover fatigue")
		return false

	world.paused = true
	var paused_time: float = world.simulation_time
	var paused_compounds: Dictionary = Biochemistry.read_compounds(world.get("biochemistry_state"))
	world._process(0.3)
	if world.simulation_time != paused_time or Biochemistry.read_compounds(world.get("biochemistry_state")) != paused_compounds:
		push_error("WORLD_PAUSE_FAILED: paused chemistry and simulation time must hold")
		return false
	world.paused = false

	var before_long_step: Dictionary = Biochemistry.read_compounds(world.get("biochemistry_state"))
	var expected: Dictionary = world.get("biochemistry_state").duplicate(true)
	var mallow_profile = world.profile_for("mallow")
	var mallow_peers: Array = world.call("_sense_peers", mallow_profile)
	var nearby_peer_stimulus := 1.0 if not mallow_peers.is_empty() else 0.0
	print("WORLD_CATCHUP_PEER_INPUT: count=%d; nearbyPeer=%.1f" % [mallow_peers.size(), nearby_peer_stimulus])
	for _tick in range(5):
		Biochemistry.advance(expected, {"active": 0.0, "resting": 1.0, "nearbyPeer": nearby_peer_stimulus}, 0.1)
	var time_before_long_step: float = world.simulation_time
	world.set("_chemistry_accumulator", 0.0)
	world.set("_decision_accumulator", 0.0)
	world._process(5.0)
	if world.simulation_time - time_before_long_step > 0.500001:
		push_error("WORLD_CATCHUP_FAILED: long frame advanced beyond the 0.5-second cap")
		return false
	if Biochemistry.read_compounds(world.get("biochemistry_state")) != expected["compounds"]:
		push_error("WORLD_CATCHUP_FAILED: long frame did not perform exactly five chemistry steps")
		return false
	if before_long_step.is_empty():
		push_error("WORLD_CATCHUP_FAILED: missing pre-step state")
		return false

	world.norn.set_physics_process(true)
	world.set_process(true)
	world.reset_run()
	print("WORLD_BIOCHEMISTRY_CHECKS_OK events=5 activity=checked rest=checked pause=checked catchup=5")
	return true


func _apply_and_check_event(world: AlbiaWorld, event_id: String, outcome: Dictionary, expected_before: Dictionary) -> bool:
	world.call("_apply_biochemistry_event", event_id, outcome)
	var cognition: Dictionary = world.get("cognition_state")
	var biochemistry: Dictionary = world.get("biochemistry_state")
	var expected_after: Dictionary = Biochemistry.read_signals(biochemistry)
	if cognition["chemistry"] != expected_after:
		push_error("WORLD_EVENT_SYNC_FAILED: %s did not synchronize cognition" % event_id)
		return false
	var episodes: Array = cognition["episodes"]
	var episode: Dictionary = episodes.back()
	if episode.get("chemicalsBefore", {}) != expected_before or episode.get("chemicalsAfter", {}) != expected_after:
		push_error("WORLD_EVENT_EPISODE_FAILED: %s did not store biochemical snapshots" % event_id)
		return false
	return true
