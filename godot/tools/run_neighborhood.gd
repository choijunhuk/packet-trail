extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var suite = load("res://tests/headless/test_neighborhood.gd").new()
	var report: Dictionary = await suite.run(self)
	print(JSON.stringify(report))
	quit(0 if report.failures.is_empty() else 1)
