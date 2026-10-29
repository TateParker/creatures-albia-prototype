class_name NornBiochemistry
extends RefCounted

const VERSION := 1
const MAX_STEP_SECONDS := 0.5
const MAX_REACTION_RATE := 24.0
const COMPOUND_IDS: Array[String] = [
	"glucose", "hunger", "curiosity", "fatigue", "reward",
	"punishment", "stress", "socialComfort", "arousal", "satiety",
	"starch", "glycogen", "pyruvate", "ATP", "ADP", "oxygen", "carbonDioxide", "water"
]
const SIGNAL_IDS: Array[String] = [
	"glucose", "hunger", "curiosity", "fatigue", "reward",
	"punishment", "stress", "socialComfort", "arousal", "satiety"
]
const INITIAL_COMPOUNDS := {
	"glucose": 55.0,
	"hunger": 45.0,
	"curiosity": 45.0,
	"fatigue": 15.0,
	"reward": 0.0,
	"punishment": 0.0,
	"stress": 0.0,
	"socialComfort": 50.0,
	"arousal": 15.75,
	"satiety": 55.0,
	"starch": 0.0,
	"glycogen": 25.0,
	"pyruvate": 0.0,
	"ATP": 55.0,
	"ADP": 20.0,
	"oxygen": 100.0,
	"carbonDioxide": 0.0,
	"water": 50.0
}
const EVENT_DEFINITIONS := {
	"food": {"starch": 34.0, "reward": 8.0},
	"toy": {"curiosity": -45.0, "arousal": -12.0, "reward": 8.0},
	"praise": {"reward": 12.0, "stress": -6.0},
	"scold": {"punishment": 12.0, "stress": 8.0},
	"teach-word": {"socialComfort": 1.5},
	"social": {"socialComfort": 1.5}
}
const REACTION_DEFINITIONS: Array[Dictionary] = [
	{"id": "starch-digestion", "reactants": {"starch": 1.0}, "products": {"glucose": 1.0}, "rate": 12.0},
	{"id": "glucose-storage", "reactants": {"glucose": 1.0}, "products": {"glycogen": 1.0}, "rate": 0.8, "stimulus": "resting"},
	{"id": "glycogen-mobilization", "reactants": {"glycogen": 1.0}, "products": {"glucose": 1.0}, "rate": 1.8, "stimulus": "active"},
	{"id": "glucose-oxidation", "reactants": {"glucose": 1.0, "oxygen": 0.5}, "products": {"pyruvate": 0.7, "ATP": 1.0, "carbonDioxide": 0.3, "water": 0.5}, "rate": 7.0},
	{"id": "pyruvate-oxidation", "reactants": {"pyruvate": 1.0, "oxygen": 0.5}, "products": {"ATP": 1.8, "carbonDioxide": 0.7, "water": 0.8}, "rate": 5.0},
	{"id": "glucose-satiation", "reactants": {"glucose": 1.0, "hunger": 1.0}, "products": {"glucose": 1.0, "satiety": 0.65}, "rate": 24.0},
	{"id": "basal-hunger", "reactants": {"glucose": 0.1}, "products": {"glucose": 0.1, "hunger": 1.0}, "rate": 1.55},
	{"id": "activity-energy-use", "reactants": {"ATP": 1.0}, "products": {"ADP": 1.0, "fatigue": 0.35}, "rate": 5.0, "stimulus": "active"},
	{"id": "rest-energy-recovery", "reactants": {"ADP": 1.0, "glycogen": 0.1}, "products": {"ATP": 1.0, "glycogen": 0.1}, "rate": 6.0, "stimulus": "resting"},
	{"id": "fatigue-recovery", "reactants": {"fatigue": 1.0}, "products": {}, "rate": 4.0, "stimulus": "resting"},
	{"id": "curiosity-drift", "reactants": {"curiosity": 1.0}, "products": {}, "rate": 0.12},
	{"id": "reward-decay", "reactants": {"reward": 1.0}, "products": {}, "rate": 7.0},
	{"id": "punishment-decay", "reactants": {"punishment": 1.0}, "products": {}, "rate": 7.0},
	{"id": "stress-decay", "reactants": {"stress": 1.0}, "products": {}, "rate": 1.6},
	{"id": "social-comfort-drift", "reactants": {"socialComfort": 1.0}, "products": {}, "rate": 0.15},
	{"id": "peer-comfort", "reactants": {"oxygen": 1.0}, "products": {"oxygen": 1.0, "socialComfort": 0.55}, "rate": 1.0, "stimulus": "nearbyPeer"},
	{"id": "arousal-decay", "reactants": {"arousal": 1.0}, "products": {}, "rate": 0.6},
	{"id": "satiety-decay", "reactants": {"satiety": 1.0}, "products": {}, "rate": 0.8}
]
static var _fast_reaction_cache: Array[Dictionary] = []


static func create_state(initial_signals: Dictionary = {}) -> Dictionary:
	var compounds: Dictionary = INITIAL_COMPOUNDS.duplicate(true)
	for signal_id: String in SIGNAL_IDS:
		if initial_signals.has(signal_id):
			var value = initial_signals[signal_id]
			if _is_finite_number(value):
				compounds[signal_id] = clampf(float(value), 0.0, 100.0)
	return {
		"version": VERSION,
		"compounds": compounds,
		"lastFluxes": {}
	}


static func advance(state: Dictionary, stimuli: Dictionary = {}, dt: float = 0.1) -> Dictionary:
	if not _advance_state(state, stimuli, dt):
		return {}
	return _make_snapshot(state)


static func advance_and_read_signals(state: Dictionary, stimuli: Dictionary = {}, dt: float = 0.1) -> Dictionary:
	if not _advance_state(state, stimuli, dt):
		return {}
	return _read_signals_unchecked(state["compounds"])


static func apply_event(state: Dictionary, event_id: String, strength: float = 1.0) -> Dictionary:
	if not _is_valid_state(state) or not _is_finite_number(strength) or not EVENT_DEFINITIONS.has(event_id):
		return {}
	var bounded_strength := clampf(strength, 0.0, 1.0)
	var compounds: Dictionary = state["compounds"].duplicate(true)
	var event_deltas: Dictionary = EVENT_DEFINITIONS[event_id]
	for compound_id: String in event_deltas:
		var change := float(event_deltas[compound_id]) * bounded_strength
		compounds[compound_id] = clampf(float(compounds[compound_id]) + change, 0.0, 100.0)
	state["compounds"] = compounds
	return _make_snapshot(state, true, event_id)


static func read_signals(state: Dictionary) -> Dictionary:
	if not _is_valid_state(state):
		return {}
	return _read_signals_unchecked(state["compounds"])


static func _read_signals_unchecked(compounds: Dictionary) -> Dictionary:
	var signals := {}
	for signal_id: String in SIGNAL_IDS:
		signals[signal_id] = float(compounds[signal_id])
	return signals


static func read_compounds(state: Dictionary) -> Dictionary:
	return state["compounds"].duplicate(true) if _is_valid_state(state) else {}


static func read_fluxes(state: Dictionary) -> Dictionary:
	return state["lastFluxes"].duplicate(true) if _is_valid_state(state) else {}


static func serialize_state(state: Dictionary) -> Dictionary:
	if not _is_valid_state(state):
		return {}
	return {
		"version": VERSION,
		"compounds": read_compounds(state),
		"lastFluxes": read_fluxes(state)
	}


static func restore_state(record: Variant) -> Dictionary:
	if not (record is Dictionary):
		return {}
	var saved: Dictionary = record
	if int(saved.get("version", -1)) != VERSION:
		return {}
	var compounds = saved.get("compounds", null)
	var fluxes = saved.get("lastFluxes", null)
	if not (compounds is Dictionary) or not (fluxes is Dictionary):
		return {}
	if not _valid_compound_map(compounds):
		return {}
	if not _valid_flux_map(fluxes):
		return {}
	return {
		"version": VERSION,
		"compounds": compounds.duplicate(true),
		"lastFluxes": fluxes.duplicate(true)
	}


static func migrate_from_legacy_signals(signals: Dictionary) -> Dictionary:
	return create_state(signals)


static func _advance_reactions(compounds: Dictionary, stimuli: Dictionary, dt: float, reaction_rules: Array[Dictionary]) -> Dictionary:
	var snapshot: Dictionary = compounds.duplicate(true)
	var deltas := {}
	var fluxes := {}
	for compound_id: String in COMPOUND_IDS:
		deltas[compound_id] = 0.0
	for rule: Dictionary in reaction_rules:
		var reactants = rule.get("reactants", null)
		var products = rule.get("products", null)
		if not (reactants is Dictionary) or not (products is Dictionary) or reactants.is_empty():
			continue
		var rate := clampf(_finite_or(rule.get("rate", 0.0), 0.0), 0.0, MAX_REACTION_RATE)
		if rate <= 0.0:
			continue
		var gate_name := str(rule.get("stimulus", ""))
		var gate := float(stimuli.get(gate_name, 0.0)) if not gate_name.is_empty() else 1.0
		gate = clampf(_finite_or(gate, 0.0), 0.0, 1.0)
		if gate <= 0.0:
			continue
		var limiting_availability := 1.0
		var available_flux := INF
		var valid_rule := true
		for compound_id: Variant in reactants:
			var id := str(compound_id)
			var coefficient = reactants[compound_id]
			if not snapshot.has(id) or not _is_positive_finite_number(coefficient):
				valid_rule = false
				break
			var stoichiometry := float(coefficient)
			var concentration := float(snapshot[id])
			available_flux = minf(available_flux, concentration / stoichiometry)
			limiting_availability = minf(limiting_availability, concentration / (100.0 * stoichiometry))
		if not valid_rule:
			continue
		for compound_id: Variant in products:
			var id := str(compound_id)
			if not snapshot.has(id) or not _is_positive_finite_number(products[compound_id]):
				valid_rule = false
				break
		if not valid_rule:
			continue
		var potential_flux := rate * clampf(dt, 0.0, MAX_STEP_SECONDS) * limiting_availability * gate
		var flux := minf(potential_flux, available_flux)
		if flux <= 0.0:
			continue
		var rule_id := str(rule.get("id", "reaction-%d" % fluxes.size()))
		fluxes[rule_id] = flux
		for compound_id: Variant in reactants:
			var id := str(compound_id)
			deltas[id] = float(deltas[id]) - flux * float(reactants[compound_id])
		for compound_id: Variant in products:
			var id := str(compound_id)
			deltas[id] = float(deltas[id]) + flux * float(products[compound_id])
	var next_compounds := {}
	for compound_id: String in COMPOUND_IDS:
		next_compounds[compound_id] = clampf(float(snapshot[compound_id]) + float(deltas[compound_id]), 0.0, 100.0)
	return {"compounds": next_compounds, "fluxes": fluxes}


static func _advance_state(state: Dictionary, stimuli: Dictionary, dt: float) -> bool:
	var compound_value = state.get("compounds", null)
	if int(state.get("version", -1)) != VERSION or not (compound_value is Dictionary) or not _valid_compound_map(compound_value):
		return false
	if not _is_finite_number(dt) or float(dt) <= 0.0 or not _all_finite_values(stimuli):
		return false
	var active := clampf(float(stimuli.get("active", 0.0)), 0.0, 1.0)
	var resting := clampf(float(stimuli.get("resting", 0.0)), 0.0, 1.0)
	var nearby_peer := clampf(float(stimuli.get("nearbyPeer", 0.0)), 0.0, 1.0)
	var compounds: Dictionary = state["compounds"]
	var values := PackedFloat64Array()
	values.resize(COMPOUND_IDS.size())
	for compound_index in range(COMPOUND_IDS.size()):
		values[compound_index] = float(compounds[COMPOUND_IDS[compound_index]])
	var deltas := PackedFloat64Array()
	deltas.resize(COMPOUND_IDS.size())
	var fluxes: Dictionary = {}
	var step_seconds := minf(float(dt), MAX_STEP_SECONDS)
	for rule: Dictionary in _get_fast_reaction_definitions():
		var gate := 1.0
		match int(rule["stimulus"]):
			0:
				gate = active
			1:
				gate = resting
			2:
				gate = nearby_peer
		if gate <= 0.0:
			continue
		var reactants: Array = rule["reactants"]
		var products: Array = rule["products"]
		var limiting_availability := 1.0
		var available_flux := INF
		for reactant: Array in reactants:
			var compound_index := int(reactant[0])
			var stoichiometry := float(reactant[1])
			var concentration := values[compound_index]
			available_flux = minf(available_flux, concentration / stoichiometry)
			limiting_availability = minf(limiting_availability, concentration / (100.0 * stoichiometry))
		var flux := minf(float(rule["rate"]) * step_seconds * limiting_availability * gate, available_flux)
		if flux <= 0.0:
			continue
		fluxes[str(rule["id"])] = flux
		for reactant: Array in reactants:
			var compound_index := int(reactant[0])
			deltas[compound_index] = deltas[compound_index] - flux * float(reactant[1])
		for product: Array in products:
			var compound_index := int(product[0])
			deltas[compound_index] = deltas[compound_index] + flux * float(product[1])
	var next_compounds: Dictionary = {}
	for compound_index in range(COMPOUND_IDS.size()):
		var compound_id: String = COMPOUND_IDS[compound_index]
		next_compounds[compound_id] = clampf(values[compound_index] + deltas[compound_index], 0.0, 100.0)
	state["compounds"] = next_compounds
	state["lastFluxes"] = fluxes
	return true


static func _get_fast_reaction_definitions() -> Array[Dictionary]:
	if not _fast_reaction_cache.is_empty():
		return _fast_reaction_cache
	for definition: Dictionary in REACTION_DEFINITIONS:
		var reactants: Array = []
		for compound_id: Variant in definition["reactants"]:
			reactants.append([COMPOUND_IDS.find(str(compound_id)), float(definition["reactants"][compound_id])])
		var products: Array = []
		for compound_id: Variant in definition["products"]:
			products.append([COMPOUND_IDS.find(str(compound_id)), float(definition["products"][compound_id])])
		var stimulus_id := -1
		match str(definition.get("stimulus", "")):
			"active":
				stimulus_id = 0
			"resting":
				stimulus_id = 1
			"nearbyPeer":
				stimulus_id = 2
		_fast_reaction_cache.append({
			"id": str(definition["id"]),
			"reactants": reactants,
			"products": products,
			"rate": clampf(float(definition["rate"]), 0.0, MAX_REACTION_RATE),
			"stimulus": stimulus_id
		})
	return _fast_reaction_cache


static func _make_snapshot(state: Dictionary, include_event: bool = false, event_id: String = "") -> Dictionary:
	var snapshot := {
		"compounds": read_compounds(state),
		"signals": read_signals(state),
		"fluxes": read_fluxes(state)
	}
	if include_event:
		snapshot["ok"] = true
		snapshot["eventId"] = event_id
	return snapshot


static func _is_valid_state(state: Dictionary) -> bool:
	if int(state.get("version", -1)) != VERSION:
		return false
	var compounds = state.get("compounds", null)
	var fluxes = state.get("lastFluxes", null)
	return compounds is Dictionary and fluxes is Dictionary and _valid_compound_map(compounds) and _valid_flux_map(fluxes)


static func _valid_compound_map(compounds: Dictionary) -> bool:
	if compounds.size() != COMPOUND_IDS.size():
		return false
	for compound_id: String in COMPOUND_IDS:
		var value = compounds.get(compound_id, null)
		if not _is_finite_number(value) or float(value) < 0.0 or float(value) > 100.0:
			return false
	return true


static func _valid_flux_map(fluxes: Dictionary) -> bool:
	for flux in fluxes.values():
		if not _is_finite_number(flux) or float(flux) < 0.0:
			return false
	return true


static func _all_finite_values(values: Dictionary) -> bool:
	for value in values.values():
		if not _is_finite_number(value):
			return false
	return true


static func _is_positive_finite_number(value: Variant) -> bool:
	return _is_finite_number(value) and float(value) > 0.0


static func _is_finite_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value))


static func _finite_or(value: Variant, fallback: float) -> float:
	return float(value) if _is_finite_number(value) else fallback
