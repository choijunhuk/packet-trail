extends SceneTree

const ContentLoader = preload("res://scripts/core/content_loader.gd")

func _initialize() -> void:
	var failures: Array = []
	var loaded: Dictionary = ContentLoader.load_mission()
	if not loaded.get("ok", false):
		failures.append({"case": "M01 content loads", "errors": loaded.get("errors", [])})
	else:
		var definition: Dictionary = loaded.get("definition", {})
		var empty_goals: Dictionary = definition.duplicate(true)
		empty_goals["goals"] = []
		if ContentLoader.validate(empty_goals).get("ok", false):
			failures.append({"case": "empty goals must be rejected"})
		var unknown_goal: Dictionary = definition.duplicate(true)
		unknown_goal["goals"] = [{"kind": "not_a_supported_goal"}]
		if ContentLoader.validate(unknown_goal).get("ok", false):
			failures.append({"case": "unknown goal kind must be rejected"})
	print(JSON.stringify({"suite": "content_validation", "checks": 3, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
