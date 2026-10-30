extends SceneTree

const Biochemistry = preload("res://scripts/norn_biochemistry.gd")
const Cognition = preload("res://scripts/norn_cognition.gd")
const COMPOUND_IDS: Array[String] = [
	"glucose", "hunger", "curiosity", "fatigue", "reward", "punishment", "stress",
	"socialComfort", "arousal", "satiety", "starch", "glycogen", "pyruvate", "ATP",
	"ADP", "oxygen", "carbonDioxide", "water", "thirst"
]
const SIGNAL_IDS: Array[String] = [
	"glucose", "hunger", "curiosity", "fatigue", "reward",
	"punishment", "stress", "socialComfort", "arousal", "satiety", "thirst"
]

var _failures: Array[String] = []


func _initialize() -> void:
	_verify_registry_and_legacy_signals()
	_verify_events()
	_verify_metabolic_pathway()
	_verify_activity_and_rest()
	_verify_signal_optimized_step_matches_snapshot_step()
	_verify_bounds_and_invalid_inputs()
	_verify_determinism_and_order()
	_verify_serialization_and_migration()
	_verify_cognition_bridge()
	if _failures.is_empty():
		print("BIOCHEMISTRY_CHECKS_OK")
		quit(0)
		return
	for failure: String in _failures:
		push_error("BIOCHEMISTRY_CHECK_FAILED: " + failure)
	quit(1)


func _verify_registry_and_legacy_signals() -> void:
	var legacy := {
		"glucose": 37.0,
		"hunger": 63.0,
		"curiosity": 42.0,
		"fatigue": 28.0,
		"reward": 7.0,
		"punishment": 2.0,
		"stress": 12.0,
		"socialComfort": 51.0,
		"arousal": 15.0,
		"satiety": 38.0
	}
	var state: Dictionary = Biochemistry.create_state(legacy)
	var compounds: Dictionary = Biochemistry.read_compounds(state)
	var actual_ids: Array = compounds.keys()
	var expected_ids: Array = COMPOUND_IDS.duplicate()
	actual_ids.sort()
	expected_ids.sort()
	_expect(actual_ids == expected_ids and actual_ids.size() == 19, "compound registry contains the 19 named compounds")
	_expect(state.get("version", -1) == 2, "new state uses biochemical version 2")
	var expected_signals: Dictionary = legacy.duplicate(true)
	expected_signals["thirst"] = 0.0
	_expect(Biochemistry.read_signals(state) == expected_signals, "legacy signals seed matching compounds and default thirst to zero")
	_expect(compounds["starch"] == 0.0 and compounds["glycogen"] == 25.0, "nutrient compounds use the authored defaults")
	_expect(compounds["ATP"] == 55.0 and compounds["oxygen"] == 100.0, "energy and oxygen compounds use the authored defaults")
	_expect(Biochemistry.read_signals(state).size() == SIGNAL_IDS.size() and SIGNAL_IDS.size() == 11, "cognition readout has the 11 named signals")


func _verify_events() -> void:
	var initial := {
		"glucose": 45.0,
		"hunger": 60.0,
		"curiosity": 70.0,
		"fatigue": 30.0,
		"reward": 0.0,
		"punishment": 0.0,
		"stress": 20.0,
		"socialComfort": 40.0,
		"arousal": 30.0,
		"satiety": 20.0
	}
	var state: Dictionary = Biochemistry.create_state(initial)
	var result: Dictionary = Biochemistry.apply_event(state, "food")
	_expect(bool(result.get("ok", false)), "food event is accepted")
	_expect(Biochemistry.read_compounds(state)["starch"] == 34.0, "food adds digestible starch")
	_expect(Biochemistry.read_compounds(state)["hunger"] == 60.0, "food does not directly erase hunger")
	_expect(Biochemistry.read_compounds(state)["reward"] == 8.0, "food produces its reward input")

	result = Biochemistry.apply_event(state, "toy")
	var compounds: Dictionary = Biochemistry.read_compounds(state)
	_expect(bool(result.get("ok", false)), "toy event is accepted")
	_expect(compounds["curiosity"] == 25.0 and compounds["arousal"] == 18.0, "toy satisfies curiosity and reduces arousal")
	_expect(compounds["reward"] == 16.0, "toy adds its reward input")
	Biochemistry.apply_event(state, "praise")
	compounds = Biochemistry.read_compounds(state)
	_expect(compounds["reward"] == 28.0 and compounds["stress"] == 14.0, "Praise adds reward and reduces stress")
	Biochemistry.apply_event(state, "scold")
	compounds = Biochemistry.read_compounds(state)
	_expect(compounds["punishment"] == 12.0 and compounds["stress"] == 22.0, "Scold adds punishment and stress")
	Biochemistry.apply_event(state, "teach-word")
	Biochemistry.apply_event(state, "social")
	_expect(Biochemistry.read_compounds(state)["socialComfort"] == 43.0, "teaching and social inputs increase social comfort")

	var before_unknown: Dictionary = Biochemistry.read_compounds(state)
	result = Biochemistry.apply_event(state, "unknown-event")
	_expect(result.is_empty(), "unknown event returns an empty result")
	_expect(Biochemistry.read_compounds(state) == before_unknown, "unknown event leaves state unchanged")


func _verify_metabolic_pathway() -> void:
	var initial := {"glucose": 15.0, "hunger": 65.0, "curiosity": 25.0, "fatigue": 15.0}
	var state: Dictionary = Biochemistry.create_state(initial)
	Biochemistry.apply_event(state, "food")
	var before: Dictionary = Biochemistry.read_compounds(state)
	for _tick in range(200):
		Biochemistry.advance(state, {}, 0.1)
	var after: Dictionary = Biochemistry.read_compounds(state)
	_expect(after["starch"] < before["starch"], "starch is digested over subsequent chemistry steps")
	_expect(after["glucose"] > before["glucose"], "digested food enters the glucose pathway")
	_expect(after["ATP"] > before["ATP"], "nutrient metabolism produces cellular energy")
	_expect(after["hunger"] < before["hunger"], "food reduces hunger over subsequent chemistry steps")
	_expect(Biochemistry.read_fluxes(state).size() > 0, "the latest step exposes reaction fluxes")


func _verify_activity_and_rest() -> void:
	var state: Dictionary = Biochemistry.create_state({"glucose": 70.0, "hunger": 30.0, "fatigue": 25.0})
	var before: Dictionary = Biochemistry.read_compounds(state)
	for _tick in range(20):
		Biochemistry.advance(state, {"active": 1.0}, 0.1)
	var active: Dictionary = Biochemistry.read_compounds(state)
	_expect(active["ADP"] > before["ADP"], "activity converts ATP into ADP")
	_expect(active["fatigue"] > before["fatigue"], "activity raises fatigue")

	state = Biochemistry.create_state({"glucose": 60.0, "hunger": 35.0, "fatigue": 70.0})
	var rest_before: Dictionary = Biochemistry.read_compounds(state)
	for _tick in range(30):
		Biochemistry.advance(state, {"resting": 1.0}, 0.1)
	var rested: Dictionary = Biochemistry.read_compounds(state)
	_expect(rested["fatigue"] < rest_before["fatigue"], "rest lowers fatigue")
	_expect(rested["ATP"] >= rest_before["ATP"], "rest supports energy recovery when fuel is available")


func _verify_signal_optimized_step_matches_snapshot_step() -> void:
	var snapshot_state: Dictionary = Biochemistry.create_state({"glucose": 42.0, "hunger": 57.0, "fatigue": 33.0})
	var signal_state: Dictionary = Biochemistry.create_state({"glucose": 42.0, "hunger": 57.0, "fatigue": 33.0})
	var stimuli := {"active": 0.65, "resting": 0.0, "nearbyPeer": 0.1}
	var snapshot: Dictionary = Biochemistry.advance(snapshot_state, stimuli, 0.1)
	var signals: Dictionary = Biochemistry.advance_and_read_signals(signal_state, stimuli, 0.1)
	_expect(signals == snapshot.get("signals", {}), "signal-only step returns the same cognition readout as the snapshot step")
	_expect(Biochemistry.read_compounds(signal_state) == Biochemistry.read_compounds(snapshot_state), "signal-only step preserves every compound result")
	_expect(Biochemistry.read_fluxes(signal_state) == Biochemistry.read_fluxes(snapshot_state), "signal-only step preserves every reaction flux")
	var before_invalid: Dictionary = Biochemistry.read_compounds(signal_state)
	_expect(Biochemistry.advance_and_read_signals(signal_state, stimuli, INF).is_empty(), "signal-only step rejects an invalid timestep")
	_expect(Biochemistry.read_compounds(signal_state) == before_invalid, "rejected signal-only step leaves its state unchanged")
	var invalid_state: Dictionary = signal_state.duplicate(true)
	invalid_state["compounds"] = null
	_expect(Biochemistry.advance_and_read_signals(invalid_state, stimuli, 0.1).is_empty(), "signal-only step safely rejects malformed state")
	var generic_state: Dictionary = Biochemistry.create_state({"glucose": 42.0, "hunger": 57.0, "fatigue": 33.0})
	var optimized_state: Dictionary = Biochemistry.create_state({"glucose": 42.0, "hunger": 57.0, "fatigue": 33.0})
	Biochemistry.apply_event(generic_state, "food")
	Biochemistry.apply_event(optimized_state, "food")
	var matches_generic_engine := true
	for tick in range(60):
		var step_stimuli := {"active": 1.0, "resting": 0.0, "nearbyPeer": 0.0}
		if tick % 3 == 1:
			step_stimuli = {"active": 0.0, "resting": 1.0, "nearbyPeer": 0.0}
		elif tick % 3 == 2:
			step_stimuli = {"active": 0.4, "resting": 0.0, "nearbyPeer": 0.7}
		var expected: Dictionary = Biochemistry._advance_reactions(
			Biochemistry.read_compounds(generic_state), step_stimuli, 0.1, Biochemistry.REACTION_DEFINITIONS
		)
		generic_state["compounds"] = expected["compounds"]
		generic_state["lastFluxes"] = expected["fluxes"]
		Biochemistry.advance_and_read_signals(optimized_state, step_stimuli, 0.1)
		if Biochemistry.read_compounds(generic_state) != Biochemistry.read_compounds(optimized_state) or Biochemistry.read_fluxes(generic_state) != Biochemistry.read_fluxes(optimized_state):
			matches_generic_engine = false
			break
	_expect(matches_generic_engine, "optimized 19-reaction path matches the generic evaluator during activity, rest, and social input")


func _verify_bounds_and_invalid_inputs() -> void:
	var state: Dictionary = Biochemistry.create_state()
	var before: Dictionary = Biochemistry.read_compounds(state)
	_expect(Biochemistry.advance(state, {}, INF).is_empty(), "infinite timestep is rejected")
	_expect(Biochemistry.read_compounds(state) == before, "rejected timestep leaves compounds unchanged")
	_expect(Biochemistry.advance(state, {"active": INF}, 0.1).is_empty(), "non-finite stimulus is rejected")
	_expect(Biochemistry.read_compounds(state) == before, "rejected stimulus leaves compounds unchanged")
	_expect(Biochemistry.apply_event(state, "food", INF).is_empty(), "non-finite event strength is rejected")
	_expect(Biochemistry.read_compounds(state) == before, "rejected event strength leaves compounds unchanged")

	var full: Dictionary = Biochemistry.read_compounds(state)
	for id: String in COMPOUND_IDS:
		full[id] = 100.0
	state["compounds"] = full
	Biochemistry.apply_event(state, "food", 2.0)
	var event_clamped: Dictionary = Biochemistry.read_compounds(state)
	_expect(event_clamped["starch"] == 100.0, "concentrations saturate after bounded event impulses")
	for _tick in range(20):
		Biochemistry.advance(state, {"active": 1.0, "resting": 1.0}, 0.5)
	_assert_bounds(Biochemistry.read_compounds(state), "saturated state")

	var depleted: Dictionary = Biochemistry.create_state()
	var empty_compounds: Dictionary = Biochemistry.read_compounds(depleted)
	for id: String in COMPOUND_IDS:
		empty_compounds[id] = 0.0
	depleted["compounds"] = empty_compounds
	Biochemistry.advance(depleted, {"active": 1.0, "resting": 1.0}, 0.5)
	var depleted_after: Dictionary = Biochemistry.read_compounds(depleted)
	_expect(depleted_after["ATP"] == 0.0 and depleted_after["glucose"] == 0.0, "depleted substrates cannot create energy or glucose")
	_assert_bounds(depleted_after, "depleted state")

	var long_step_a: Dictionary = Biochemistry.create_state()
	var long_step_b: Dictionary = Biochemistry.create_state()
	Biochemistry.advance(long_step_a, {"active": 1.0}, 0.5)
	Biochemistry.advance(long_step_b, {"active": 1.0}, 4.0)
	_expect(Biochemistry.read_compounds(long_step_a) == Biochemistry.read_compounds(long_step_b), "single-step dt is capped at 0.5 seconds")


func _verify_determinism_and_order() -> void:
	var first: Dictionary = Biochemistry.create_state({"glucose": 40.0, "hunger": 55.0, "fatigue": 20.0})
	var second: Dictionary = Biochemistry.create_state({"glucose": 40.0, "hunger": 55.0, "fatigue": 20.0})
	for tick in range(20):
		var stimuli := {"active": 0.7 if tick < 10 else 0.0, "resting": 0.0 if tick < 10 else 1.0}
		Biochemistry.advance(first, stimuli, 0.1)
		Biochemistry.advance(second, stimuli, 0.1)
	_expect(Biochemistry.read_compounds(first) == Biochemistry.read_compounds(second), "identical state and inputs replay deterministically")

	var sample: Dictionary = Biochemistry.read_compounds(first)
	var rules: Array[Dictionary] = [
		{"id": "test-starch-to-glucose", "reactants": {"starch": 1.0}, "products": {"glucose": 1.0}, "rate": 10.0},
		{"id": "test-glucose-to-pyruvate", "reactants": {"glucose": 1.0}, "products": {"pyruvate": 1.0}, "rate": 5.0}
	]
	var forward: Dictionary = Biochemistry._advance_reactions(sample, {}, 0.1, rules)
	rules.reverse()
	var reversed: Dictionary = Biochemistry._advance_reactions(sample, {}, 0.1, rules)
	_expect(forward["compounds"] == reversed["compounds"], "reaction table order does not alter a fixed-step result")


func _verify_serialization_and_migration() -> void:
	var legacy := {"glucose": 55.0, "hunger": 45.0, "curiosity": 32.0, "fatigue": 22.0}
	var state: Dictionary = Biochemistry.create_state(legacy)
	Biochemistry.apply_event(state, "food")
	Biochemistry.advance(state, {"active": 0.4}, 0.1)
	var record: Dictionary = Biochemistry.serialize_state(state)
	var restored: Dictionary = Biochemistry.restore_state(record)
	_expect(not restored.is_empty() and int(restored.get("version", -1)) == Biochemistry.VERSION, "version-2 biochemical state restores")
	_expect(Biochemistry.read_compounds(restored) == Biochemistry.read_compounds(state), "serialization round-trips every compound")
	_expect(Biochemistry.read_fluxes(restored) == Biochemistry.read_fluxes(state), "serialization round-trips latest reaction fluxes")

	var migrated: Dictionary = Biochemistry.migrate_from_legacy_signals(legacy)
	_expect(not migrated.is_empty(), "legacy cognition signals migrate into biochemistry")
	_expect(Biochemistry.read_signals(migrated)["glucose"] == 55.0 and Biochemistry.read_signals(migrated)["hunger"] == 45.0, "migration preserves legacy cognition signals")
	record["version"] = 99
	_expect(Biochemistry.restore_state(record).is_empty(), "unsupported biochemical record version is rejected")


func _verify_cognition_bridge() -> void:
	var initial := {"glucose": 55.0, "hunger": 45.0, "curiosity": 35.0, "fatigue": 18.0}
	var biochemistry: Dictionary = Biochemistry.create_state(initial)
	var signals: Dictionary = Biochemistry.read_signals(biochemistry)
	var cognition: Dictionary = Cognition.create_state(4181996, {}, initial)
	_expect(Cognition.sync_chemistry(cognition, signals), "cognition accepts the eleven biochemical signals")
	_expect(cognition["chemistry"] == signals, "cognition stores the synchronized signal readout")
	var invalid_signals: Dictionary = signals.duplicate(true)
	invalid_signals.erase("hunger")
	_expect(not Cognition.sync_chemistry(cognition, invalid_signals), "cognition rejects an incomplete signal map")
	_expect(cognition["chemistry"] == signals, "rejected signal map leaves cognition unchanged")

	var before: Dictionary = signals.duplicate(true)
	var after: Dictionary = signals.duplicate(true)
	after["glucose"] = 68.0
	after["hunger"] = 31.0
	var external := {"before": before, "after": after}
	var outcome := {"eventType": "food", "actionId": "fruit", "targetId": "fruit", "time": 1.0}
	var result: Dictionary = Cognition.record_outcome(cognition, outcome, external)
	var episode: Dictionary = cognition["episodes"].back()
	_expect(episode["chemicalsBefore"] == before, "external event stores the biochemical pre-event readout")
	_expect(episode["chemicalsAfter"] == after, "external event stores the biochemical post-event readout")
	_expect(cognition["chemistry"] == after, "external event leaves cognition synchronized to post-event state")
	_expect(float(cognition["chemistry"]["hunger"]) == 31.0, "external event does not apply legacy food chemistry twice")
	_expect(float(result.get("learningDelta", 0.0)) > 0.0, "external event keeps the bounded learning update")

	var legacy_cognition: Dictionary = Cognition.create_state(4181996, {}, initial)
	Cognition.record_outcome(legacy_cognition, outcome)
	_expect(legacy_cognition["chemistry"]["hunger"] == 3.0, "two-argument outcome retains the cognition-only food adjustment")
	_expect(legacy_cognition["chemistry"]["glucose"] == 89.0, "two-argument outcome retains the cognition-only glucose adjustment")


func _assert_bounds(compounds: Dictionary, label: String) -> void:
	for id: String in COMPOUND_IDS:
		var value := float(compounds.get(id, NAN))
		_expect(is_finite(value) and value >= 0.0 and value <= 100.0, "%s %s remains finite and bounded" % [label, id])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
