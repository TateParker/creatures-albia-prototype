extends SceneTree

const Cognition = preload("res://scripts/norn_cognition.gd")
const Biochemistry = preload("res://scripts/norn_biochemistry.gd")
const Lifecycle = preload("res://scripts/norn_lifecycle.gd")
const ProfileScript = preload("res://scripts/norn_profile.gd")
const SAVE_PATH := "user://albia_norn_save.json"

var _failures: Array[String] = []
var _save_backup_available: bool = false
var _save_backup_ok: bool = true
var _original_save_text: String = ""


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	_save_backup_ok = _capture_original_save()
	test_profiles_keep_independent_state()
	await test_actor_approaches_peer_without_consuming_object()
	await test_world_spawns_two_independent_norns()
	await test_peer_perception_filters_distance_and_occlusion()
	await test_shared_object_sensing_filters_distance_and_occlusion()
	await test_peer_comfort_rises_and_decays()
	test_social_attention_selects_observation_when_needs_are_settled()
	await test_observer_stays_settled_inside_stop_distance()
	await test_baby_follows_nearest_living_parent_and_resumes_after_separation()
	await test_baby_follow_respects_priorities_and_orphan_fallback()
	await test_adolescent_observer_prefers_nearest_visible_non_parent_and_falls_back()
	await test_adolescent_peer_preference_only_applies_to_observe_peer()
	test_observation_peer_utility_prefers_non_parent_with_neutral_memory()
	test_positive_peer_memory_can_override_adolescent_preference()
	test_negative_peer_memory_can_lower_a_non_parent_score()
	test_old_peer_memory_decays_below_adolescent_preference()
	test_observation_peer_utility_filters_invalid_candidates_and_ties_stably()
	await test_adolescent_world_uses_memory_when_selecting_observation_target()
	await test_child_observer_prefers_visible_parent_then_falls_back_to_nearest_peer()
	await test_child_witnessed_learning_is_scaled_for_positive_and_negative_events()
	await test_observation_requires_range_visibility_and_attention()
	await test_observed_success_and_feedback_teach_matching_action()
	await test_contested_object_completes_once()
	await test_focus_routes_actions_only_to_selected_norn()
	await test_invalid_focus_id_is_ignored()
	await test_unfocused_norn_keeps_simulating()
	if _save_backup_ok:
		await test_version5_round_trip_preserves_both_profiles()
		await test_v1_migration_preserves_mallow_and_seeds_moss()
		await test_v2_migration_preserves_mallow_and_seeds_moss()
		await test_v3_migration_preserves_mallow_and_seeds_moss()
		await test_malformed_v4_save_uses_safe_reset()
	else:
		_expect(false, "save tests can preserve the existing local save")
	_restore_original_save()
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


func test_world_spawns_two_independent_norns() -> void:
	var world = await _create_social_world()
	if not world.has_method("profile_for"):
		_expect(false, "world exposes profiles for both Norns")
		await _destroy_social_world(world)
		return
	var mallow = world.call("profile_for", "mallow")
	var moss = world.call("profile_for", "moss")
	_expect(mallow != null and moss != null, "world creates Mallow and Moss profiles")
	if mallow == null or moss == null:
		await _destroy_social_world(world)
		return
	_expect(mallow.get("actor_id") == "mallow" and moss.get("actor_id") == "moss", "world profiles have stable IDs")
	_expect(mallow.get("actor") != moss.get("actor"), "each profile owns a different actor")
	var mallow_cognition: Dictionary = mallow.get("cognition_state")
	var moss_cognition: Dictionary = moss.get("cognition_state")
	var moss_hunger := float(moss_cognition["chemistry"]["hunger"])
	var mallow_hunger := float(mallow_cognition["chemistry"]["hunger"])
	mallow_cognition["chemistry"]["hunger"] = 12.0
	_expect(float(moss_cognition["chemistry"]["hunger"]) == moss_hunger, "each profile owns separate cognition")
	mallow_cognition["chemistry"]["hunger"] = mallow_hunger
	var mallow_biochemistry: Dictionary = mallow.get("biochemistry_state")
	var moss_biochemistry: Dictionary = moss.get("biochemistry_state")
	var moss_atp := float(moss_biochemistry["compounds"]["ATP"])
	var mallow_atp := float(mallow_biochemistry["compounds"]["ATP"])
	mallow_biochemistry["compounds"]["ATP"] = 1.0
	_expect(float(moss_biochemistry["compounds"]["ATP"]) == moss_atp, "each profile owns separate biochemistry")
	mallow_biochemistry["compounds"]["ATP"] = mallow_atp
	var mallow_language: Dictionary = mallow.get("language_state")
	var moss_language: Dictionary = moss.get("language_state")
	mallow_language["words"]["fruit"] = {"word": "fruit", "targetId": "fruit", "confidence": 0.38}
	_expect((moss_language["words"] as Dictionary).is_empty(), "each profile owns separate language")
	mallow_language["words"].clear()
	_expect(int(mallow_cognition.get("seed", -1)) == 4181996 and int(moss_cognition.get("seed", -1)) == 4181997, "profiles use their deterministic seeds")
	_expect(float(mallow_cognition["traits"]["sociability"]) == 0.55 and float(moss_cognition["traits"]["sociability"]) == 0.85, "profiles use distinct sociability traits")
	_expect((moss.get("actor") as Node3D).global_position.distance_to(Vector3(6.2, 0.0, 1.6)) < 0.05, "Moss starts at the planned habitat position")
	var initial_peers: Array = world.call("_sense_peers", mallow)
	_expect(initial_peers.size() == 1 and initial_peers[0].get("id", "") == "moss", "the starting habitat positions produce visible peer input")
	world.call("toggle_pause")
	_expect(not (mallow.get("actor") as NornActor).is_physics_processing() and not (moss.get("actor") as NornActor).is_physics_processing(), "global pause stops both Norns")
	world.call("toggle_pause")
	_expect((mallow.get("actor") as NornActor).is_physics_processing() and (moss.get("actor") as NornActor).is_physics_processing(), "global resume restarts both Norns")
	await _destroy_social_world(world)


func test_peer_perception_filters_distance_and_occlusion() -> void:
	var world = await _create_social_world()
	if not world.has_method("_sense_peers") or not world.has_method("profile_for"):
		_expect(false, "world provides bounded line-of-sight peer perception")
		await _destroy_social_world(world)
		return
	var mallow = world.call("profile_for", "mallow")
	var moss = world.call("profile_for", "moss")
	var mallow_actor: NornActor = mallow.get("actor")
	var moss_actor: NornActor = moss.get("actor")
	mallow_actor.global_position = Vector3.ZERO
	moss_actor.global_position = Vector3(8.0, 0.0, 0.0)
	await physics_frame
	var peers: Array = world.call("_sense_peers", mallow)
	_expect(peers.size() == 1 and peers[0].get("id", "") == "moss", "visible peer inside the sense radius is perceived")
	moss_actor.global_position = Vector3(11.0, 0.0, 0.0)
	await physics_frame
	peers = world.call("_sense_peers", mallow)
	_expect(peers.is_empty(), "peer outside the ten-unit sense radius is excluded")
	moss_actor.global_position = Vector3(5.0, 0.0, 0.0)
	var wall := StaticBody3D.new()
	wall.name = "PeerOccluder"
	wall.collision_layer = 1
	wall.collision_mask = 0
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(0.35, 2.0, 2.0)
	wall_shape.shape = wall_box
	wall.position = Vector3(2.5, 1.25, 0.0)
	wall.add_child(wall_shape)
	world.add_child(wall)
	await physics_frame
	peers = world.call("_sense_peers", mallow)
	_expect(peers.is_empty(), "occluded peer is excluded from perception")
	wall.queue_free()
	await _destroy_social_world(world)


func test_shared_object_sensing_filters_distance_and_occlusion() -> void:
	var world = await _create_social_world()
	if not world.has_method("_sense_objects") or not world.has_method("profile_for"):
		_expect(false, "world builds visible-object input independently of Area overlap caches")
		await _destroy_social_world(world)
		return
	world.set_process(false)
	var mallow = world.call("profile_for", "mallow")
	var mallow_actor: NornActor = mallow.get("actor")
	mallow_actor.set_physics_process(false)
	var moss_actor: NornActor = world.call("profile_for", "moss").get("actor")
	moss_actor.set_physics_process(false)
	mallow_actor.global_position = Vector3.ZERO
	moss_actor.global_position = Vector3(4.0, 0.0, -1.2)
	mallow_actor.get_node("LocalSensor").monitoring = false
	var visible_objects: Array = world.call("_sense_objects", mallow)
	_expect(visible_objects.any(func(entry: Dictionary) -> bool: return entry.get("id", "") == "fruit"), "available fruit inside the sense radius is perceived")
	_expect(visible_objects.any(func(entry: Dictionary) -> bool: return entry.get("id", "") == "spinner"), "available spinner inside the sense radius is perceived without the Area cache")
	_expect(mallow_actor.can_see_interactable(world.get("objects")["spinner"]), "a peer standing in front of an object does not block object perception")
	var spinner: Interactable = world.get("objects")["spinner"]
	spinner.global_position = Vector3(11.0, 0.0, 0.0)
	visible_objects = world.call("_sense_objects", mallow)
	_expect(not visible_objects.any(func(entry: Dictionary) -> bool: return entry.get("id", "") == "spinner"), "object outside the ten-unit sense radius is excluded")
	spinner.global_position = Vector3(6.0, 0.0, 0.0)
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(0.35, 2.0, 2.0)
	wall_shape.shape = wall_box
	wall.position = Vector3(3.0, 1.2, 0.0)
	wall.add_child(wall_shape)
	world.add_child(wall)
	await physics_frame
	visible_objects = world.call("_sense_objects", mallow)
	_expect(not visible_objects.any(func(entry: Dictionary) -> bool: return entry.get("id", "") == "spinner"), "object occluded by habitat geometry is excluded")
	await _destroy_social_world(world)


func test_peer_comfort_rises_and_decays() -> void:
	var world = await _create_social_world()
	if not world.has_method("_step_profile_chemistry") or not world.has_method("profile_for"):
		_expect(false, "each profile advances chemistry using sensed peers")
		await _destroy_social_world(world)
		return
	var mallow = world.call("profile_for", "mallow")
	var moss = world.call("profile_for", "moss")
	var moss_actor: NornActor = moss.get("actor")
	var mallow_profile: Object = mallow
	var mallow_compounds := Biochemistry.read_compounds(mallow_profile.get("biochemistry_state"))
	var starting_comfort := float(mallow_compounds["socialComfort"])
	for _step in range(40):
		world.call("_step_profile_chemistry", mallow_profile)
	var nearby_compounds := Biochemistry.read_compounds(mallow_profile.get("biochemistry_state"))
	var nearby_comfort := float(nearby_compounds["socialComfort"])
	_expect(nearby_comfort > starting_comfort, "peer proximity raises the observer's social comfort")
	moss_actor.global_position = Vector3(30.0, 0.0, 30.0)
	await physics_frame
	for _step in range(100):
		world.call("_step_profile_chemistry", mallow_profile)
	var separated_compounds := Biochemistry.read_compounds(mallow_profile.get("biochemistry_state"))
	_expect(float(separated_compounds["socialComfort"]) < nearby_comfort, "social comfort decays after the peer leaves")
	await _destroy_social_world(world)


func test_social_attention_selects_observation_when_needs_are_settled() -> void:
	var low_state := Cognition.create_state(431, {"curiosity": 0.5, "sociability": 0.0}, {"hunger": 10.0, "curiosity": 5.0, "fatigue": 5.0})
	var high_state := Cognition.create_state(431, {"curiosity": 0.5, "sociability": 0.85}, {"hunger": 10.0, "curiosity": 5.0, "fatigue": 5.0})
	var peer := [{"id": "mallow", "distance": 2.0}]
	var settled_observation := {"time": 1.0, "nearbyNorns": peer}
	var low_decision: Dictionary = Cognition.preview(low_state, settled_observation)
	var high_decision: Dictionary = Cognition.preview(high_state, settled_observation)
	_expect(float(high_decision["actionScores"]["observe_peer"]) > float(low_decision["actionScores"]["observe_peer"]), "higher sociability increases the observe-peer need")
	_expect(high_decision.get("actionId", "") == "observe_peer", "social attention wins when needs are settled")
	var hungry_state := Cognition.create_state(431, {"curiosity": 0.5, "sociability": 0.85}, {"hunger": 90.0, "curiosity": 5.0, "fatigue": 5.0})
	var food_observation := {"time": 1.0, "nearbyNorns": peer, "nearbyObjects": [{"id": "fruit", "distance": 1.0}]}
	var hungry_decision: Dictionary = Cognition.preview(hungry_state, food_observation)
	_expect(hungry_decision.get("actionId", "") == "fruit", "urgent food need takes priority over social observation")
	var tired_state := Cognition.create_state(431, {"curiosity": 0.5, "sociability": 0.85}, {"hunger": 5.0, "curiosity": 5.0, "fatigue": 100.0})
	var tired_decision: Dictionary = Cognition.preview(tired_state, settled_observation)
	_expect(tired_decision.get("actionId", "") == "rest", "urgent rest need takes priority over social observation")


func test_observer_stays_settled_inside_stop_distance() -> void:
	var world = await _create_social_world()
	world.set_process(false)
	var mallow = world.call("profile_for", "mallow")
	var moss = world.call("profile_for", "moss")
	var mallow_actor: NornActor = mallow.get("actor")
	var moss_actor: NornActor = moss.get("actor")
	var moss_cognition := Cognition.create_state(4181997, {"curiosity": 0.5, "sociability": 0.85}, {"hunger": 0.0, "curiosity": 0.0, "fatigue": 2.0})
	var moss_biochemistry := Biochemistry.create_state(moss_cognition["chemistry"])
	Cognition.sync_chemistry(moss_cognition, Biochemistry.read_signals(moss_biochemistry))
	(moss_cognition["actionAssociations"] as Dictionary)["fruit"] = 0.5
	(moss_cognition["actionAssociations"] as Dictionary)["spinner"] = 0.5
	moss.set("cognition_state", moss_cognition)
	moss.set("biochemistry_state", moss_biochemistry)
	moss_actor.global_position = mallow_actor.global_position + Vector3(1.8, 0.0, 0.0)
	await physics_frame
	world.call("_run_decision", moss)
	_expect(moss_actor.current_action == "observe_peer", "nearby settled Norn keeps the observation decision")
	_expect(moss_actor.target == null and not moss_actor.is_walking, "nearby observer does not reacquire a movement target inside stop distance")
	await _destroy_social_world(world)


func test_baby_follows_nearest_living_parent_and_resumes_after_separation() -> void:
	var world = await _create_social_world()
	world.set_process(false)
	var mallow = world.call("profile_for", "mallow")
	var moss = world.call("profile_for", "moss")
	var mallow_actor: NornActor = mallow.get("actor")
	var moss_actor: NornActor = moss.get("actor")
	mallow_actor.set_physics_process(false)
	moss_actor.set_physics_process(false)
	mallow_actor.reset_position(Vector3.ZERO)
	moss_actor.reset_position(Vector3(8.0, 0.0, 0.0))
	var baby = await _add_test_child_profile(world, "norn-1", ["mallow", "moss"], 0.0, Vector3(5.6, 0.0, 0.0), 901)
	var baby_actor: NornActor = baby.get("actor")
	var nearer_peer = await _add_test_child_profile(world, "norn-2", [], 600.0, Vector3(5.6, 0.0, 1.3), 903)
	nearer_peer.get("actor").set_physics_process(false)
	var baby_cognition: Dictionary = baby.get("cognition_state")
	baby_cognition["actionAssociations"]["idle"] = 1.0
	baby.set("cognition_state", baby_cognition)
	await physics_frame
	world.call("_run_decision", baby)
	_expect(str(baby_actor.current_action) == "observe_peer", "a baby uses the existing peer-follow action")
	_expect(baby_actor.target == moss_actor and baby_actor.target_id == "moss", "a baby follows its nearest living parent")
	_expect(str(baby_actor.action_reason).contains("Moss"), "the baby's follow reason identifies its parent")
	for _frame in range(240):
		if baby_actor.target == null and not baby_actor.is_walking:
			break
		await physics_frame
	_expect(baby_actor.target == null and not baby_actor.is_walking and baby_actor.global_position.distance_to(moss_actor.global_position) <= 2.2, "a baby settles at the existing peer stop distance")
	mallow_actor.global_position = Vector3(-20.0, 0.0, 0.0)
	moss_actor.global_position += Vector3(5.0, 0.0, 0.0)
	await physics_frame
	world.call("_run_decision", baby)
	await physics_frame
	_expect(baby_actor.target == moss_actor and baby_actor.is_walking, "a baby resumes following its chosen parent when they move away")
	await _destroy_social_world(world)


func test_baby_follow_respects_priorities_and_orphan_fallback() -> void:
	var world = await _create_social_world()
	world.set_process(false)
	var mallow = world.call("profile_for", "mallow")
	var moss = world.call("profile_for", "moss")
	var mallow_actor: NornActor = mallow.get("actor")
	var moss_actor: NornActor = moss.get("actor")
	mallow_actor.set_physics_process(false)
	moss_actor.set_physics_process(false)
	mallow_actor.reset_position(Vector3.ZERO)
	moss_actor.reset_position(Vector3(12.0, 0.0, 0.0))
	var baby = await _add_test_child_profile(world, "norn-1", ["mallow"], 0.0, Vector3(5.0, 0.0, 0.0), 902)
	var baby_actor: NornActor = baby.get("actor")
	baby.set("guidance", {"objectId": "fruit", "expiresAt": 10.0})
	world.call("_run_decision", baby)
	_expect(baby_actor.current_action == "fruit" and baby_actor.target == world.get("objects")["fruit"], "player guidance takes priority over baby parent following")
	baby.set("guidance", {})
	var hungry_cognition := Cognition.create_state(903, {"curiosity": 0.5, "sociability": 0.5}, {"hunger": 100.0, "curiosity": 0.0, "fatigue": 0.0})
	baby.set("cognition_state", hungry_cognition)
	world.call("_run_decision", baby)
	_expect(baby_actor.current_action == "fruit", "a baby's fruit decision takes priority over parent following")
	var tired_cognition := Cognition.create_state(904, {"curiosity": 0.5, "sociability": 0.5}, {"hunger": 0.0, "curiosity": 0.0, "fatigue": 100.0})
	baby.set("cognition_state", tired_cognition)
	world.call("_run_decision", baby)
	_expect(baby_actor.current_action == "rest", "a baby's rest decision takes priority over parent following")
	baby.set("cognition_state", Cognition.create_state(905, {"curiosity": 0.5, "sociability": 0.5}, {"hunger": 0.0, "curiosity": 0.0, "fatigue": 0.0}))
	var idle_cognition: Dictionary = baby.get("cognition_state")
	idle_cognition["actionAssociations"]["idle"] = 1.0
	baby.set("cognition_state", idle_cognition)
	var dead_actor: NornActor = mallow.get("actor")
	dead_actor.set_physics_process(false)
	dead_actor.queue_free()
	mallow.set("actor", null)
	mallow.get("life_state")["alive"] = false
	moss_actor.global_position = Vector3(30.0, 0.0, 0.0)
	await process_frame
	await physics_frame
	world.call("_run_decision", baby)
	_expect(baby_actor.target == null and baby_actor.current_action == "idle", "a baby without a living parent falls back to its own cognition")
	await _destroy_social_world(world)


func test_adolescent_observer_prefers_nearest_visible_non_parent_and_falls_back() -> void:
	var world = await _create_social_world()
	world.set_process(false)
	var mallow = world.call("profile_for", "mallow")
	var moss = world.call("profile_for", "moss")
	var mallow_actor: NornActor = mallow.get("actor")
	var moss_actor: NornActor = moss.get("actor")
	mallow_actor.set_physics_process(false)
	moss_actor.set_physics_process(false)
	mallow_actor.reset_position(Vector3(0.0, 0.0, 3.0))
	moss_actor.reset_position(Vector3(4.2, 0.0, 0.0))
	var adolescent = await _add_test_child_profile(world, "norn-1", ["mallow"], 240.0, Vector3.ZERO, 916)
	var additional_peer = await _add_test_child_profile(world, "norn-2", [], 600.0, Vector3(-5.0, 0.0, 0.0), 917)
	var adolescent_actor: NornActor = adolescent.get("actor")
	var additional_peer_actor: NornActor = additional_peer.get("actor")
	adolescent_actor.set_physics_process(false)
	additional_peer_actor.set_physics_process(false)
	var cognition := Cognition.create_state(918, {"curiosity": 0.5, "sociability": 1.0}, {"hunger": 0.0, "curiosity": 0.0, "fatigue": 0.0})
	cognition["chemistry"]["socialComfort"] = 10.0
	adolescent.set("cognition_state", cognition)
	await physics_frame
	world.call("_run_decision", adolescent)
	_expect(adolescent.get("life_stage") == "adolescent" and adolescent_actor.current_action == "observe_peer", "a settled adolescent can decide to observe a peer")
	_expect(adolescent_actor.target == moss_actor and adolescent_actor.target_id == "moss", "an adolescent chooses its nearest visible non-parent even when its parent is closer")
	_expect(adolescent_actor.action_reason.contains("Moss"), "the adolescent's observation reason identifies the selected peer")
	moss_actor.global_position = Vector3(20.0, 0.0, 0.0)
	additional_peer_actor.global_position = Vector3(-25.0, 0.0, 0.0)
	await physics_frame
	world.call("_run_decision", adolescent)
	_expect(adolescent_actor.target == mallow_actor and adolescent_actor.target_id == "mallow", "an adolescent falls back to its nearest visible peer when no non-parent is sensed")
	await _destroy_social_world(world)


func test_adolescent_peer_preference_only_applies_to_observe_peer() -> void:
	var world = await _create_social_world()
	world.set_process(false)
	var mallow = world.call("profile_for", "mallow")
	var moss = world.call("profile_for", "moss")
	var mallow_actor: NornActor = mallow.get("actor")
	var moss_actor: NornActor = moss.get("actor")
	mallow_actor.set_physics_process(false)
	moss_actor.set_physics_process(false)
	mallow_actor.reset_position(Vector3(3.0, 0.0, 0.0))
	moss_actor.reset_position(Vector3(4.2, 0.0, 0.0))
	var adolescent = await _add_test_child_profile(world, "norn-1", ["mallow"], 240.0, Vector3.ZERO, 919)
	var adolescent_actor: NornActor = adolescent.get("actor")
	adolescent_actor.set_physics_process(false)
	adolescent.set("guidance", {"objectId": "fruit", "expiresAt": 10.0})
	world.call("_run_decision", adolescent)
	_expect(adolescent_actor.current_action == "fruit" and adolescent_actor.target == world.get("objects")["fruit"], "player guidance keeps priority over adolescent peer preference")
	adolescent.set("guidance", {})
	adolescent.set("cognition_state", Cognition.create_state(920, {"curiosity": 0.5, "sociability": 1.0}, {"hunger": 100.0, "curiosity": 0.0, "fatigue": 0.0}))
	world.call("_run_decision", adolescent)
	_expect(adolescent_actor.current_action == "fruit", "an adolescent's urgent fruit decision keeps priority over peer preference")
	adolescent.set("cognition_state", Cognition.create_state(921, {"curiosity": 1.0, "sociability": 1.0}, {"hunger": 0.0, "curiosity": 100.0, "fatigue": 0.0}))
	world.call("_run_decision", adolescent)
	_expect(adolescent_actor.current_action == "spinner", "an adolescent's urgent spinner decision keeps priority over peer preference")
	adolescent.set("cognition_state", Cognition.create_state(922, {"curiosity": 0.5, "sociability": 1.0}, {"hunger": 0.0, "curiosity": 0.0, "fatigue": 100.0}))
	world.call("_run_decision", adolescent)
	_expect(adolescent_actor.current_action == "rest", "an adolescent's urgent rest decision keeps priority over peer preference")
	await _destroy_social_world(world)


func test_observation_peer_utility_prefers_non_parent_with_neutral_memory() -> void:
	var state := Cognition.create_state(930)
	var candidates: Array[Dictionary] = [
		{"id": "mallow", "name": "Mallow", "distance": 3.0},
		{"id": "moss", "name": "Moss", "distance": 4.2}
	]
	var parent_ids: Array[String] = ["mallow"]
	var selection := _select_observation_peer_for_test(state, candidates, parent_ids, "adolescent", 100.0)
	_expect(selection.get("peerId", "") == "moss", "neutral peer memory leaves the adolescent's non-parent preference strong enough to win")
	var parent_score := _peer_score(selection, "mallow")
	var peer_score := _peer_score(selection, "moss")
	_expect(is_equal_approx(float(parent_score.get("proximity", -1.0)), 0.70) and is_equal_approx(float(peer_score.get("proximity", -1.0)), 0.58), "peer utility reports normalized proximity scores from the 10-unit sensor radius")
	_expect(is_equal_approx(float(parent_score.get("total", -1.0)), 0.70) and is_equal_approx(float(peer_score.get("total", -1.0)), 0.83), "neutral memory leaves the 0.25 adolescent preference in the peer's total score")


func test_positive_peer_memory_can_override_adolescent_preference() -> void:
	var state := Cognition.create_state(931)
	_record_observation_peer_memory(state, "mallow", "observe", "", 100.0, 6)
	var candidates: Array[Dictionary] = [
		{"id": "mallow", "name": "Mallow", "distance": 3.0},
		{"id": "moss", "name": "Moss", "distance": 4.2}
	]
	var parent_ids: Array[String] = ["mallow"]
	var selection := _select_observation_peer_for_test(state, candidates, parent_ids, "adolescent", 100.0)
	_expect(selection.get("peerId", "") == "mallow", "strong recent positive memories can outweigh the adolescent non-parent preference")
	var parent_score := _peer_score(selection, "mallow")
	_expect(is_equal_approx(float(parent_score.get("memory", -1.0)), 0.35) and is_equal_approx(float(parent_score.get("total", -1.0)), 1.05), "repeated positive social memories saturate at the bounded parent memory score")


func test_negative_peer_memory_can_lower_a_non_parent_score() -> void:
	var state := Cognition.create_state(932)
	_record_observation_peer_memory(state, "moss", "observe-feedback", "scold", 100.0, 6)
	var candidates: Array[Dictionary] = [
		{"id": "mallow", "name": "Mallow", "distance": 3.0},
		{"id": "moss", "name": "Moss", "distance": 4.2}
	]
	var parent_ids: Array[String] = ["mallow"]
	var selection := _select_observation_peer_for_test(state, candidates, parent_ids, "adolescent", 100.0)
	_expect(selection.get("peerId", "") == "mallow", "strong recent negative memories can make an adolescent avoid its non-parent preference")
	var peer_score := _peer_score(selection, "moss")
	_expect(is_equal_approx(float(peer_score.get("memory", 1.0)), -0.35) and is_equal_approx(float(peer_score.get("total", 1.0)), 0.48), "negative social memory lowers the non-parent's score within the configured bound")


func test_old_peer_memory_decays_below_adolescent_preference() -> void:
	var state := Cognition.create_state(933)
	_record_observation_peer_memory(state, "mallow", "observe", "", 0.0, 6)
	var candidates: Array[Dictionary] = [
		{"id": "mallow", "name": "Mallow", "distance": 3.0},
		{"id": "moss", "name": "Moss", "distance": 4.2}
	]
	var parent_ids: Array[String] = ["mallow"]
	var selection := _select_observation_peer_for_test(state, candidates, parent_ids, "adolescent", 720.0)
	_expect(selection.get("peerId", "") == "moss", "positive memories four half-lives old no longer overcome the adolescent preference")
	var parent_score := _peer_score(selection, "mallow")
	_expect(is_equal_approx(float(parent_score.get("memory", -1.0)), 0.0240625), "the decayed social memory score follows the 180-second half-life and familiarity factor")


func test_observation_peer_utility_filters_invalid_candidates_and_ties_stably() -> void:
	var state := Cognition.create_state(934)
	var candidates: Array[Dictionary] = [
		{"id": "norn-2", "name": "Norn Two", "distance": 4.0},
		{"id": "moss", "name": "Moss", "distance": 4.0},
		{"id": "", "name": "Missing ID", "distance": 0.1},
		{"id": "infinite", "name": "Infinite Distance", "distance": INF},
		{"id": "negative", "name": "Negative Distance", "distance": -0.5},
		{"name": "No ID", "distance": 0.2},
		{"id": "nonnumeric", "name": "Bad Distance", "distance": "near"}
	]
	var no_parents: Array[String] = []
	var selection := _select_observation_peer_for_test(state, candidates, no_parents, "adolescent", 100.0)
	_expect(selection.get("peerId", "") == "moss", "equal peer scores resolve by stable actor ID instead of incoming array order")
	var scores: Array = selection.get("scores", [])
	_expect(scores.size() == 2, "malformed peer IDs and distances are excluded from the score breakdown")
	var reversed: Array[Dictionary] = [candidates[1], candidates[0]]
	var reversed_selection := _select_observation_peer_for_test(state, reversed, no_parents, "adolescent", 100.0)
	_expect(reversed_selection.get("peerId", "") == "moss", "stable peer tie resolution is independent of candidate order")
	var empty_selection := _select_observation_peer_for_test(state, [], no_parents, "adolescent", 100.0)
	_expect(empty_selection.is_empty(), "an empty candidate list leaves the existing world fallback available")


func test_adolescent_world_uses_memory_when_selecting_observation_target() -> void:
	var world = await _create_social_world()
	world.set_process(false)
	var mallow = world.call("profile_for", "mallow")
	var moss = world.call("profile_for", "moss")
	var mallow_actor: NornActor = mallow.get("actor")
	var moss_actor: NornActor = moss.get("actor")
	mallow_actor.set_physics_process(false)
	moss_actor.set_physics_process(false)
	mallow_actor.reset_position(Vector3(0.0, 0.0, 3.0))
	moss_actor.reset_position(Vector3(4.2, 0.0, 0.0))
	var adolescent = await _add_test_child_profile(world, "norn-1", ["mallow"], 240.0, Vector3.ZERO, 935)
	var adolescent_actor: NornActor = adolescent.get("actor")
	adolescent_actor.set_physics_process(false)
	var cognition := Cognition.create_state(936, {"curiosity": 0.5, "sociability": 1.0}, {"hunger": 0.0, "curiosity": 0.0, "fatigue": 0.0})
	cognition["chemistry"]["socialComfort"] = 10.0
	_record_observation_peer_memory(cognition, "mallow", "observe", "", 0.0, 6)
	adolescent.set("cognition_state", cognition)
	await physics_frame
	await physics_frame
	world.call("_run_decision", adolescent)
	_expect(adolescent_actor.current_action == "observe_peer" and adolescent_actor.target == mallow_actor and adolescent_actor.target_id == "mallow", "the world uses positive peer memory after cognition chooses adolescent observation")
	_expect(adolescent_actor.action_reason.contains("Mallow") and adolescent_actor.action_reason.to_lower().contains("remember"), "the memory-driven target reason names Mallow and explains why it was selected")
	await _destroy_social_world(world)


func test_child_observer_prefers_visible_parent_then_falls_back_to_nearest_peer() -> void:
	var world = await _create_social_world()
	world.set_process(false)
	var mallow = world.call("profile_for", "mallow")
	var moss = world.call("profile_for", "moss")
	var mallow_actor: NornActor = mallow.get("actor")
	var moss_actor: NornActor = moss.get("actor")
	mallow_actor.set_physics_process(false)
	moss_actor.set_physics_process(false)
	mallow_actor.reset_position(Vector3(5.0, 0.0, 0.0))
	moss_actor.reset_position(Vector3(1.8, 0.0, 2.0))
	var child = await _add_test_child_profile(world, "norn-1", ["mallow"], 120.0, Vector3.ZERO, 906)
	var child_actor: NornActor = child.get("actor")
	var child_cognition := Cognition.create_state(907, {"curiosity": 0.5, "sociability": 1.0}, {"hunger": 0.0, "curiosity": 0.0, "fatigue": 0.0})
	child_cognition["chemistry"]["socialComfort"] = 10.0
	child.set("cognition_state", child_cognition)
	await physics_frame
	world.call("_run_decision", child)
	_expect(child_actor.current_action == "observe_peer", "a settled child can decide to observe a nearby peer")
	_expect(child_actor.target == mallow_actor and child_actor.target_id == "mallow", "a child prefers its visible parent over a closer non-parent")
	child_actor.reset_position(Vector3.ZERO)
	mallow_actor.global_position = Vector3(20.0, 0.0, 0.0)
	moss_actor.global_position = Vector3(1.8, 0.0, 2.0)
	await physics_frame
	world.call("_run_decision", child)
	_expect(child_actor.current_action == "observe_peer" and child_actor.target == moss_actor and child_actor.target_id == "moss", "a child falls back to its nearest visible peer when no parent is sensed")
	await _destroy_social_world(world)


func test_child_witnessed_learning_is_scaled_for_positive_and_negative_events() -> void:
	var world = await _create_social_world()
	world.set_process(false)
	var mallow = world.call("profile_for", "mallow")
	var moss = world.call("profile_for", "moss")
	var mallow_actor: NornActor = mallow.get("actor")
	var moss_actor: NornActor = moss.get("actor")
	mallow_actor.set_physics_process(false)
	moss_actor.set_physics_process(false)
	mallow_actor.reset_position(Vector3.ZERO)
	moss_actor.reset_position(Vector3(-2.0, 0.0, 0.0))
	var child = await _add_test_child_profile(world, "norn-1", ["mallow"], 120.0, Vector3(2.0, 0.0, 0.0), 910)
	var child_actor: NornActor = child.get("actor")
	var child_cognition := Cognition.create_state(911, {"curiosity": 0.5, "sociability": 0.5}, {"hunger": 10.0, "curiosity": 10.0, "fatigue": 5.0})
	var adult_cognition := Cognition.create_state(912, {"curiosity": 0.5, "sociability": 0.5}, {"hunger": 10.0, "curiosity": 10.0, "fatigue": 5.0})
	var child_biochemistry := Biochemistry.create_state(child_cognition["chemistry"])
	var adult_biochemistry := Biochemistry.create_state(adult_cognition["chemistry"])
	Cognition.sync_chemistry(child_cognition, Biochemistry.read_signals(child_biochemistry))
	Cognition.sync_chemistry(adult_cognition, Biochemistry.read_signals(adult_biochemistry))
	child.set("cognition_state", child_cognition)
	child.set("biochemistry_state", child_biochemistry)
	moss.set("cognition_state", adult_cognition)
	moss.set("biochemistry_state", adult_biochemistry)
	child_actor.set_physics_process(false)
	child_actor.set_action_target(null, "observe_peer", "Watching Mallow", "mallow")
	moss_actor.set_action_target(null, "observe_peer", "Watching Mallow", "mallow")
	await process_frame
	await physics_frame
	var expected_child_cognition: Dictionary = child_cognition.duplicate(true)
	var expected_adult_cognition: Dictionary = adult_cognition.duplicate(true)
	var expected_child_biochemistry: Dictionary = child_biochemistry.duplicate(true)
	var expected_adult_biochemistry: Dictionary = adult_biochemistry.duplicate(true)
	var positive_event := {"eventType": "observe", "actorId": "mallow", "actionId": "fruit", "targetId": "fruit", "time": 1.0, "peerCount": 1, "sociability": 0.5, "learningMultiplier": 1.5}
	var adult_positive_event := positive_event.duplicate(true)
	adult_positive_event["learningMultiplier"] = 1.0
	var expected_child_positive: Dictionary = _expected_observation_update(expected_child_cognition, expected_child_biochemistry, positive_event)
	var expected_adult_positive: Dictionary = _expected_observation_update(expected_adult_cognition, expected_adult_biochemistry, adult_positive_event)
	world.call("_offer_observation", mallow, {"eventType": "food", "actorId": "mallow", "actionId": "fruit", "targetId": "fruit", "time": 1.0, "eventId": 1})
	_expect(is_equal_approx(float(expected_child_positive.get("learningDelta", 0.0)), float(expected_adult_positive.get("learningDelta", 0.0)) * 1.5), "child positive observation learning is 1.5 times the adult baseline")
	_expect(is_equal_approx(float(child_cognition["actionAssociations"]["fruit"]), float(expected_child_cognition["actionAssociations"]["fruit"])) and is_equal_approx(float(adult_cognition["actionAssociations"]["fruit"]), float(expected_adult_cognition["actionAssociations"]["fruit"])), "the world applies the age-scaled and baseline positive learning updates")
	var expected_child_negative: Dictionary = _expected_observation_update(expected_child_cognition, expected_child_biochemistry, {"eventType": "observe-feedback", "actorId": "mallow", "actionId": "fruit", "targetId": "fruit", "feedback": "scold", "time": 2.0, "peerCount": 1, "sociability": 0.5, "learningMultiplier": 1.5})
	var expected_adult_negative: Dictionary = _expected_observation_update(expected_adult_cognition, expected_adult_biochemistry, {"eventType": "observe-feedback", "actorId": "mallow", "actionId": "fruit", "targetId": "fruit", "feedback": "scold", "time": 2.0, "peerCount": 1, "sociability": 0.5, "learningMultiplier": 1.0})
	world.call("_offer_observation", mallow, {"eventType": "scold", "feedback": "scold", "actorId": "mallow", "actionId": "fruit", "targetId": "fruit", "time": 2.0, "eventId": 2})
	_expect(is_equal_approx(float(expected_child_negative.get("learningDelta", 0.0)), float(expected_adult_negative.get("learningDelta", 0.0)) * 1.5), "child negative observation learning is 1.5 times the adult baseline")
	_expect(is_equal_approx(float(child_cognition["actionAssociations"]["fruit"]), float(expected_child_cognition["actionAssociations"]["fruit"])) and is_equal_approx(float(adult_cognition["actionAssociations"]["fruit"]), float(expected_adult_cognition["actionAssociations"]["fruit"])), "the world applies the age-scaled and baseline negative learning updates")
	var direct_state := Cognition.create_state(913)
	var direct_result: Dictionary = Cognition.record_outcome(direct_state, {"eventType": "food", "actionId": "fruit", "learningMultiplier": 1.5})
	_expect(is_equal_approx(float(direct_result.get("learningDelta", 0.0)), 0.12), "the observation multiplier does not change direct food learning")
	var upper_state := Cognition.create_state(914)
	upper_state["actionAssociations"]["fruit"] = 0.99
	Cognition.record_outcome(upper_state, {"eventType": "observe-feedback", "feedback": "praise", "actionId": "fruit", "sociability": 1.0, "learningMultiplier": 1.5})
	_expect(float(upper_state["actionAssociations"]["fruit"]) <= 1.0, "positive scaled observation learning respects the upper association clamp")
	var lower_state := Cognition.create_state(915)
	lower_state["actionAssociations"]["fruit"] = 0.01
	Cognition.record_outcome(lower_state, {"eventType": "observe-feedback", "feedback": "scold", "actionId": "fruit", "sociability": 1.0, "learningMultiplier": 1.5})
	_expect(float(lower_state["actionAssociations"]["fruit"]) >= 0.0, "negative scaled observation learning respects the lower association clamp")
	await _destroy_social_world(world)


func test_observation_requires_range_visibility_and_attention() -> void:
	var world = await _create_social_world()
	if not world.has_method("_offer_observation") or not world.has_method("profile_for"):
		_expect(false, "world gates witnessed events through social attention")
		await _destroy_social_world(world)
		return
	var mallow = world.call("profile_for", "mallow")
	var moss = world.call("profile_for", "moss")
	var mallow_actor: NornActor = mallow.get("actor")
	var moss_actor: NornActor = moss.get("actor")
	var outcome := {"eventType": "food", "actionId": "fruit", "targetId": "fruit", "actorId": "mallow", "time": 10.0}
	world.call("_offer_observation", mallow, outcome)
	_expect((moss.get("cognition_state")["episodes"] as Array).is_empty(), "unattending Norn does not learn from an event")
	await _set_profile_attending(moss, mallow)
	moss_actor.global_position = mallow_actor.global_position + Vector3(3.2, 0.0, 0.0)
	world.call("_offer_observation", mallow, outcome)
	_expect((moss.get("cognition_state")["episodes"] as Array).is_empty(), "observer outside the three-unit radius does not learn")
	moss_actor.global_position = mallow_actor.global_position + Vector3(2.0, 0.0, 0.0)
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(0.35, 2.0, 2.0)
	wall_shape.shape = wall_box
	wall.position = (mallow_actor.global_position + moss_actor.global_position) * 0.5 + Vector3(0.0, 1.25, 0.0)
	wall.add_child(wall_shape)
	world.add_child(wall)
	await physics_frame
	world.call("_offer_observation", mallow, outcome)
	_expect((moss.get("cognition_state")["episodes"] as Array).is_empty(), "occluded observer does not learn")
	wall.queue_free()
	await physics_frame
	moss_actor.set_action_target(null, "idle", "Not attending")
	world.call("_offer_observation", mallow, outcome)
	_expect((moss.get("cognition_state")["episodes"] as Array).is_empty(), "visible nearby observer learns only while attending")
	await _destroy_social_world(world)


func test_observed_success_and_feedback_teach_matching_action() -> void:
	var world = await _create_social_world()
	if not world.has_method("_offer_observation") or not world.has_method("profile_for"):
		_expect(false, "world records successful actions and eligible feedback for observers")
		await _destroy_social_world(world)
		return
	var mallow = world.call("profile_for", "mallow")
	var moss = world.call("profile_for", "moss")
	var moss_actor: NornActor = moss.get("actor")
	await _set_profile_attending(moss, mallow)
	var moss_state: Dictionary = moss.get("cognition_state")
	var initial_fruit := float(moss_state["actionAssociations"]["fruit"])
	var initial_spinner := float(moss_state["actionAssociations"]["spinner"])
	var food_outcome := {"eventType": "food", "actionId": "fruit", "targetId": "fruit", "actorId": "mallow", "time": 12.5, "eventId": 9, "text": "Mallow ate honey fruit"}
	world.call("_offer_observation", mallow, food_outcome)
	var episodes: Array = moss_state["episodes"]
	_expect(episodes.size() == 1, "attentive observer remembers a successful food action")
	if episodes.size() == 1:
		_expect(episodes[0].get("eventType", "") == "observe" and episodes[0].get("actorId", "") == "mallow", "observation memory names its source")
		_expect(episodes[0].get("actionId", "") == "fruit" and episodes[0].get("targetId", "") == "fruit", "observation memory names the matching action and target")
		_expect(float(episodes[0].get("time", -1.0)) == 12.5 and int(episodes[0]["observation"].get("peerCount", -1)) == 1, "observation memory records time and peer count")
		_expect(absf(float(episodes[0].get("sociability", -1.0)) - 0.85) < 0.001, "observation memory records observer sociability")
	world.call("_run_decision", moss)
	var recalled_observation_found := false
	for recalled: Dictionary in moss.get("recalled_moments"):
		if recalled.get("eventType", "") == "observe" and recalled.get("text", "") == "Moss observed Mallow fruit":
			recalled_observation_found = true
			break
	_expect(recalled_observation_found, "Norn decision exposes retrieved observation episodes to the remembered-moments HUD")
	_expect(float(moss_state["actionAssociations"]["fruit"]) > initial_fruit, "successful witnessed fruit increases the fruit association")
	_expect(is_equal_approx(float(moss_state["actionAssociations"]["spinner"]), initial_spinner), "successful witnessed fruit does not change the spinner association")
	await _set_profile_attending(moss, mallow)
	var praise_outcome := {"eventType": "praise", "actionId": "spinner", "targetId": "spinner", "actorId": "mallow", "time": 13.0, "eventId": 10, "feedback": "praise", "text": "Mallow was praised after spinner"}
	world.call("_offer_observation", mallow, praise_outcome)
	episodes = moss_state["episodes"]
	_expect(episodes.size() == 2, "attentive observer remembers eligible praise")
	if episodes.size() == 2:
		_expect(episodes[1].get("eventType", "") == "observe-feedback" and episodes[1].get("feedback", "") == "praise", "feedback memory keeps its praise outcome")
		_expect(episodes[1].get("actionId", "") == "spinner", "feedback learning remains tied to the praised action")
	_expect(float(moss_state["actionAssociations"]["spinner"]) > initial_spinner, "witnessed praise changes only the matching spinner association")
	_expect(Biochemistry.read_compounds(moss.get("biochemistry_state"))["socialComfort"] > 50.0, "witnessing a social event applies observer biochemistry")
	await _set_profile_attending(moss, mallow)
	var fruit_before_scold := float(moss_state["actionAssociations"]["fruit"])
	var scold_outcome := {"eventType": "scold", "actionId": "fruit", "targetId": "fruit", "actorId": "mallow", "time": 13.5, "eventId": 11, "feedback": "scold", "text": "Mallow was scolded after fruit"}
	world.call("_offer_observation", mallow, scold_outcome)
	episodes = moss_state["episodes"]
	_expect(episodes.size() == 3, "attentive observer remembers eligible scolding")
	if episodes.size() == 3:
		_expect(episodes[2].get("eventType", "") == "observe-feedback" and episodes[2].get("feedback", "") == "scold", "feedback memory keeps its scold outcome")
		_expect(episodes[2].get("actionId", "") == "fruit", "scolding remains tied to the matching fruit action")
	_expect(float(moss_state["actionAssociations"]["fruit"]) < fruit_before_scold, "witnessed scolding lowers only the matching fruit association")
	await _destroy_social_world(world)


func test_contested_object_completes_once() -> void:
	var world = await _create_social_world()
	if not world.has_method("profile_for"):
		_expect(false, "world routes shared interactable completion by actor")
		await _destroy_social_world(world)
		return
	var mallow = world.call("profile_for", "mallow")
	var moss = world.call("profile_for", "moss")
	var mallow_actor: NornActor = mallow.get("actor")
	var moss_actor: NornActor = moss.get("actor")
	var fruit: Interactable = world.get("objects")["fruit"]
	fruit.global_position = Vector3.ZERO
	mallow_actor.global_position = Vector3(-2.0, 0.0, 0.0)
	moss_actor.global_position = Vector3(2.0, 0.0, 0.0)
	mallow_actor.set_action_target(fruit, "fruit", "Eating honey fruit", "fruit")
	moss_actor.set_action_target(fruit, "fruit", "Eating honey fruit", "fruit")
	for _frame in range(90):
		await physics_frame
		var mallow_episodes: Array = mallow.get("cognition_state")["episodes"]
		var moss_episodes: Array = moss.get("cognition_state")["episodes"]
		if _event_count(mallow_episodes, "food") + _event_count(moss_episodes, "food") > 0 and not fruit.available:
			break
	await physics_frame
	var total_food_events := _event_count(mallow.get("cognition_state")["episodes"], "food") + _event_count(moss.get("cognition_state")["episodes"], "food")
	_expect(total_food_events == 1, "shared fruit produces exactly one successful food event")
	_expect(not fruit.available, "the first valid arrival consumes the shared object")
	await _destroy_social_world(world)


func test_focus_routes_actions_only_to_selected_norn() -> void:
	var world = await _create_social_world()
	if not world.has_method("select_norn") or not world.has_method("focused_profile"):
		_expect(false, "world exposes focus selection and focused profile")
		await _destroy_social_world(world)
		return
	var mallow = world.call("profile_for", "mallow")
	var moss = world.call("profile_for", "moss")
	var mallow_actor: NornActor = mallow.get("actor")
	var moss_actor: NornActor = moss.get("actor")
	var mallow_state: Dictionary = mallow.get("cognition_state")
	var moss_state: Dictionary = moss.get("cognition_state")
	var mallow_chemistry_before := Biochemistry.read_compounds(mallow.get("biochemistry_state"))
	var mallow_vocabulary_before: Dictionary = mallow.get("language_state")["words"].duplicate(true)
	var mallow_guidance_before: Dictionary = mallow.get("guidance").duplicate(true)
	var mallow_episode_count := (mallow_state["episodes"] as Array).size()
	moss.set("feedback_available", true)
	moss.set("feedback_action", "fruit")
	moss.set("feedback_target", "fruit")
	moss.set("feedback_time", float(world.get("simulation_time")))
	world.call("select_norn", "moss")
	_expect(world.call("focused_profile").get("actor_id") == "moss", "selecting Moss changes the focused profile")
	var ui: Node = world.get("_ui")
	var focus_label := ui.find_child("FocusNameLabel", true, false) as Label
	var moss_button := ui.find_child("Roster_moss", true, false) as Button
	_expect(focus_label != null and focus_label.text == "Focused: Moss", "HUD identifies the focused Norn")
	_expect(moss_button != null and moss_button.button_pressed, "HUD marks the active focus button")
	world.call("guide_to", "spinner")
	_expect(str(moss.get("guidance").get("objectId", "")) == "spinner", "guidance applies to the focused Norn")
	_expect(mallow.get("guidance") == mallow_guidance_before, "guidance leaves the other Norn unchanged")
	world.call("toggle_teaching_mode")
	world.call("teach_word", "pine", "fruit")
	world.call("toggle_teaching_mode")
	_expect((moss.get("language_state")["words"] as Dictionary).has("pine"), "typed teaching updates the focused Norn's vocabulary")
	_expect(mallow.get("language_state")["words"] == mallow_vocabulary_before, "typed teaching leaves the other Norn's vocabulary unchanged")
	world.call("give_feedback", "praise")
	_expect(str((moss_state["episodes"] as Array).back().get("eventType", "")) == "praise", "Praise updates the focused Norn")
	moss.set("feedback_available", true)
	moss.set("feedback_action", "fruit")
	moss.set("feedback_target", "fruit")
	moss.set("feedback_time", float(world.get("simulation_time")))
	world.call("give_feedback", "scold")
	var moss_episodes: Array = moss_state["episodes"]
	_expect(moss_episodes.size() >= 3 and moss_episodes.back().get("eventType", "") == "scold", "Scold updates the focused Norn's independent feedback window")
	_expect((mallow_state["episodes"] as Array).size() == mallow_episode_count, "focused feedback leaves the other Norn's memories unchanged")
	_expect(Biochemistry.read_compounds(mallow.get("biochemistry_state")) == mallow_chemistry_before, "focused feedback leaves the other Norn's chemistry unchanged")
	_expect(mallow_actor != moss_actor and world.get("norn") == mallow_actor, "Mallow remains the unfocused actor while Moss is selected")
	await _destroy_social_world(world)


func test_invalid_focus_id_is_ignored() -> void:
	var world = await _create_social_world()
	if not world.has_method("select_norn") or not world.has_method("focused_profile"):
		_expect(false, "world validates requested focus IDs")
		await _destroy_social_world(world)
		return
	world.call("select_norn", "moss")
	world.call("select_norn", "unknown")
	_expect(world.call("focused_profile").get("actor_id") == "moss", "invalid focus ID leaves the previous Norn selected")
	await _destroy_social_world(world)


func test_unfocused_norn_keeps_simulating() -> void:
	var world = await _create_social_world()
	if not world.has_method("select_norn") or not world.has_method("profile_for"):
		_expect(false, "world keeps unfocused Norns in the simulation")
		await _destroy_social_world(world)
		return
	world.set_process(false)
	world.call("select_norn", "moss")
	var mallow = world.call("profile_for", "mallow")
	var moss = world.call("profile_for", "moss")
	var mallow_actor: NornActor = mallow.get("actor")
	var start_position := mallow_actor.global_position
	var spinner: Interactable = world.get("objects")["spinner"]
	mallow_actor.set_action_target(spinner, "spinner", "Testing autonomous movement", "spinner")
	for _frame in range(8):
		await physics_frame
	_expect(mallow_actor.global_position.distance_to(start_position) > 0.1, "unfocused Mallow continues moving")
	var before_compounds := Biochemistry.read_compounds(mallow.get("biochemistry_state"))
	world.call("_step_profile_chemistry", mallow)
	var after_compounds := Biochemistry.read_compounds(mallow.get("biochemistry_state"))
	_expect(after_compounds != before_compounds, "unfocused Mallow continues advancing chemistry")
	_expect(world.call("focused_profile").get("actor_id") == "moss", "ongoing simulation does not change focus")
	await _destroy_social_world(world)


func test_version5_round_trip_preserves_both_profiles() -> void:
	var world = await _create_social_world()
	world.set_process(false)
	var mallow = world.call("profile_for", "mallow")
	var moss = world.call("profile_for", "moss")
	var mallow_cognition: Dictionary = mallow.get("cognition_state")
	var moss_cognition: Dictionary = moss.get("cognition_state")
	Cognition.record_outcome(mallow_cognition, {"eventType": "food", "actionId": "fruit", "targetId": "fruit", "time": 1.5, "text": "Mallow ate fruit"})
	Cognition.record_outcome(moss_cognition, {"eventType": "toy", "actionId": "spinner", "targetId": "spinner", "time": 2.5, "text": "Moss played"})
	var mallow_biochemistry: Dictionary = mallow.get("biochemistry_state")
	var moss_biochemistry: Dictionary = moss.get("biochemistry_state")
	Biochemistry.apply_event(mallow_biochemistry, "food")
	Biochemistry.apply_event(moss_biochemistry, "toy")
	Cognition.sync_chemistry(mallow_cognition, Biochemistry.read_signals(mallow_biochemistry))
	Cognition.sync_chemistry(moss_cognition, Biochemistry.read_signals(moss_biochemistry))
	var language: RefCounted = world.get("_language")
	language.call("teach_word", mallow.get("language_state"), "mela", "fruit")
	language.call("teach_word", moss.get("language_state"), "twirl", "spinner")
	mallow.set("feedback_available", true)
	mallow.set("feedback_action", "fruit")
	mallow.set("feedback_target", "fruit")
	mallow.set("feedback_time", 7.25)
	moss.set("feedback_available", true)
	moss.set("feedback_action", "spinner")
	moss.set("feedback_target", "spinner")
	moss.set("feedback_time", 9.5)
	world.set("simulation_time", 10.0)
	world.call("select_norn", "moss")
	var expected_mallow_episodes: Array = mallow_cognition["episodes"].duplicate(true)
	var expected_moss_episodes: Array = moss_cognition["episodes"].duplicate(true)
	var expected_mallow_compounds := Biochemistry.read_compounds(mallow_biochemistry)
	var expected_moss_compounds := Biochemistry.read_compounds(moss_biochemistry)
	var expected_mallow_words: Dictionary = mallow.get("language_state")["words"].duplicate(true)
	var expected_moss_words: Dictionary = moss.get("language_state")["words"].duplicate(true)
	var spinner: Interactable = world.get("objects")["spinner"]
	mallow.get("actor").set_action_target(spinner, "spinner", "Transient before load", "spinner")
	moss.get("actor").set_action_target(spinner, "spinner", "Transient before load", "spinner")
	world.call("save_game")
	var saved := _read_save_record()
	var saved_norns: Dictionary = saved.get("norns", {})
	_expect(int(saved.get("version", -1)) == 5, "saving both profiles writes version 5")
	_expect(saved_norns.has("mallow") and saved_norns.has("moss"), "version-5 save contains both stable profile IDs")
	if saved_norns.has("mallow") and saved_norns.has("moss"):
		for actor_id: String in ["mallow", "moss"]:
			var saved_profile: Dictionary = saved_norns[actor_id]
			_expect(saved_profile.has("cognition") and saved_profile.has("biochemistry") and saved_profile.has("language") and saved_profile.has("feedback"), "%s save contains cognition, biochemistry, language, and feedback" % actor_id.capitalize())
	_expect(str(saved.get("focusedNornId", "")) == "moss", "version-5 save retains the focused Norn")
	_expect(saved.get("seed", -1) == 4181996 and is_equal_approx(float(saved.get("simulationTime", -1.0)), 10.0), "version-5 save retains top-level seed and simulation time")
	(mallow_cognition["episodes"] as Array).clear()
	(moss_cognition["episodes"] as Array).clear()
	(mallow.get("language_state")["words"] as Dictionary).clear()
	(moss.get("language_state")["words"] as Dictionary).clear()
	Biochemistry.apply_event(mallow_biochemistry, "scold")
	Biochemistry.apply_event(moss_biochemistry, "scold")
	mallow.set("feedback_available", false)
	moss.set("feedback_available", false)
	world.call("select_norn", "mallow")
	world.call("load_game")
	mallow = world.call("profile_for", "mallow")
	moss = world.call("profile_for", "moss")
	mallow_cognition = mallow.get("cognition_state")
	moss_cognition = moss.get("cognition_state")
	_expect(_deep_values_match(mallow_cognition["episodes"], expected_mallow_episodes) and _deep_values_match(moss_cognition["episodes"], expected_moss_episodes), "version-5 round trip preserves both Norns' episodes")
	_expect(_number_maps_match(Biochemistry.read_compounds(mallow.get("biochemistry_state")), expected_mallow_compounds, Biochemistry.COMPOUND_IDS) and _number_maps_match(Biochemistry.read_compounds(moss.get("biochemistry_state")), expected_moss_compounds, Biochemistry.COMPOUND_IDS), "version-5 round trip preserves both Norns' compounds")
	_expect(mallow.get("language_state")["words"] == expected_mallow_words and moss.get("language_state")["words"] == expected_moss_words, "version-5 round trip preserves both vocabularies")
	_expect(world.get("focused_norn_id") == "moss", "version-5 round trip restores focus")
	_expect(mallow.get("feedback_available") and mallow.get("feedback_action") == "fruit" and is_equal_approx(float(mallow.get("feedback_time")), 7.25), "version-5 round trip preserves Mallow's independent feedback window")
	_expect(moss.get("feedback_available") and moss.get("feedback_action") == "spinner" and is_equal_approx(float(moss.get("feedback_time")), 9.5), "version-5 round trip preserves Moss's independent feedback window")
	_expect(mallow.get("actor").target == null and moss.get("actor").target == null, "loading clears transient movement targets")
	await _destroy_social_world(world)


func test_v1_migration_preserves_mallow_and_seeds_moss() -> void:
	await _verify_legacy_profile_migration(1)


func test_v2_migration_preserves_mallow_and_seeds_moss() -> void:
	await _verify_legacy_profile_migration(2)


func test_v3_migration_preserves_mallow_and_seeds_moss() -> void:
	await _verify_legacy_profile_migration(3)


func _verify_legacy_profile_migration(save_version: int) -> void:
	var world = await _create_social_world()
	world.set_process(false)
	var mallow = world.call("profile_for", "mallow")
	var cognition: Dictionary = mallow.get("cognition_state")
	Cognition.record_outcome(cognition, {"eventType": "food", "actionId": "fruit", "targetId": "fruit", "time": 3.0, "text": "Mallow legacy memory"})
	var biochemistry: Dictionary = mallow.get("biochemistry_state")
	Biochemistry.apply_event(biochemistry, "food")
	Cognition.sync_chemistry(cognition, Biochemistry.read_signals(biochemistry))
	var language: RefCounted = world.get("_language")
	language.call("teach_word", mallow.get("language_state"), "legacy", "fruit")
	var saved_cognition := Cognition.serialize_state(cognition)
	var expected_episodes: Array = saved_cognition["episodes"].duplicate(true)
	var expected_associations: Dictionary = saved_cognition["actionAssociations"].duplicate(true)
	var expected_signals := Biochemistry.read_signals(biochemistry)
	var expected_compounds := Biochemistry.read_compounds(biochemistry)
	var expected_words: Dictionary = mallow.get("language_state")["words"].duplicate(true)
	var legacy_record := {"version": save_version, "seed": 4181996, "simulationTime": 3.0, "cognition": saved_cognition}
	if save_version >= 2:
		legacy_record["language"] = language.call("serialize_state", mallow.get("language_state"))
	if save_version >= 3:
		legacy_record["biochemistry"] = Biochemistry.serialize_state(biochemistry)
	_expect(_write_save_record(legacy_record), "version-%d migration fixture can be written" % save_version)
	world.call("load_game")
	mallow = world.call("profile_for", "mallow")
	var moss = world.call("profile_for", "moss")
	var restored_cognition: Dictionary = mallow.get("cognition_state")
	var restored_language: Dictionary = mallow.get("language_state")
	var restored_biochemistry: Dictionary = mallow.get("biochemistry_state")
	_expect(_deep_values_match(restored_cognition["episodes"], expected_episodes) and _deep_values_match(restored_cognition["actionAssociations"], expected_associations), "version-%d migration preserves Mallow's cognition" % save_version)
	_expect(_number_maps_match(Biochemistry.read_signals(restored_biochemistry), expected_signals, Biochemistry.SIGNAL_IDS), "version-%d migration preserves Mallow's biochemical signals" % save_version)
	if save_version >= 3:
		_expect(_number_maps_match(Biochemistry.read_compounds(restored_biochemistry), expected_compounds, Biochemistry.COMPOUND_IDS), "version-3 migration preserves all Mallow compounds")
	if save_version >= 2:
		_expect(restored_language["words"] == expected_words, "version-%d migration preserves Mallow's vocabulary" % save_version)
	else:
		_expect(restored_language["words"].is_empty(), "version-1 migration starts Mallow with an empty vocabulary")
	var moss_cognition: Dictionary = moss.get("cognition_state")
	_expect(int(moss_cognition.get("seed", -1)) == 4181997 and moss_cognition["traits"] == {"curiosity": 0.5, "sociability": 0.85}, "version-%d migration creates Moss from deterministic seed and traits" % save_version)
	_expect(moss_cognition["episodes"].is_empty() and moss.get("language_state")["words"].is_empty() and not moss.get("feedback_available"), "version-%d migration creates clean independent Moss state" % save_version)
	var clean_moss_biochemistry := Biochemistry.create_state(moss_cognition["chemistry"])
	_expect(_number_maps_match(Biochemistry.read_compounds(moss.get("biochemistry_state")), Biochemistry.read_compounds(clean_moss_biochemistry), Biochemistry.COMPOUND_IDS), "version-%d migration initializes Moss with reproducible compounds" % save_version)
	_expect(world.get("focused_norn_id") == "mallow", "version-%d migration defaults focus to Mallow" % save_version)
	await _destroy_social_world(world)


func test_malformed_v4_save_uses_safe_reset() -> void:
	var world = await _create_social_world()
	world.set_process(false)
	var valid_record := _make_version4_fixture(world)
	var invalid_records: Array[Dictionary] = []
	var bad_ids: Dictionary = valid_record.duplicate(true)
	(bad_ids["norns"] as Dictionary).erase("moss")
	(bad_ids["norns"] as Dictionary)["stranger"] = (bad_ids["norns"] as Dictionary)["mallow"].duplicate(true)
	invalid_records.append(bad_ids)
	var bad_chemistry: Dictionary = valid_record.duplicate(true)
	(((bad_chemistry["norns"] as Dictionary)["moss"] as Dictionary)["biochemistry"] as Dictionary)["compounds"]["ATP"] = -1.0
	invalid_records.append(bad_chemistry)
	var bad_feedback: Dictionary = valid_record.duplicate(true)
	((bad_feedback["norns"] as Dictionary)["mallow"] as Dictionary)["feedback"]["action"] = "unknown"
	invalid_records.append(bad_feedback)
	var missing_data: Dictionary = valid_record.duplicate(true)
	(((missing_data["norns"] as Dictionary)["moss"] as Dictionary).erase("language"))
	invalid_records.append(missing_data)
	for index: int in range(invalid_records.size()):
		_expect(_write_save_record(invalid_records[index]), "malformed version-4 case %d can be written" % index)
		world.call("load_game")
		var mallow = world.call("profile_for", "mallow")
		var moss = world.call("profile_for", "moss")
		var mallow_cognition: Dictionary = mallow.get("cognition_state")
		var moss_cognition: Dictionary = moss.get("cognition_state")
		_expect(str(world.get("last_status")).contains("started a clean seeded"), "malformed version-4 case %d uses safe reset" % index)
		_expect(mallow_cognition["episodes"].is_empty() and moss_cognition["episodes"].is_empty(), "malformed version-4 case %d does not partially restore learning" % index)
		_expect(int(mallow_cognition.get("seed", -1)) == 4181996 and int(moss_cognition.get("seed", -1)) == 4181997 and world.get("focused_norn_id") == "mallow", "malformed version-4 case %d resets to both deterministic profiles" % index)
	await _destroy_social_world(world)


func _make_version4_fixture(world: Node) -> Dictionary:
	var norns := {}
	for actor_id: String in ["mallow", "moss"]:
		var profile = world.call("profile_for", actor_id)
		var serialized_cognition: Dictionary = Cognition.serialize_state(profile.get("cognition_state"))
		var serialized_biochemistry: Dictionary = Biochemistry.serialize_state(profile.get("biochemistry_state"))
		var serialized_language: Dictionary = world.get("_language").call("serialize_state", profile.get("language_state"))
		norns[actor_id] = {
			"actorId": actor_id,
			"cognition": serialized_cognition,
			"biochemistry": serialized_biochemistry,
			"language": serialized_language,
			"feedback": {"available": false, "action": "", "target": "", "time": -1000.0}
		}
	return {"version": 4, "seed": 4181996, "simulationTime": 1.0, "focusedNornId": "mallow", "norns": norns}


func _capture_original_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return true
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	_original_save_text = file.get_as_text()
	file.close()
	_save_backup_available = true
	return true


func _restore_original_save() -> void:
	if not _save_backup_ok:
		return
	if _save_backup_available:
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file == null:
			_failures.append("could not restore the original local save after persistence checks")
			return
		file.store_string(_original_save_text)
		file.close()
	elif FileAccess.file_exists(SAVE_PATH):
		var absolute_path := ProjectSettings.globalize_path(SAVE_PATH)
		if DirAccess.remove_absolute(absolute_path) != OK:
			_failures.append("could not remove the persistence test save after restoring the original empty state")


func _read_save_record() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file.close()
	return parser.data if parse_error == OK and parser.data is Dictionary else {}


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


func _deep_values_match(actual: Variant, expected: Variant) -> bool:
	if (actual is int or actual is float) and (expected is int or expected is float):
		return is_equal_approx(float(actual), float(expected))
	if actual is Dictionary and expected is Dictionary:
		if actual.size() != expected.size():
			return false
		for key: Variant in expected:
			if not actual.has(key) or not _deep_values_match(actual[key], expected[key]):
				return false
		return true
	if actual is Array and expected is Array:
		if actual.size() != expected.size():
			return false
		for index: int in range(expected.size()):
			if not _deep_values_match(actual[index], expected[index]):
				return false
		return true
	return actual == expected


func _create_social_world() -> Node:
	var world_script: Script = load("res://scripts/albia_world.gd")
	var world: Node = world_script.new()
	world.name = "SocialWorldFixture"
	root.add_child(world)
	await process_frame
	await physics_frame
	return world


func _add_test_child_profile(world: Node, actor_id: String, parent_ids: Array[String], age_seconds: float, position: Vector3, seed: int) -> Object:
	var cognition := Cognition.create_state(seed, {"curiosity": 0.5, "sociability": 0.5}, {"hunger": 0.0, "curiosity": 0.0, "fatigue": 5.0})
	var biochemistry := Biochemistry.create_state(cognition["chemistry"])
	Cognition.sync_chemistry(cognition, Biochemistry.read_signals(biochemistry))
	var actor := NornActor.new()
	actor.configure_identity(actor_id, "Testling", Color(0.62, 0.34, 0.18))
	actor.position = position
	world.add_child(actor)
	var profile = ProfileScript.new()
	profile.call("initialize", actor_id, "Testling", actor, cognition, biochemistry, world.get("_language").call("create_state"))
	profile.set("parent_ids", parent_ids.duplicate())
	profile.set("generation", 1)
	profile.set("body_color", Color(0.62, 0.34, 0.18))
	profile.set("life_state", Lifecycle.create_state(seed, age_seconds))
	actor.set_life_stage(str(profile.get("life_stage")))
	world.get("norn_profiles")[actor_id] = profile
	return profile


func _destroy_social_world(world: Node) -> void:
	if is_instance_valid(world):
		world.queue_free()
	await process_frame
	await physics_frame


func _set_profile_attending(observer: Object, source: Object) -> void:
	var observer_actor: NornActor = observer.get("actor")
	var source_actor: NornActor = source.get("actor")
	observer_actor.global_position = source_actor.global_position + Vector3(2.0, 0.0, 0.0)
	observer_actor.set_action_target(source_actor, "observe_peer", "Observing %s" % source.get("display_name"), str(source.get("actor_id")))
	await process_frame
	await physics_frame
	if is_instance_valid(observer_actor):
		observer_actor.set_action_target(null, "observe_peer", "Watching %s" % source.get("display_name"), str(source.get("actor_id")))


func _expected_observation_update(cognition: Dictionary, biochemistry: Dictionary, outcome: Dictionary) -> Dictionary:
	var before: Dictionary = Biochemistry.read_signals(biochemistry)
	var next_biochemistry: Dictionary = biochemistry.duplicate(true)
	Biochemistry.apply_event(next_biochemistry, "social")
	var after: Dictionary = Biochemistry.read_signals(next_biochemistry)
	Cognition.sync_chemistry(cognition, after)
	return Cognition.record_outcome(cognition, outcome, {"before": before, "after": after})


func _select_observation_peer_for_test(state: Dictionary, candidates: Array[Dictionary], parent_ids: Array[String], life_stage: String, now: float) -> Dictionary:
	var cognition_script_instance: Object = Cognition.new()
	if _method_argument_count(cognition_script_instance, "select_observation_peer") != 5:
		return {}
	var value: Variant = cognition_script_instance.call("select_observation_peer", state, candidates, parent_ids, life_stage, now)
	return value if value is Dictionary else {}


func _peer_score(selection: Dictionary, peer_id: String) -> Dictionary:
	for score_value: Variant in selection.get("scores", []):
		if score_value is Dictionary and str((score_value as Dictionary).get("peerId", "")) == peer_id:
			return score_value as Dictionary
	return {}


func _record_observation_peer_memory(state: Dictionary, actor_id: String, event_type: String, feedback: String, time_value: float, count: int) -> void:
	for memory_index in range(count):
		Cognition.record_outcome(state, {
			"eventType": event_type,
			"actorId": actor_id,
			"actionId": "observe_peer",
			"feedback": feedback,
			"time": time_value,
			"peerCount": 1,
			"sociability": 0.5,
			"salience": 0.55,
			"text": "Observed %s social event %d" % [actor_id, memory_index]
		})


func _event_count(episodes: Array, event_type: String) -> int:
	var total := 0
	for episode: Variant in episodes:
		if episode is Dictionary and episode.get("eventType", "") == event_type:
			total += 1
	return total


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
