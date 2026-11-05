extends SceneTree
## Dedicated process entry point; an external deadline validates that product shutdown completes.

const ShutdownTests = preload("res://tests/headless/test_shutdown.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or not args[0] in ["--mode=menu", "--mode=window"]:
		print(JSON.stringify({"suite": "shutdown", "checks": 1,
			"failures": ["Exactly one --mode=menu or --mode=window argument is required."], "stage": "setup_failed"}))
		quit(1)
		return
	await ShutdownTests.new().run(self, str(args[0]).trim_prefix("--mode="))
