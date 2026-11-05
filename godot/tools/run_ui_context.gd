extends SceneTree

const ContextTests = preload("res://tests/headless/test_ui_context.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var result: Dictionary = await ContextTests.new().run(self)
	result["suite"] = "ui_context"
	print(JSON.stringify(result))
	quit(0 if result.get("failures", ["Missing result"]).is_empty() else 1)
