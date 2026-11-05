extends SceneTree

func _initialize() -> void:
	var game = preload("res://scripts/core/campaign_game.gd").new("user://tests/grep_probe.json")
	game.execute("ssh guest@archive.packet.test", 0)
	var authenticated: Dictionary = game.submit_password("guest", 0)
	if not authenticated.get("ok", false):
		print("GREP_PROBE_SETUP_FAILED")
		quit(1)
		return
	print("GREP_PROBE_START")
	var result: Dictionary = game.execute("grep -i -n MAINT /public/shift-note.txt", 0)
	var failures: Array = [] if result.get("ok", false) else ["valid grep flags must read the existing virtual note"]
	print(JSON.stringify({"suite": "grep_flags", "checks": 1, "failures": failures, "result_code": result.get("code", "")}))
	quit(0 if failures.is_empty() else 1)
