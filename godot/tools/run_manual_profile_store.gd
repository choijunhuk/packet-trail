extends SceneTree

const Tests = preload("res://tests/headless/test_manual_profile_store.gd")


func _initialize() -> void:
	var result: Dictionary = Tests.new().run()
	print(JSON.stringify(result))
	quit(0 if result.failures.is_empty() else 1)
