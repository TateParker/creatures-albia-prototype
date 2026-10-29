class_name NornProfile
extends RefCounted

var actor_id: String = ""
var display_name: String = ""
var generation: int = 0
var parent_ids: Array[String] = []
var body_color: Color = Color(0.43, 0.27, 0.16)
var life_state: Dictionary = {}
var actor: NornActor
var cognition_state: Dictionary = {}
var biochemistry_state: Dictionary = {}
var language_state: Dictionary = {}
var guidance: Dictionary = {}
var current_decision: Dictionary = {}
var recalled_moments: Array[Dictionary] = []
var feedback_available: bool = false
var feedback_action: String = ""
var feedback_target: String = ""
var feedback_time: float = -1000.0


func initialize(profile_actor_id: String, profile_display_name: String, actor_node: NornActor, cognition: Dictionary, biochemistry: Dictionary, language: Dictionary) -> void:
	actor_id = profile_actor_id
	display_name = profile_display_name
	actor = actor_node
	cognition_state = cognition
	biochemistry_state = biochemistry
	language_state = language
	guidance.clear()
	current_decision.clear()
	recalled_moments.clear()
	feedback_available = false
	feedback_action = ""
	feedback_target = ""
	feedback_time = -1000.0
