class_name NornLanguage
extends RefCounted

const STATE_VERSION := 1
const MAX_WORDS := 32
const MAX_WORD_LENGTH := 24
const TEACH_INCREMENT := 0.38
const UTTERANCE_THRESHOLD := 0.60
const TARGET_IDS: Array[String] = ["fruit", "spinner", "berry_bush", "spring", "echo_bloom", "praise", "scold"]


func create_state() -> Dictionary:
	return {"version": STATE_VERSION, "words": {}}


func teach_word(state: Dictionary, input: String, target_id: String) -> Dictionary:
	if not state.has("words") or not (state["words"] is Dictionary):
		return {"ok": false, "error": "The vocabulary state is not available."}
	var word := input.strip_edges()
	if word.is_empty():
		return {"ok": false, "error": "Type one word (up to 24 characters) first."}
	if word.length() > MAX_WORD_LENGTH:
		return {"ok": false, "error": "Keep the teaching word to 24 characters or fewer."}
	if _contains_whitespace(word):
		return {"ok": false, "error": "Teach one word at a time; phrases are not supported."}
	if not TARGET_IDS.has(target_id):
		return {"ok": false, "error": "Choose fruit, spinner, berries, spring, echo bloom, Praise, or Scold as the meaning."}

	var words: Dictionary = state["words"]
	var normalized := word.to_lower()
	if words.has(normalized):
		var existing: Dictionary = words[normalized]
		if str(existing.get("targetId", "")) != target_id:
			return {
				"ok": false,
				"error": "“%s” already means %s. Use another word or keep its current meaning." % [str(existing.get("word", word)), _target_name(str(existing.get("targetId", "")))]
			}
		existing["confidence"] = clampf(float(existing.get("confidence", 0.0)) + TEACH_INCREMENT, 0.0, 1.0)
		return {
			"ok": true,
			"word": str(existing.get("word", word)),
			"targetId": target_id,
			"confidence": float(existing["confidence"]),
			"repeated": true
		}
	if words.size() >= MAX_WORDS:
		return {"ok": false, "error": "Mallow can learn up to 32 different words."}
	words[normalized] = {"word": word, "targetId": target_id, "confidence": TEACH_INCREMENT}
	return {"ok": true, "word": word, "targetId": target_id, "confidence": TEACH_INCREMENT, "repeated": false}


func adjust_target(state: Dictionary, target_id: String, delta: float) -> Array[Dictionary]:
	var adjusted: Array[Dictionary] = []
	if not TARGET_IDS.has(target_id) or not _is_finite_number(delta):
		return adjusted
	var words: Dictionary = state.get("words", {})
	if not (words is Dictionary):
		return adjusted
	for normalized: String in words.keys():
		var entry: Dictionary = words[normalized]
		if str(entry.get("targetId", "")) != target_id:
			continue
		entry["confidence"] = clampf(float(entry.get("confidence", 0.0)) + delta, 0.0, 1.0)
		adjusted.append({
			"word": str(entry.get("word", normalized)),
			"targetId": target_id,
			"confidence": float(entry["confidence"])
		})
	return adjusted


func word_for_target(state: Dictionary, target_id: String) -> Dictionary:
	if not TARGET_IDS.has(target_id):
		return {}
	var words: Dictionary = state.get("words", {})
	if not (words is Dictionary):
		return {}
	var keys: Array = words.keys()
	keys.sort()
	var best: Dictionary = {}
	for normalized: String in keys:
		var entry: Dictionary = words[normalized]
		var confidence := float(entry.get("confidence", 0.0))
		if str(entry.get("targetId", "")) != target_id or confidence < UTTERANCE_THRESHOLD:
			continue
		if best.is_empty() or confidence > float(best.get("confidence", 0.0)):
			best = {
				"word": str(entry.get("word", normalized)),
				"targetId": target_id,
				"confidence": confidence
			}
	return best


func serialize_state(state: Dictionary) -> Dictionary:
	var restored := restore_state(state)
	if restored.is_empty():
		return {}
	return restored.duplicate(true)


func restore_state(value: Variant) -> Dictionary:
	if not (value is Dictionary) or int(value.get("version", -1)) != STATE_VERSION:
		return {}
	var source = value.get("words", null)
	if not (source is Dictionary) or source.size() > MAX_WORDS:
		return {}
	var normalized_words: Dictionary = {}
	for key: Variant in source:
		if not (key is String):
			return {}
		var entry = source[key]
		if not (entry is Dictionary):
			return {}
		var word = entry.get("word", null)
		var target_id = entry.get("targetId", null)
		var confidence = entry.get("confidence", null)
		if not (word is String) or not (target_id is String) or not (confidence is int or confidence is float):
			return {}
		if word != word.strip_edges() or word.is_empty() or word.length() > MAX_WORD_LENGTH or _contains_whitespace(word):
			return {}
		if word.to_lower() != key or not TARGET_IDS.has(target_id):
			return {}
		if not is_finite(float(confidence)) or float(confidence) < 0.0 or float(confidence) > 1.0:
			return {}
		normalized_words[key] = {
			"word": word,
			"targetId": target_id,
			"confidence": float(confidence)
		}
	return {"version": STATE_VERSION, "words": normalized_words}


func _contains_whitespace(value: String) -> bool:
	var whitespace := RegEx.new()
	whitespace.compile("\\s")
	return whitespace.search(value) != null


func _target_name(target_id: String) -> String:
	match target_id:
		"fruit":
			return "honey fruit"
		"spinner":
			return "the wind-up spinner"
		"berry_bush":
			return "the berry bush"
		"spring":
			return "the spring"
		"echo_bloom":
			return "the echo bloom"
		"praise":
			return "Praise"
		"scold":
			return "Scold"
	return "another concept"


func _is_finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
