extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	test_profiles_keep_independent_state()
	await test_actor_approaches_peer_without_consuming_object()
	if _failures.is_empty():
		print("SOCIAL_SLICE_CHECKS_OK")
		quit(0)
		return
	for failure: String in _failures:
		push_error("SOCIAL_SLICE_CHECK_FAILED: " + failure)
	quit(1)


func test_profiles_keep_independent_state() -> void:
	var profile_path := "res://scripts/norn_profile.gd"
	if not ResourceLoader.exists(profile_path):
		_expect(false, "NornProfile script exists")
		return
	var profile_script: Script = load(profile_path)
	var first: Object = profile_script.new()
	var second: Object = profile_script.new()
	var first_actor := NornActor.new()
	var second_actor := NornActor.new()
	var first_cognition := {"chemistry": {"hunger": 41.0}}
	var second_cognition := {"chemistry": {"hunger": 73.0}}
	var first_biochemistry := {"compounds": {"ATP": 21.0}}
	var second_biochemistry := {"compounds": {"ATP": 64.0}}
	var first_language := {"words": {"fruit": 0.38}}
	var second_language := {"words": {"spinner": 0.76}}
	first.call("initialize", "mallow", "Mallow", first_actor, first_cognition, first_biochemistry, first_language)
	second.call("initialize", "moss", "Moss", second_actor, second_cognition, second_biochemistry, second_language)
	var first_cognition_state: Dictionary = first.get("cognition_state")
	var second_cognition_state: Dictionary = second.get("cognition_state")
	var first_biochemistry_state: Dictionary = first.get("biochemistry_state")
	var second_biochemistry_state: Dictionary = second.get("biochemistry_state")
	var first_language_state: Dictionary = first.get("language_state")
	var second_language_state: Dictionary = second.get("language_state")
	first_cognition_state["chemistry"]["hunger"] = 12.0
	first_biochemistry_state["compounds"]["ATP"] = 4.0
	first_language_state["words"]["fruit"] = 0.9
	_expect(first.get("actor_id") == "mallow" and second.get("actor_id") == "moss", "profiles retain distinct stable actor IDs")
	_expect(first_cognition_state["chemistry"]["hunger"] == 12.0 and second_cognition_state["chemistry"]["hunger"] == 73.0, "changing one profile's cognition does not change the other")
	_expect(first_biochemistry_state["compounds"]["ATP"] == 4.0 and second_biochemistry_state["compounds"]["ATP"] == 64.0, "changing one profile's compounds does not change the other")
	_expect(first_language_state["words"]["fruit"] == 0.9 and second_language_state["words"]["spinner"] == 0.76, "changing one profile's vocabulary does not change the other")
	first_actor.free()
	second_actor.free()


func test_actor_approaches_peer_without_consuming_object() -> void:
	var habitat := Node3D.new()
	habitat.name = "SocialTestHabitat"
	root.add_child(habitat)
	var actor := NornActor.new()
	actor.name = "MallowActor"
	if actor.has_method("configure_identity"):
		actor.call("configure_identity", "mallow", "Mallow", Color(0.43, 0.27, 0.16))
	actor.position = Vector3.ZERO
	habitat.add_child(actor)
	var peer := Node3D.new()
	peer.name = "MossPeer"
	peer.position = Vector3(3.5, 0.0, 0.0)
	habitat.add_child(peer)
	var fruit := Interactable.new()
	fruit.name = "UntouchedFruit"
	fruit.configure("fruit", "food", "Honey fruit", ["eat"])
	fruit.position = Vector3(6.0, 0.0, 0.0)
	habitat.add_child(fruit)
	await process_frame
	await physics_frame
	var completion_events: Array[Dictionary] = []
	var action_signal_arguments := _signal_argument_count(actor, "action_completed")
	if action_signal_arguments == 3:
		actor.action_completed.connect(_capture_action_completed_three.bind(completion_events))
	elif action_signal_arguments == 2:
		actor.action_completed.connect(_capture_action_completed_two.bind(completion_events))
	_expect(action_signal_arguments == 3, "action completion signal includes the actor ID")
	var target_arguments: Array = [peer, "observe_peer", "Watching Moss"]
	if _method_argument_count(actor, "set_action_target") >= 4:
		target_arguments.append("moss")
	actor.callv("set_action_target", target_arguments)
	_expect(actor.current_action == "observe_peer", "peer approach keeps the observe_peer action")
	_expect(actor.get("target") == peer, "actor can retain a generic Node3D peer as its target")
	_expect(_has_property(actor, "actor_id") and actor.get("actor_id") == "mallow", "actor retains its stable ID")
	_expect(_has_property(actor, "target_id") and actor.get("target_id") == "moss", "actor retains the stable target ID")
	for _frame in range(120):
		await physics_frame
		if not actor.is_walking and actor.global_position.distance_to(peer.global_position) <= 2.2:
			break
	_expect(not actor.is_walking and actor.global_position.distance_to(peer.global_position) <= 2.2, "actor approaches and settles within the peer stop distance")
	_expect(completion_events.is_empty(), "peer arrival does not emit an object action completion")
	_expect(fruit.available, "arriving at a peer does not consume a habitat object")
	var fruit_target_arguments: Array = [fruit, "fruit", "Eating honey fruit"]
	if _method_argument_count(actor, "set_action_target") >= 4:
		fruit_target_arguments.append("fruit")
	actor.callv("set_action_target", fruit_target_arguments)
	for _frame in range(180):
		await physics_frame
		if not actor.is_walking and not completion_events.is_empty():
			break
	_expect(completion_events.size() == 1, "interactable arrival emits exactly one completion")
	if completion_events.size() == 1:
		_expect(completion_events[0].get("actorId", "") == "mallow", "interactable completion identifies the actor")
		_expect(completion_events[0].get("actionId", "") == "fruit" and completion_events[0].get("targetId", "") == "fruit", "interactable completion preserves action and target IDs")
	habitat.queue_free()
	await process_frame
	await physics_frame


func _method_argument_count(object: Object, method_name: String) -> int:
	for method: Dictionary in object.get_method_list():
		if str(method.get("name", "")) == method_name:
			return (method.get("args", []) as Array).size()
	return -1


func _signal_argument_count(object: Object, signal_name: String) -> int:
	for signal_info: Dictionary in object.get_signal_list():
		if str(signal_info.get("name", "")) == signal_name:
			return (signal_info.get("args", []) as Array).size()
	return -1


func _capture_action_completed_two(action_id: String, target_id: String, events: Array) -> void:
	events.append({"actionId": action_id, "targetId": target_id})


func _capture_action_completed_three(actor_id: String, action_id: String, target_id: String, events: Array) -> void:
	events.append({"actorId": actor_id, "actionId": action_id, "targetId": target_id})


func _has_property(object: Object, property_name: String) -> bool:
	for property: Dictionary in object.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	return false


func _expect(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
