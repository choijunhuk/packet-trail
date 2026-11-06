extends SceneTree

const PreferenceTests = preload("res://tests/headless/test_lobby_preferences.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var result: Dictionary = await PreferenceTests.new().run(self)
	result["suite"] = "lobby_preferences"
	print(JSON.stringify(result))
	quit(0 if result.get("failures", ["Missing result"]).is_empty() else 1)
