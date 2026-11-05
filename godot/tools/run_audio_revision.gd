extends SceneTree

const AudioTests = preload("res://tests/headless/test_audio_revision.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var result: Dictionary = await AudioTests.new().run()
	print(JSON.stringify(result))
	quit(0 if result.get("failures", ["Missing result"]).is_empty() else 1)
