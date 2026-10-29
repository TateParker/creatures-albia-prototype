extends SceneTree

const HabitatScene = preload("res://scenes/main.tscn")
const Biochemistry = preload("res://scripts/norn_biochemistry.gd")
const Cognition = preload("res://scripts/norn_cognition.gd")
const SAVE_PATH := "user://albia_norn_save.json"

var _world: Node
var _previous_save_exists := false
var _previous_save_text := ""
var _save_backup_ready := false


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
	for frame in range(12):
		await process_frame
	if not _press_hud_button("Guide to fruit"):
		return
	var reached_fruit: bool = await _wait_for_status("ate honey fruit", 360)
	if not reached_fruit:
		_fail("Mallow did not reach the guided fruit during the recording: %s" % str(_world.get("last_status")))
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
	var reached_spinner: bool = await _wait_for_status("played with the spinner", 600)
	if not reached_spinner:
		_fail("Mallow did not reach the guided spinner during the recording.")
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
	if not _press_hud_button("Save"):
		return
	cognition["actionAssociations"]["fruit"] = 0.99
	var words_before_reload: Dictionary = language_state["words"]
	words_before_reload["apple"]["confidence"] = 0.01
	words_before_reload.erase("toy")
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

	if not _verify_legacy_save_migration(fruit_association_before_save):
		return
	_restore_user_save()
	print("VIDEO_CAPTURE_OK frames=%d path=%s flow=teach-fruit-food-spinner-activity-praise-scold-rest-inspector-pause-save-load-legacy" % [frame_count, video_path])
	quit()


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
	associations["fruit"] = 0.0
	associations["spinner"] = 0.0
	cognition["actionAssociations"] = associations
	if not Cognition.sync_chemistry(cognition, Biochemistry.read_signals(biochemical_state)):
		_fail("Could not prepare the high-fatigue inspection scenario.")
		return false
	_world.set("cognition_state", cognition)
	_world.set("guidance", {})
	_world.call("_run_decision")
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
	for object_id: String in ["fruit", "spinner"]:
		var item := objects.get(object_id) as Node3D
		var screen_position := camera.unproject_position(item.global_position + Vector3.UP)
		if screen_position.x < panel_right + 32.0 or screen_position.x > visible_rect.size.x - 32.0:
			_fail("The %s is too close to the HUD or screen edge (x=%d, panel=%d)." % [object_id, int(screen_position.x), int(panel_right)])
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


func _verify_legacy_save_migration(expected_fruit_association: float) -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		_fail("The walkthrough did not leave a local save to check.")
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		_fail("The saved version-2 language record could not be read.")
		return false
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK or not (parser.data is Dictionary):
		_fail("The saved version-2 language record was not valid JSON.")
		return false
	var record: Dictionary = parser.data
	if int(record.get("version", -1)) != 3 or not (record.get("language", null) is Dictionary) or not (record.get("biochemistry", null) is Dictionary):
		_fail("Save did not write version-3 vocabulary and biochemical data.")
		return false
	var saved_biochemistry: Dictionary = record["biochemistry"]
	var saved_compounds: Dictionary = saved_biochemistry.get("compounds", {})
	var expected_compounds: Dictionary = Biochemistry.read_compounds(Biochemistry.restore_state(saved_biochemistry))
	if not _number_maps_match(saved_compounds, expected_compounds, Biochemistry.COMPOUND_IDS):
		_fail("The version-3 save did not contain all 18 compound concentrations.")
		return false
	var expected_signals: Dictionary = Biochemistry.read_signals(Biochemistry.restore_state(saved_biochemistry))
	var saved_cognition: Dictionary = record["cognition"]
	var saved_language: Dictionary = record["language"]
	var expected_word_count: int = saved_language["words"].size()
	var expected_association := float(saved_cognition["actionAssociations"]["fruit"])

	var version2_record: Dictionary = record.duplicate(true)
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
	if version2_words.size() != expected_word_count or not is_equal_approx(float(version2_cognition["actionAssociations"]["fruit"]), expected_association) or not _number_maps_match(version2_signals, expected_signals, Biochemistry.SIGNAL_IDS):
		_fail("Version-2 migration did not preserve learning, vocabulary, and cognition signals.")
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
	if not is_equal_approx(float(version1_cognition["actionAssociations"]["fruit"]), expected_fruit_association) or not _number_maps_match(version1_signals, expected_signals, Biochemistry.SIGNAL_IDS):
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
