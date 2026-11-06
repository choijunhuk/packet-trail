extends SceneTree

const WorkbenchTests = preload("res://tests/headless/test_workbench.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var result: Dictionary = await WorkbenchTests.new().run(self)
	print(JSON.stringify(result))
	quit(0 if result.get("failures", ["Missing result"]).is_empty() else 1)
