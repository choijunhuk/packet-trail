extends SceneTree
const Tests = preload("res://tests/headless/test_habitat_ui.gd")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var result: Dictionary = await Tests.new().run(self)
	print(JSON.stringify(result))
	quit(0 if result.get("failures", ["Missing result"]).is_empty() else 1)
