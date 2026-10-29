class_name HabitatUi
extends CanvasLayer

const Biochemistry = preload("res://scripts/norn_biochemistry.gd")

var habitat: Node
var _focus_name_label: Label
var _focus_age_stage_label: Label
var _roster_container: HBoxContainer
var _roster_buttons: Dictionary = {}
var _roster_signature := ""
var _family_panel: PanelContainer
var _family_content: VBoxContainer
var _family_panel_toggle: Button
var _second_parent_selector: OptionButton
var _start_egg_button: Button
var _egg_progress_label: Label
var _family_population_label: Label
var _family_signature := ""
var _family_archive: PanelContainer
var _family_archive_content: VBoxContainer
var _family_archive_toggle: Button
var _family_archive_text: Label
var _extinction_panel: PanelContainer
var _empty_world_label: Label
var _start_new_run_button: Button
var _chemistry_label: Label
var _action_label: Label
var _recall_label: Label
var _language_label: Label
var _status_label: Label
var _fruit_button: Button
var _spinner_button: Button
var _praise_button: Button
var _scold_button: Button
var _teach_mode_button: Button
var _word_input: LineEdit
var _pause_button: Button
var _speed_button: Button
var _record_button: Button
var _recording_label: Label
var _biochemistry_button: Button
var _biochemistry_panel: PanelContainer
var _biochemistry_rows: VBoxContainer
var _reaction_fluxes_label: Label
var _biochemistry_values: Dictionary = {}


func setup(world: Node) -> void:
	habitat = world
	_build_ui()


func update_view(view: Dictionary) -> void:
	if _chemistry_label == null:
		return
	var display_name := str(view.get("displayName", ""))
	var actor_id := str(view.get("actorId", ""))
	var has_focus := not actor_id.is_empty()
	var chemistry: Dictionary = view.get("chemistry", {})
	var decision: Dictionary = view.get("decision", {})
	var recalled: Array = view.get("recalled", [])
	var language_state: Dictionary = view.get("languageState", {})
	var compounds: Dictionary = view.get("compounds", {})
	var reaction_fluxes: Dictionary = view.get("reactionFluxes", {})
	var teaching_mode := bool(view.get("teachingMode", false))
	var life_stage := str(view.get("lifeStage", "none"))
	if has_focus:
		_chemistry_label.text = "Needs   Hunger %3.0f    Curiosity %3.0f    Fatigue %3.0f\nBody   Glucose %3.0f    Reward %3.0f    Stress %3.0f" % [
			float(chemistry.get("hunger", 0.0)),
			float(chemistry.get("curiosity", 0.0)),
			float(chemistry.get("fatigue", 0.0)),
			float(chemistry.get("glucose", 0.0)),
			float(chemistry.get("reward", 0.0)),
			float(chemistry.get("stress", 0.0))
		]
		var action := str(decision.get("actionId", "idle")).replace("_", " ").capitalize()
		var reason := str(decision.get("reason", "Settling into the habitat"))
		_action_label.text = "%s is %s.\n%s" % [display_name, action.to_lower(), reason]
		var lines: PackedStringArray = []
		for episode: Dictionary in recalled:
			var text_value := str(episode.get("text", ""))
			if text_value.is_empty():
				text_value = str(episode.get("eventType", "experience")).capitalize()
			lines.append("• %s" % text_value)
		_recall_label.text = "%s's remembered moments\n%s" % [display_name, "\n".join(lines) if not lines.is_empty() else "• Nothing recalled yet"]
		_language_label.text = _format_language_words(language_state)
		_focus_name_label.text = "Focused: %s" % display_name
		_focus_age_stage_label.text = "Age %s s   ·   %s" % [_format_age(float(view.get("ageSeconds", 0.0))), life_stage.capitalize()]
	else:
		_chemistry_label.text = "No living Norn needs to monitor."
		_focus_name_label.text = "No living Norns"
		_focus_age_stage_label.text = "Age —   ·   Stage —"
		var empty_message := "A family egg is still incubating." if bool(view.get("eggsOnly", false)) else "The lineage has ended. Begin a new run when you are ready."
		_action_label.text = empty_message
		_recall_label.text = "Family history\nThe deceased archive is below."
		_language_label.text = "No living Norn to teach."
	_update_roster(view.get("roster", []), actor_id)
	_update_family_ui(view)
	_status_label.text = str(view.get("status", ""))
	_fruit_button.text = "Teach fruit" if teaching_mode else "Guide to fruit"
	_spinner_button.text = "Teach spinner" if teaching_mode else "Guide to spinner"
	_praise_button.text = "Teach Praise" if teaching_mode else "Praise"
	_scold_button.text = "Teach Scold" if teaching_mode else "Scold"
	var feedback_ready := bool(view.get("feedbackReady", false))
	_fruit_button.disabled = not has_focus
	_spinner_button.disabled = not has_focus
	_praise_button.disabled = not has_focus or (not feedback_ready and not teaching_mode)
	_scold_button.disabled = not has_focus or (not feedback_ready and not teaching_mode)
	_teach_mode_button.text = "Cancel teaching" if teaching_mode else "Teach word"
	_teach_mode_button.disabled = not has_focus
	_word_input.editable = has_focus
	_biochemistry_button.text = "Hide biochemistry" if _biochemistry_panel.visible else "Biochemistry"
	var paused := bool(view.get("paused", false))
	var speed := float(view.get("speed", 1.0))
	var recording := bool(view.get("recording", false))
	var recording_elapsed := float(view.get("recordingElapsed", 0.0))
	var last_recording_path := str(view.get("lastRecordingPath", ""))
	var recording_error := str(view.get("recordingError", ""))
	var recorded_frame_count := int(view.get("recordedFrameCount", 0))
	_pause_button.text = "Resume" if paused else "Pause"
	_speed_button.text = "Speed %.1f×" % speed
	_record_button.text = "Stop recording" if recording else "Record video"
	if not recording_error.is_empty():
		_recording_label.text = "Recorder note: %s" % recording_error
	elif recording:
		_recording_label.text = "RECORDING  %s  ·  15 FPS" % _format_duration(recording_elapsed)
	elif not last_recording_path.is_empty():
		_recording_label.text = "Saved %d frames · %s" % [recorded_frame_count, last_recording_path]
	else:
		_recording_label.text = "Local AVI · 720p at 15 FPS · Keep 10 clips"
	_update_biochemistry(compounds, reaction_fluxes)


func _update_roster(roster_value: Variant, focused_actor_id: String) -> void:
	if _roster_container == null:
		return
	var roster: Array = roster_value if roster_value is Array else []
	var signature_parts := PackedStringArray()
	for entry_value: Variant in roster:
		if entry_value is Dictionary:
			var entry: Dictionary = entry_value
			signature_parts.append("%s:%s:%s" % [str(entry.get("actorId", "")), str(entry.get("displayName", "")), str(entry.get("lifeStage", ""))])
	var signature := "|".join(signature_parts)
	if signature != _roster_signature:
		for child: Node in _roster_container.get_children():
			child.free()
		_roster_buttons.clear()
		for entry_value: Variant in roster:
			if not (entry_value is Dictionary):
				continue
			var entry: Dictionary = entry_value
			var actor_id := str(entry.get("actorId", ""))
			if actor_id.is_empty():
				continue
			var button := Button.new()
			button.name = "Roster_" + actor_id
			button.text = str(entry.get("displayName", actor_id))
			button.tooltip_text = "Generation %d · %s · age %.0f seconds" % [int(entry.get("generation", 0)), str(entry.get("lifeStage", "")).capitalize(), float(entry.get("ageSeconds", 0.0))]
			button.toggle_mode = true
			button.custom_minimum_size = Vector2(108.0, 28.0)
			button.focus_mode = Control.FOCUS_ALL
			button.pressed.connect(func() -> void: habitat.call("select_norn", actor_id))
			_roster_container.add_child(button)
			_roster_buttons[actor_id] = button
		_roster_signature = signature
	for actor_id: String in _roster_buttons.keys():
		var button := _roster_buttons[actor_id] as Button
		if button != null:
			button.set_pressed_no_signal(actor_id == focused_actor_id)


func _update_family_ui(view: Dictionary) -> void:
	var roster_value: Variant = view.get("roster", [])
	var roster: Array = roster_value if roster_value is Array else []
	var focused_actor_id := str(view.get("actorId", ""))
	var parent_parts := PackedStringArray([focused_actor_id])
	var adult_candidates: Array[Dictionary] = []
	for entry_value: Variant in roster:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var actor_id := str(entry.get("actorId", ""))
		var stage := str(entry.get("lifeStage", ""))
		parent_parts.append("%s:%s:%s" % [actor_id, str(entry.get("displayName", "")), stage])
		if actor_id != focused_actor_id and ["adult", "elder"].has(stage):
			adult_candidates.append(entry)
	var family_signature := "|".join(parent_parts)
	if family_signature != _family_signature:
		_second_parent_selector.clear()
		for entry: Dictionary in adult_candidates:
			var item_index := _second_parent_selector.item_count
			_second_parent_selector.add_item("%s · %s" % [str(entry.get("displayName", "Norn")), str(entry.get("lifeStage", "")).capitalize()])
			_second_parent_selector.set_item_metadata(item_index, str(entry.get("actorId", "")))
		_family_signature = family_signature
	var population_count := int(view.get("populationCount", 0))
	var has_second_parent := _second_parent_selector.item_count > 0
	_start_egg_button.disabled = focused_actor_id.is_empty() or not has_second_parent or population_count >= 4
	_second_parent_selector.disabled = not has_second_parent or population_count >= 4
	_family_population_label.text = "Living Norns + eggs: %d / 4" % population_count
	var egg_records_value: Variant = view.get("eggRecords", [])
	var egg_records: Array = egg_records_value if egg_records_value is Array else []
	var egg_lines := PackedStringArray()
	for egg_value: Variant in egg_records:
		if not (egg_value is Dictionary):
			continue
		var egg: Dictionary = egg_value
		var remaining := clampf(float(egg.get("remainingSeconds", 0.0)), 0.0, 45.0)
		var percent := 100.0 * (1.0 - remaining / 45.0)
		egg_lines.append("%s  ·  %d%%  ·  %.1f s" % [str(egg.get("displayName", "Egg")), roundi(percent), remaining])
	_egg_progress_label.text = "Egg incubation\n%s" % ("\n".join(egg_lines) if not egg_lines.is_empty() else "No family eggs")
	var archived_value: Variant = view.get("archivedNorns", [])
	var archived: Array = archived_value if archived_value is Array else []
	_family_archive.visible = not archived.is_empty()
	var known_names: Dictionary = {}
	for family_member_value: Variant in roster + archived:
		if family_member_value is Dictionary:
			var family_member: Dictionary = family_member_value
			known_names[str(family_member.get("actorId", ""))] = str(family_member.get("displayName", "Norn"))
	var archive_lines := PackedStringArray()
	for archived_value_item: Variant in archived:
		if not (archived_value_item is Dictionary):
			continue
		var archived_norn: Dictionary = archived_value_item
		var parents: Array = archived_norn.get("parentIds", [])
		var parent_names := PackedStringArray()
		for parent_id: Variant in parents:
			parent_names.append(str(known_names.get(str(parent_id), str(parent_id))))
		var ancestry := "" if parents.is_empty() else " · parents %s" % ", ".join(parent_names)
		archive_lines.append("%s · Generation %d · %s at age %.0f s%s" % [
			str(archived_norn.get("displayName", "Norn")),
			int(archived_norn.get("generation", 0)),
			str(archived_norn.get("cause", "old-age")).replace("-", " "),
			float(archived_norn.get("ageSeconds", 0.0)),
			ancestry
		])
	_family_archive_text.text = "\n".join(archive_lines) if not archive_lines.is_empty() else "No deceased family members."
	var eggs_only := bool(view.get("eggsOnly", false))
	var extinct := bool(view.get("extinct", false))
	_empty_world_label.visible = eggs_only
	_extinction_panel.visible = extinct
	_start_new_run_button.visible = extinct


func _on_start_egg_pressed() -> void:
	if _second_parent_selector == null or _second_parent_selector.selected < 0:
		return
	var parent_id := str(_second_parent_selector.get_item_metadata(_second_parent_selector.selected))
	if not parent_id.is_empty():
		habitat.call("start_egg", parent_id)


func _toggle_family_content() -> void:
	if _family_content == null:
		return
	_family_content.visible = not _family_content.visible
	_family_panel_toggle.text = "Family and eggs  %s" % ("▾" if _family_content.visible else "▸")


func _toggle_archive_content() -> void:
	if _family_archive_content == null:
		return
	_family_archive_content.visible = not _family_archive_content.visible
	_family_archive_toggle.text = "Deceased family  %s" % ("▾" if _family_archive_content.visible else "▸")


func _format_age(seconds: float) -> String:
	return "%.1f" % maxf(0.0, seconds)


func _build_ui() -> void:
	var root := Control.new()
	root.name = "HabitatHUD"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var panel := PanelContainer.new()
	panel.position = Vector2(16.0, 10.0)
	panel.size = Vector2(380.0, 700.0)
	panel.custom_minimum_size = Vector2(380.0, 700.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.085, 0.075, 0.94)
	style.border_color = Color(0.63, 0.68, 0.46, 0.85)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(12.0)
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.name = "HUDScrollContainer"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var layout := VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 5)
	scroll.add_child(layout)
	var title := Label.new()
	title.text = "NEW ALBIA  ·  SUNMEADOW"
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color(0.96, 0.84, 0.57))
	layout.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Two local, learning Norns"
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.77, 0.86, 0.76))
	layout.add_child(subtitle)
	var focus_row := HBoxContainer.new()
	focus_row.name = "FocusRow"
	focus_row.add_theme_constant_override("separation", 5)
	layout.add_child(focus_row)
	_focus_name_label = Label.new()
	_focus_name_label.name = "FocusNameLabel"
	_focus_name_label.text = "Focused: Mallow"
	_focus_name_label.add_theme_font_size_override("font_size", 12)
	_focus_name_label.add_theme_color_override("font_color", Color(0.96, 0.84, 0.57))
	_focus_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_row.add_child(_focus_name_label)
	_roster_container = HBoxContainer.new()
	_roster_container.name = "NornRoster"
	_roster_container.add_theme_constant_override("separation", 6)
	layout.add_child(_roster_container)
	_focus_age_stage_label = Label.new()
	_focus_age_stage_label.name = "FocusAgeStageLabel"
	_focus_age_stage_label.add_theme_font_size_override("font_size", 13)
	_focus_age_stage_label.add_theme_color_override("font_color", Color(0.77, 0.86, 0.76))
	layout.add_child(_focus_age_stage_label)
	_build_extinction_panel(layout)
	_empty_world_label = Label.new()
	_empty_world_label.name = "EggsOnlyLabel"
	_empty_world_label.text = "No living Norns · family incubation continues"
	_empty_world_label.visible = false
	_empty_world_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_world_label.add_theme_font_size_override("font_size", 13)
	_empty_world_label.add_theme_color_override("font_color", Color(0.96, 0.84, 0.57))
	layout.add_child(_empty_world_label)
	_build_family_panel(layout)
	_build_family_archive(layout)
	_chemistry_label = Label.new()
	_chemistry_label.add_theme_font_size_override("font_size", 14)
	_chemistry_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.86))
	layout.add_child(_chemistry_label)
	_biochemistry_button = _add_button(layout, "Biochemistry", _toggle_biochemistry_view)
	_biochemistry_button.name = "BiochemistryButton"
	_biochemistry_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_action_label = Label.new()
	_action_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_action_label.custom_minimum_size.y = 40.0
	_action_label.add_theme_font_size_override("font_size", 15)
	_action_label.add_theme_color_override("font_color", Color(0.87, 0.93, 0.76))
	layout.add_child(_action_label)
	_recall_label = Label.new()
	_recall_label.name = "RememberedMomentsLabel"
	_recall_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_recall_label.custom_minimum_size.y = 58.0
	_recall_label.add_theme_font_size_override("font_size", 14)
	_recall_label.add_theme_color_override("font_color", Color(0.84, 0.85, 0.75))
	layout.add_child(_recall_label)
	_language_label = Label.new()
	_language_label.name = "LearnedWordsLabel"
	_language_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_language_label.custom_minimum_size.y = 20.0
	_language_label.add_theme_font_size_override("font_size", 12)
	_language_label.add_theme_color_override("font_color", Color(0.77, 0.86, 0.76))
	layout.add_child(_language_label)
	var teaching_row := HBoxContainer.new()
	teaching_row.add_theme_constant_override("separation", 6)
	layout.add_child(teaching_row)
	var word_label := Label.new()
	word_label.text = "Word"
	word_label.add_theme_font_size_override("font_size", 14)
	teaching_row.add_child(word_label)
	_word_input = LineEdit.new()
	_word_input.name = "TeachWordInput"
	_word_input.placeholder_text = "Type one word"
	_word_input.max_length = 24
	_word_input.focus_mode = Control.FOCUS_ALL
	_word_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_word_input.tooltip_text = "Choose Teach word, type one word of up to 24 characters, then choose its meaning."
	_word_input.text_submitted.connect(_on_word_submitted)
	teaching_row.add_child(_word_input)
	_teach_mode_button = _add_button(teaching_row, "Teach word", func() -> void: habitat.call("toggle_teaching_mode"))
	_teach_mode_button.name = "TeachModeButton"
	_teach_mode_button.custom_minimum_size = Vector2(116.0, 32.0)
	var divider := HSeparator.new()
	layout.add_child(divider)
	var controls_title := Label.new()
	controls_title.text = "Guide and respond"
	controls_title.add_theme_font_size_override("font_size", 16)
	controls_title.add_theme_color_override("font_color", Color(0.96, 0.84, 0.57))
	layout.add_child(controls_title)
	var controls := GridContainer.new()
	controls.columns = 2
	controls.add_theme_constant_override("h_separation", 8)
	controls.add_theme_constant_override("v_separation", 6)
	layout.add_child(controls)
	_fruit_button = _add_button(controls, "Guide to fruit", func() -> void: habitat.call("select_hud_target", "fruit", _word_input.text))
	_spinner_button = _add_button(controls, "Guide to spinner", func() -> void: habitat.call("select_hud_target", "spinner", _word_input.text))
	_praise_button = _add_button(controls, "Praise", func() -> void: habitat.call("select_hud_target", "praise", _word_input.text))
	_scold_button = _add_button(controls, "Scold", func() -> void: habitat.call("select_hud_target", "scold", _word_input.text))
	_pause_button = _add_button(controls, "Pause", func() -> void: habitat.call("toggle_pause"))
	_speed_button = _add_button(controls, "Speed 1.0×", func() -> void: habitat.call("cycle_speed"))
	_add_button(controls, "Save", func() -> void: habitat.call("save_game"))
	_add_button(controls, "Load", func() -> void: habitat.call("load_game"))
	_add_button(controls, "Reset", func() -> void: habitat.call("reset_run"))
	_record_button = _add_button(controls, "Record video", func() -> void: habitat.call("toggle_recording"))
	_add_button(controls, "Open recordings", func() -> void: habitat.call("open_recordings_folder"))
	_recording_label = Label.new()
	_recording_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_recording_label.custom_minimum_size.y = 28.0
	_recording_label.add_theme_font_size_override("font_size", 12)
	_recording_label.add_theme_color_override("font_color", Color(0.94, 0.53, 0.42))
	layout.add_child(_recording_label)
	var instruction := Label.new()
	instruction.text = "Camera: WASD / arrows · Zoom: mouse wheel · Space: pause"
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction.add_theme_font_size_override("font_size", 12)
	instruction.add_theme_color_override("font_color", Color(0.68, 0.76, 0.7))
	layout.add_child(instruction)
	_status_label = Label.new()
	_status_label.custom_minimum_size.y = 34.0
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.add_theme_color_override("font_color", Color(0.96, 0.85, 0.6))
	layout.add_child(_status_label)
	_build_biochemistry_panel(root)


func _build_family_panel(layout: VBoxContainer) -> void:
	_family_panel = PanelContainer.new()
	_family_panel.name = "FamilyPanel"
	_family_panel.add_theme_stylebox_override("panel", _family_panel_style())
	layout.add_child(_family_panel)
	var family_layout := VBoxContainer.new()
	family_layout.add_theme_constant_override("separation", 3)
	_family_panel.add_child(family_layout)
	_family_panel_toggle = _add_button(family_layout, "Family and eggs  ▾", _toggle_family_content)
	_family_panel_toggle.name = "FamilyPanelToggle"
	_family_panel_toggle.custom_minimum_size.y = 26.0
	_family_content = VBoxContainer.new()
	_family_content.name = "FamilyPanelContent"
	_family_content.add_theme_constant_override("separation", 3)
	family_layout.add_child(_family_content)
	var second_parent_label := Label.new()
	second_parent_label.text = "Second parent · living adults and elders"
	second_parent_label.add_theme_font_size_override("font_size", 12)
	second_parent_label.add_theme_color_override("font_color", Color(0.77, 0.86, 0.76))
	_family_content.add_child(second_parent_label)
	_second_parent_selector = OptionButton.new()
	_second_parent_selector.name = "SecondParentSelector"
	_second_parent_selector.custom_minimum_size.y = 28.0
	_second_parent_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_family_content.add_child(_second_parent_selector)
	_start_egg_button = _add_button(_family_content, "Start family egg", _on_start_egg_pressed)
	_start_egg_button.name = "StartEggButton"
	_start_egg_button.custom_minimum_size.y = 30.0
	_family_population_label = Label.new()
	_family_population_label.name = "FamilyPopulationLabel"
	_family_population_label.add_theme_font_size_override("font_size", 11)
	_family_population_label.add_theme_color_override("font_color", Color(0.77, 0.86, 0.76))
	_family_content.add_child(_family_population_label)
	_egg_progress_label = Label.new()
	_egg_progress_label.name = "EggProgressLabel"
	_egg_progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_egg_progress_label.custom_minimum_size.y = 28.0
	_egg_progress_label.add_theme_font_size_override("font_size", 12)
	_egg_progress_label.add_theme_color_override("font_color", Color(0.96, 0.84, 0.57))
	_family_content.add_child(_egg_progress_label)


func _build_family_archive(layout: VBoxContainer) -> void:
	_family_archive = PanelContainer.new()
	_family_archive.name = "FamilyArchive"
	_family_archive.visible = false
	_family_archive.add_theme_stylebox_override("panel", _family_panel_style())
	layout.add_child(_family_archive)
	var archive_layout := VBoxContainer.new()
	archive_layout.add_theme_constant_override("separation", 3)
	_family_archive.add_child(archive_layout)
	_family_archive_toggle = _add_button(archive_layout, "Deceased family  ▾", _toggle_archive_content)
	_family_archive_toggle.name = "FamilyArchiveToggle"
	_family_archive_toggle.custom_minimum_size.y = 26.0
	_family_archive_content = VBoxContainer.new()
	_family_archive_content.name = "FamilyArchiveContent"
	archive_layout.add_child(_family_archive_content)
	_family_archive_text = Label.new()
	_family_archive_text.name = "FamilyArchiveText"
	_family_archive_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_family_archive_text.add_theme_font_size_override("font_size", 12)
	_family_archive_text.add_theme_color_override("font_color", Color(0.84, 0.89, 0.78))
	_family_archive_content.add_child(_family_archive_text)


func _build_extinction_panel(layout: VBoxContainer) -> void:
	_extinction_panel = PanelContainer.new()
	_extinction_panel.name = "ExtinctionPanel"
	_extinction_panel.visible = false
	_extinction_panel.add_theme_stylebox_override("panel", _family_panel_style())
	layout.add_child(_extinction_panel)
	var extinction_layout := VBoxContainer.new()
	extinction_layout.add_theme_constant_override("separation", 3)
	_extinction_panel.add_child(extinction_layout)
	var extinction_label := Label.new()
	extinction_label.text = "No living Norns or eggs remain. The family archive is preserved below."
	extinction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	extinction_label.add_theme_font_size_override("font_size", 12)
	extinction_label.add_theme_color_override("font_color", Color(0.96, 0.84, 0.57))
	extinction_layout.add_child(extinction_label)
	_start_new_run_button = _add_button(extinction_layout, "Start new run", func() -> void: habitat.call("reset_run"))
	_start_new_run_button.name = "StartNewRunButton"


func _family_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.16, 0.13, 0.84)
	style.border_color = Color(0.45, 0.54, 0.37, 0.72)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.set_content_margin_all(6.0)
	return style


func _build_biochemistry_panel(root: Control) -> void:
	_biochemistry_panel = PanelContainer.new()
	_biochemistry_panel.name = "BiochemistryPanel"
	_biochemistry_panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_biochemistry_panel.offset_left = -356.0
	_biochemistry_panel.offset_top = 60.0
	_biochemistry_panel.offset_right = -16.0
	_biochemistry_panel.offset_bottom = -60.0
	_biochemistry_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.085, 0.075, 0.96)
	style.border_color = Color(0.63, 0.68, 0.46, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(12.0)
	_biochemistry_panel.add_theme_stylebox_override("panel", style)
	root.add_child(_biochemistry_panel)

	var panel_layout := VBoxContainer.new()
	panel_layout.add_theme_constant_override("separation", 6)
	_biochemistry_panel.add_child(panel_layout)
	var title := Label.new()
	title.text = "BIOCHEMISTRY  ·  LIVE"
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(0.96, 0.84, 0.57))
	panel_layout.add_child(title)
	var hint := Label.new()
	hint.text = "Compound concentrations · scale 0–100"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.77, 0.86, 0.76))
	panel_layout.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.name = "BiochemistryCompoundScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_layout.add_child(scroll)
	_biochemistry_rows = VBoxContainer.new()
	_biochemistry_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_biochemistry_rows.add_theme_constant_override("separation", 1)
	scroll.add_child(_biochemistry_rows)
	for compound_id: String in Biochemistry.COMPOUND_IDS:
		var row := Label.new()
		row.name = "BiochemistryCompound_" + compound_id
		row.add_theme_font_size_override("font_size", 13)
		row.add_theme_color_override("font_color", Color(0.91, 0.94, 0.85))
		_biochemistry_rows.add_child(row)
		_biochemistry_values[compound_id] = row

	var flux_heading := Label.new()
	flux_heading.text = "Latest reaction fluxes"
	flux_heading.add_theme_font_size_override("font_size", 14)
	flux_heading.add_theme_color_override("font_color", Color(0.96, 0.84, 0.57))
	panel_layout.add_child(flux_heading)
	_reaction_fluxes_label = Label.new()
	_reaction_fluxes_label.name = "ReactionFluxesLabel"
	_reaction_fluxes_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reaction_fluxes_label.custom_minimum_size.y = 104.0
	_reaction_fluxes_label.add_theme_font_size_override("font_size", 12)
	_reaction_fluxes_label.add_theme_color_override("font_color", Color(0.84, 0.89, 0.78))
	panel_layout.add_child(_reaction_fluxes_label)
	_update_biochemistry(Biochemistry.INITIAL_COMPOUNDS, {})


func _toggle_biochemistry_view() -> void:
	if _biochemistry_panel == null:
		return
	_biochemistry_panel.visible = not _biochemistry_panel.visible
	_biochemistry_button.text = "Hide biochemistry" if _biochemistry_panel.visible else "Biochemistry"


func _update_biochemistry(compounds: Dictionary, reaction_fluxes: Dictionary) -> void:
	if _biochemistry_rows == null or _reaction_fluxes_label == null:
		return
	for compound_id: String in Biochemistry.COMPOUND_IDS:
		var row := _biochemistry_values.get(compound_id) as Label
		if row == null:
			continue
		row.text = "%s  %5.1f / 100" % [compound_id, float(compounds.get(compound_id, 0.0))]
	var flux_ids: Array = reaction_fluxes.keys()
	var fluxes: Array[Dictionary] = []
	for flux_id: String in flux_ids:
		var flux := float(reaction_fluxes[flux_id])
		if flux > 0.0:
			fluxes.append({"id": flux_id, "value": flux})
	fluxes.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if not is_equal_approx(float(left["value"]), float(right["value"])):
			return float(left["value"]) > float(right["value"])
		return str(left["id"]) < str(right["id"])
	)
	var flux_summaries := PackedStringArray()
	for index in range(mini(fluxes.size(), 6)):
		var flux: Dictionary = fluxes[index]
		flux_summaries.append("%s  %.3f" % [str(flux["id"]), float(flux["value"])])
	_reaction_fluxes_label.text = "\n".join(flux_summaries) if not flux_summaries.is_empty() else "No reaction flux this step"


func clear_teaching_input() -> void:
	if _word_input != null:
		_word_input.clear()


func _format_language_words(language_state: Dictionary) -> String:
	var words: Dictionary = language_state.get("words", {})
	if words.is_empty():
		return "Words learned: none"
	var keys: Array = words.keys()
	keys.sort()
	var summaries: PackedStringArray = []
	for index in range(mini(keys.size(), 4)):
		var entry: Dictionary = words[keys[index]]
		summaries.append("%s → %s %.2f" % [
			str(entry.get("word", keys[index])),
			_target_display_name(str(entry.get("targetId", ""))),
			float(entry.get("confidence", 0.0))
		])
	if keys.size() > 4:
		summaries.append("+%d more" % (keys.size() - 4))
	return "Words: " + " · ".join(summaries)


func _target_display_name(target_id: String) -> String:
	match target_id:
		"fruit":
			return "fruit"
		"spinner":
			return "spinner"
		"praise":
			return "Praise"
		"scold":
			return "Scold"
	return "unknown"


func _on_word_submitted(_word: String) -> void:
	if not bool(habitat.get("teaching_mode")):
		habitat.call("toggle_teaching_mode")


func _format_duration(seconds: float) -> String:
	var whole_seconds := maxi(0, int(seconds))
	return "%02d:%02d" % [floori(float(whole_seconds) / 60.0), whole_seconds % 60]


func _add_button(parent: Container, title: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(168.0, 30.0)
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
