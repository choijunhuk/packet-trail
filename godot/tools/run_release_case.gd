extends SceneTree

const Tests = preload("res://tests/headless/test_release_case.gd")


func _initialize() -> void:
	var report: Dictionary = Tests.new().run()
	print(JSON.stringify(report))
	quit(0 if report.get("failures", ["Missing report"]).is_empty() else 1)
