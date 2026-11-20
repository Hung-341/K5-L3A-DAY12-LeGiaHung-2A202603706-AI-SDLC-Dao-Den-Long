extends Node3D

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--headless-run" in args:
		get_tree().quit(preload("res://scripts/headless.gd").run(args))
		return
	add_child(preload("res://scripts/view.gd").new())
