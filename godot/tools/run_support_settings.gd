extends SceneTree

const SupportTests = preload("res://tests/headless/test_support_settings.gd")


func _initialize() -> void:
	var result: Dictionary = SupportTests.new().run()
	result["suite"] = "support_settings"
	print(JSON.stringify(result))
	quit(0 if result.get("failures", ["Missing result"]).is_empty() else 1)
