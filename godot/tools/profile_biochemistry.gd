extends SceneTree

const Biochemistry = preload("res://scripts/norn_biochemistry.gd")
const Cognition = preload("res://scripts/norn_cognition.gd")
const POPULATION_SIZES: Array[int] = [1, 4, 12]
const SAMPLE_COUNT := 1000
const STEP_SECONDS := 0.1
const INITIAL_SIGNALS := {
	"glucose": 55.0,
	"hunger": 45.0,
	"curiosity": 45.0,
	"fatigue": 15.0,
	"reward": 5.0,
	"punishment": 2.0,
	"stress": 5.0,
	"socialComfort": 50.0,
	"arousal": 15.75,
	"satiety": 55.0
}
const STIMULI := {"active": 1.0, "resting": 0.0, "nearbyPeer": 0.0}


func _initialize() -> void:
	call_deferred("_profile")


func _profile() -> void:
	var warmup_state: Dictionary = Biochemistry.create_state(INITIAL_SIGNALS)
	var warmup_cognition: Dictionary = Cognition.create_state(4181996, {}, INITIAL_SIGNALS)
	for step in range(200):
		var warmup_signals: Dictionary = Biochemistry.advance_and_read_signals(warmup_state, STIMULI, STEP_SECONDS)
		if warmup_signals.is_empty() or not Cognition.sync_chemistry(warmup_cognition, warmup_signals):
			_fail("Biochemistry warm-up did not return a valid state snapshot.")
			return
	var measurements: Array[Dictionary] = []
	for population_size: int in POPULATION_SIZES:
		if not _check_population_isolation_and_inputs(population_size):
			return
		measurements.append(_measure_population(population_size))
	var twelve_state_p95 := float(measurements.back()["p95_us"])
	if twelve_state_p95 >= 1000.0:
		_fail("The 12-state p95 exceeded the 1 ms real-time target (%.2f μs)." % twelve_state_p95)
		return
	print("BIOCHEMISTRY_PROFILE_OK states=1,4,12 samples=%d target_12_state_p95_us<1000" % SAMPLE_COUNT)
	quit()


func _check_population_isolation_and_inputs(population_size: int) -> bool:
	var states := _create_population(population_size)
	var initial_compounds: Array[Dictionary] = []
	for state: Dictionary in states:
		initial_compounds.append(Biochemistry.read_compounds(state))
	if population_size > 1:
		Biochemistry.apply_event(states[0], "food")
		for index in range(1, population_size):
			if Biochemistry.read_compounds(states[index]) != initial_compounds[index]:
				_fail("Population %d shares biochemical state with Norn 0." % population_size)
				return false

	states = _create_population(population_size)
	var reference: Dictionary = {}
	for index in range(population_size):
		var input_stimuli: Dictionary = STIMULI.duplicate(true)
		var signals: Dictionary = Biochemistry.advance_and_read_signals(states[index], input_stimuli, STEP_SECONDS)
		var result := {
			"compounds": Biochemistry.read_compounds(states[index]),
			"signals": signals,
			"fluxes": Biochemistry.read_fluxes(states[index])
		}
		if result.is_empty():
			_fail("Population %d did not accept the fixed 0.1-second input." % population_size)
			return false
		if index == 0:
			reference = result
		elif not _snapshots_match(reference, result):
			_fail("Population %d did not give every Norn identical starting inputs." % population_size)
			return false
	return true


func _measure_population(population_size: int) -> Dictionary:
	var states := _create_population(population_size)
	var cognition_states: Array[Dictionary] = []
	for index in range(population_size):
		cognition_states.append(Cognition.create_state(4181996 + index, {}, INITIAL_SIGNALS))
	var samples: Array[float] = []
	for sample_index in range(SAMPLE_COUNT):
		var start_usec := Time.get_ticks_usec()
		for index in range(population_size):
			var signals: Dictionary = Biochemistry.advance_and_read_signals(states[index], STIMULI, STEP_SECONDS)
			Cognition.sync_chemistry(cognition_states[index], signals)
		samples.append(float(Time.get_ticks_usec() - start_usec))
	samples.sort()
	var median_usec := (samples[499] + samples[500]) * 0.5
	var p95_usec := samples[ceili(float(SAMPLE_COUNT) * 0.95) - 1]
	var maximum_usec: float = samples[samples.size() - 1]
	var measurement := {
		"states": population_size,
		"median_us": median_usec,
		"p95_us": p95_usec,
		"max_us": maximum_usec
	}
	print("BIOCHEMISTRY_PROFILE states=%d samples=%d work=bio-step+signal-sync median_us=%.2f p95_us=%.2f max_us=%.2f" % [
		population_size,
		SAMPLE_COUNT,
		median_usec,
		p95_usec,
		maximum_usec
	])
	return measurement


func _create_population(population_size: int) -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	for index in range(population_size):
		states.append(Biochemistry.create_state(INITIAL_SIGNALS))
	return states


func _snapshots_match(left: Dictionary, right: Dictionary) -> bool:
	for snapshot_key: String in ["compounds", "signals", "fluxes"]:
		if left.get(snapshot_key, {}) != right.get(snapshot_key, {}):
			return false
	return true


func _fail(message: String) -> void:
	push_error("BIOCHEMISTRY_PROFILE_FAILED: " + message)
	quit(1)
