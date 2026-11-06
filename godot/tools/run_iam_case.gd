extends SceneTree

const IAMTests = preload("res://tests/headless/test_iam_case.gd")


func _initialize() -> void:
	var result: Dictionary = IAMTests.new().run()
	print(JSON.stringify(result))
	quit(0 if result.failures.is_empty() else 1)
