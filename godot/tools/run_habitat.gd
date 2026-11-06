extends SceneTree

const HabitatTests = preload("res://tests/headless/test_habitat.gd")


func _initialize() -> void:
	var result: Dictionary = HabitatTests.new().run()
	print(JSON.stringify(result))
	quit(0 if result.failures.is_empty() else 1)
