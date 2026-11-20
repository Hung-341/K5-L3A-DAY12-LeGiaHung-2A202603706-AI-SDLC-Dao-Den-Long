extends Node3D

const Leaderboard = preload("res://scripts/leaderboard.gd")


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var all := OS.get_cmdline_args() + args
	if "--headless-run" in args:
		get_tree().quit(preload("res://scripts/headless.gd").run(args))
		return
	var ei := all.find("--export-leaderboard")
	if ei >= 0:
		get_tree().quit(Leaderboard.export_to(all[ei + 1]) if ei + 1 < all.size() else 1)
		return
	var ai := args.find("--lb-add")  # chỉ dùng cho test: --lb-add <tên> <điểm> <số đêm thắng> <seed>
	if ai >= 0 and ai + 4 < args.size():
		if not Leaderboard.valid_name(args[ai + 1]):
			printerr("tên không hợp lệ")
			get_tree().quit(2)
			return
		Leaderboard.save_entries(Leaderboard.add(Leaderboard.load_entries(), args[ai + 1], int(args[ai + 2]),
			int(args[ai + 3]), int(args[ai + 4])))
		get_tree().quit(0)
		return
	add_child(preload("res://scripts/view.gd").new())
