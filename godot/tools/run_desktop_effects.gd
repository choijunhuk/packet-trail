extends SceneTree

const Tests = preload("res://tests/headless/test_desktop_effects.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result: Dictionary = await Tests.new().run(self)
	print(JSON.stringify(result))
	quit(0 if result.failures.is_empty() else 1)
