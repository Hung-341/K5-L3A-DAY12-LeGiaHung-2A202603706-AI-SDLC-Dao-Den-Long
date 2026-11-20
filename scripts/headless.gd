# HeadlessRun
extends RefCounted
const Sim = preload("res://scripts/sim.gd")
## Chạy headless theo Test Contract. Trả exit code: 0 ok, 1 lỗi tham số/IO, 2 file inputs/scenario sai định dạng.

class BadFormat:
	var msg: String
	func _init(m: String) -> void:
		msg = m


static func run(args: PackedStringArray) -> int:
	var opt := {"--snapshot-every": "10", "--night": "1"}
	var i := 0
	while i < args.size():
		var a := args[i]
		if a.begins_with("--") and a != "--headless-run":
			if i + 1 >= args.size():
				printerr("thiếu giá trị cho ", a)
				return 1
			opt[a] = args[i + 1]
			i += 2
		else:
			i += 1
	for k in ["--seed", "--ticks", "--out"]:
		if not opt.has(k):
			printerr("thiếu tham số ", k)
			return 1
	if not (opt["--seed"].is_valid_int() and opt["--ticks"].is_valid_int() and opt["--snapshot-every"].is_valid_int()):
		printerr("--seed/--ticks/--snapshot-every phải là số nguyên")
		return 1
	if opt["--night"] != "1":
		printerr("Phase 1 chỉ có --night 1")
		return 1
	var ticks := int(opt["--ticks"])
	var every := int(opt["--snapshot-every"])
	if ticks < 0 or every <= 0:
		printerr("--ticks >= 0, --snapshot-every > 0")
		return 1

	var sc = {}
	if opt.has("--scenario"):
		sc = _load(opt["--scenario"])
		if sc is BadFormat or sc is int:
			return _fail(sc)
		var e := _check_scenario(sc)
		if e != "":
			return _fail(BadFormat.new("scenario: " + e))
	var frames := []
	if opt.has("--inputs"):
		var inp = _load(opt["--inputs"])
		if inp is BadFormat or inp is int:
			return _fail(inp)
		var e := _check_inputs(inp)
		if e != "":
			return _fail(BadFormat.new("inputs: " + e))
		frames = inp["frames"]

	var out := FileAccess.open(opt["--out"], FileAccess.WRITE)
	if out == null:
		printerr("không ghi được ", opt["--out"])
		return 1
	var sim := Sim.new(int(opt["--seed"]), Sim.load_tuning())
	sim.apply_scenario(sc)
	var cur := {"move": [0, 0], "cam_yaw_deg": 0.0, "jump": false, "interact": false, "pulse": false, "dash": false}
	var fi := 0
	var k := 0
	out.store_line(JSON.stringify(sim.snapshot(0), "", false))
	while k < ticks and sim.state == "playing":
		while fi < frames.size() and int(frames[fi]["tick"]) <= k:
			for key in frames[fi]:
				if key != "tick":
					cur[key] = frames[fi][key]
			fi += 1
		sim.step(cur)
		k += 1
		for ev in sim.events:
			out.store_line(JSON.stringify({"type": "event", "tick": k, "name": ev["name"], "data": ev["data"]}, "", false))
		sim.events.clear()
		if k % every == 0:
			out.store_line(JSON.stringify(sim.snapshot(k), "", false))
	out.store_line(JSON.stringify({"type": "end", "ticks": k, "state": sim.state, "score": sim.score}, "", false))
	out.close()
	return 0


static func _fail(e) -> int:
	if e is int:
		return e
	printerr(e.msg)
	return 2


static func _load(path: String):
	if not FileAccess.file_exists(path):
		printerr("không tìm thấy ", path)
		return 1
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK:
		return BadFormat.new("JSON hỏng ở %s dòng %d: %s" % [path, j.get_error_line(), j.get_error_message()])
	if typeof(j.data) != TYPE_DICTIONARY:
		return BadFormat.new(path + ": gốc phải là object")
	return j.data


static func _num(x) -> bool:
	return typeof(x) == TYPE_FLOAT or typeof(x) == TYPE_INT


static func _vec(x, n: int) -> bool:
	return typeof(x) == TYPE_ARRAY and x.size() == n and x.all(func(v): return _num(v))


static func _int(x) -> bool:
	return _num(x) and float(x) == floor(float(x))


static func _check_inputs(d: Dictionary) -> String:
	if typeof(d.get("frames")) != TYPE_ARRAY:
		return "thiếu mảng frames"
	var last := -1
	for f in d["frames"]:
		if typeof(f) != TYPE_DICTIONARY or not f.has("tick") or not _int(f["tick"]):
			return "frame phải có tick nguyên"
		if int(f["tick"]) <= last or int(f["tick"]) < 0:
			return "tick phải tăng nghiêm ngặt và >= 0"
		last = int(f["tick"])
		if f.has("move") and not (_vec(f["move"], 2) and absf(f["move"][0]) <= 1.0 and absf(f["move"][1]) <= 1.0):
			return "move phải là [x,z] trong [-1,1]"
		if f.has("cam_yaw_deg") and not _num(f["cam_yaw_deg"]):
			return "cam_yaw_deg phải là số"
		for b in ["jump", "interact", "pulse", "dash", "pause"]:
			if f.has(b) and typeof(f[b]) != TYPE_BOOL:
				return b + " phải là boolean"
	return ""


static func _check_scenario(d: Dictionary) -> String:
	if d.has("player"):
		var p = d["player"]
		if typeof(p) != TYPE_DICTIONARY:
			return "player phải là object"
		if p.has("pos") and not _vec(p["pos"], 3):
			return "player.pos phải là [x,y,z]"
		for k in ["carried", "flames"]:
			if p.has(k) and not (_int(p[k]) and p[k] >= 0):
				return "player.%s phải là số nguyên >= 0" % k
	for k in ["random_motes", "random_shades"]:
		if d.has(k) and typeof(d[k]) != TYPE_BOOL:
			return k + " phải là boolean"
	if d.has("motes") and not (typeof(d["motes"]) == TYPE_ARRAY and d["motes"].all(func(m): return _vec(m, 3))):
		return "motes phải là mảng [x,y,z]"
	if d.has("shades"):
		if typeof(d["shades"]) != TYPE_ARRAY:
			return "shades phải là mảng"
		for s in d["shades"]:
			if typeof(s) != TYPE_DICTIONARY or not _vec(s.get("pos"), 3) or (s.has("id") and typeof(s["id"]) != TYPE_STRING):
				return "shade cần pos [x,y,z], id là chuỗi"
	if d.has("lanterns"):
		if typeof(d["lanterns"]) != TYPE_ARRAY:
			return "lanterns phải là mảng"
		for l in d["lanterns"]:
			if typeof(l) != TYPE_DICTIONARY or not (l.get("id") in ["L1", "L2", "L3", "L4", "L5"]):
				return "lantern cần id L1..L5"
			if l.has("pos") and not _vec(l["pos"], 3):
				return "lantern.pos phải là [x,y,z]"
			if l.has("lit") and typeof(l["lit"]) != TYPE_BOOL:
				return "lantern.lit phải là boolean"
			if l.has("deposited") and not (_int(l["deposited"]) and l["deposited"] >= 0):
				return "lantern.deposited phải là số nguyên >= 0"
	if d.has("time_left_s") and not (_num(d["time_left_s"]) and d["time_left_s"] > 0):
		return "time_left_s phải là số > 0"
	return ""
