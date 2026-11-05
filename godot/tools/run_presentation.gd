extends SceneTree

func _initialize() -> void:
	var result: Dictionary = preload("res://tests/headless/test_presentation.gd").new().run()
	result["suite"] = "presentation"
	print(JSON.stringify(result))
	quit(0 if result.get("failures", ["missing failures"]).is_empty() else 1)
