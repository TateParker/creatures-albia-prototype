extends Node3D

const HabitatScene = preload("res://scenes/main.tscn")

var _warmup_frames: int = 12
var _previous_sample: int = 0
var _frame_interval_ms: Array[float] = []
var _world_process_ms: Array[float] = []
var _norn_physics_ms: Array[float] = []
var _world: AlbiaWorld


func _ready() -> void:
	_world = HabitatScene.instantiate()
	add_child(_world)
	_world.set_process(false)
	_world.norn.set_physics_process(false)


func _process(_delta: float) -> void:
	if _warmup_frames > 0:
		_warmup_frames -= 1
		_previous_sample = Time.get_ticks_usec()
		return
	var now := Time.get_ticks_usec()
	_frame_interval_ms.append(float(now - _previous_sample) / 1000.0)
	_previous_sample = now
	var before_world := Time.get_ticks_usec()
	_world._process(_delta)
	_world_process_ms.append(float(Time.get_ticks_usec() - before_world) / 1000.0)
	if _frame_interval_ms.size() < 600:
		return
	print("Godot: %s" % Engine.get_version_info()["string"])
	print("Scene profile: 1 Norn, 2 interactables, 600 measured frames at max 60 FPS")
	print("Rendered frame interval: %s ms" % _summary(_frame_interval_ms))
	print("AlbiaWorld process work (including cognition/sensing): %s ms" % _summary(_world_process_ms))
	print("Norn movement physics work: %s ms" % _summary(_norn_physics_ms))
	get_tree().quit()


func _physics_process(delta: float) -> void:
	if _world == null or _warmup_frames > 0:
		return
	var before_physics := Time.get_ticks_usec()
	_world.norn._physics_process(delta)
	_norn_physics_ms.append(float(Time.get_ticks_usec() - before_physics) / 1000.0)


func _summary(samples: Array[float]) -> String:
	var sorted: Array[float] = samples.duplicate()
	sorted.sort()
	if sorted.is_empty():
		return "no samples"
	var median := sorted[int((sorted.size() - 1) * 0.5)]
	var p95 := sorted[clampi(int(ceil(float(sorted.size() - 1) * 0.95)), 0, sorted.size() - 1)]
	return "median %.3f, p95 %.3f, max %.3f" % [median, p95, sorted[-1]]
