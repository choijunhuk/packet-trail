extends SceneTree

const ShellTests = preload("res://tests/headless/test_desktop_shell.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var result: Dictionary = await ShellTests.new().run(self)
	result["suite"] = "desktop_shell"
	print(JSON.stringify(result))
	quit(0 if result.get("failures", ["Missing result"]).is_empty() else 1)
