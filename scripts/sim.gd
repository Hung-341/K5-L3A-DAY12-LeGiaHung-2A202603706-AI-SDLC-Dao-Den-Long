# Sim: luật chơi (nạp bằng preload, không dùng class_name để chạy được khi chưa import)
extends RefCounted
## Toàn bộ luật chơi. Không phụ thuộc node; GUI và headless cùng gọi step().
## Thứ tự trong step() theo Ticket-02 "Thứ tự xử lý trong một tick".

const DT := 1.0 / 60.0
const ISLAND_R := 40.0
const FALL_Y := -10.0
const GRAVITY := 20.0
const JUMP_V := 7.0
const DASH_V := 14.0
const DASH_TICKS := 12
const DASH_CD_TICKS := 90
const MOTE_CAP := 30
const MOTE_INIT := 20
const MOTE_EVERY := 240
const DROP_TTL := 480
const SHADE_FIRST := 300
const SHADE_EVERY := 480
const SHADE_MAX := 6
const SHADE_MIN_DIST := 15.0
const SHADE_DETECT := 12.0
const SHADE_LOSE := 18.0
const SHADE_Y := 1.0
const SHADE_SPAWNING := 30
const WANDER_SPEED := 2.0
const PUSH_TICKS := 15
const RECOIL_TICKS := 60
const RECOIL_M := 2.0
const SAFE_PUSH_TICKS := 30
const PULSE_H := 0.8
const DY_MAX := 1.5
const RESPAWN_WAIT := 60
const LANTERN_POS := [Vector3(0, 0, 25), Vector3(23.8, 0, 7.7), Vector3(14.7, 0, -20.2), Vector3(-14.7, 0, -20.2), Vector3(-23.8, 0, 7.7)]

var T: Dictionary
var S: Dictionary
var rng := RandomNumberGenerator.new()
var events: Array = []
var steps := 0
var state := "playing"
var dur0 := 300.0
var time_left := 300.0
var score := 0

var p_pos := Vector3.ZERO
var p_vel := Vector3.ZERO
var p_face := Vector3(0, 0, 1)
var grounded := true
var flames := 3
var carried := 0
var invuln := 0
var pulse_cd := 0
var dash_cd := 0
var dash_t := 0
var dash_dir := Vector3.ZERO
var fall_wait := 0

var motes: Array = []     # {id, pos, kind, ttl, born}
var shades: Array = []    # {id, pos, state, t, push_t, dir, target}
var lanterns: Array = []  # {id, pos, lit, deposited}
var mote_points: Array = []
var shade_points: Array = []
var next_mote := 1
var next_shade := 1
var random_motes := true
var random_shades := true
var prev := {"jump": false, "interact": false, "pulse": false, "dash": false}


static func load_tuning() -> Dictionary:
	var f := FileAccess.open("res://game.contract.json", FileAccess.READ)
	return JSON.parse_string(f.get_as_text())["tuning"]


func _init(seed: int, tuning: Dictionary) -> void:
	T = tuning
	S = tuning["score"]
	rng.seed = seed
	dur0 = float(T["night1_duration_s"])
	time_left = dur0
	flames = int(T["flames"])
	for i in LANTERN_POS.size():
		lanterns.append({"id": "L%d" % (i + 1), "pos": LANTERN_POS[i], "lit": false, "deposited": 0})
	for k in 8:
		mote_points.append(_polar(12.0, k * 45.0))
	for k in 16:
		mote_points.append(_polar(33.0, k * 22.5))
	for k in 12:
		shade_points.append(_polar(37.0, 15.0 + k * 30.0, SHADE_Y))
	var pts := mote_points.duplicate()
	for i in MOTE_INIT:
		var j := rng.randi_range(0, pts.size() - 1)
		_add_mote(pts[j], "random", -1)
		pts.remove_at(j)


static func _polar(r: float, deg: float, y := 0.0) -> Vector3:
	var a := deg_to_rad(deg)
	return Vector3(r * cos(a), y, r * sin(a))


static func xz(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _add_mote(pos: Vector3, kind: String, ttl: int) -> void:
	motes.append({"id": "M%d" % next_mote, "pos": pos, "kind": kind, "ttl": ttl, "born": steps})
	next_mote += 1


func add_shade(pos: Vector3, id := "", st := "wander", t := 0) -> void:
	if id == "":
		id = "S%d" % next_shade
	next_shade = max(next_shade, int(id.substr(1)) + 1) if id.substr(1).is_valid_int() else next_shade + 1
	shades.append({"id": id, "pos": pos, "state": st, "t": t, "push_t": 0, "dir": Vector3.RIGHT, "target": pos})


## Dựng scenario: không phát event, không cộng điểm. Đã được validate ở driver.
func apply_scenario(sc: Dictionary) -> void:
	random_motes = sc.get("random_motes", true)
	random_shades = sc.get("random_shades", true)
	if sc.has("motes") or not random_motes:
		motes.clear()
		for m in sc.get("motes", []):
			_add_mote(Vector3(m[0], m[1], m[2]), "random", -1)
	if sc.has("shades"):
		shades.clear()
		for s in sc["shades"]:
			var p: Array = s["pos"]
			add_shade(Vector3(p[0], p[1], p[2]), s.get("id", ""))
	for l in sc.get("lanterns", []):
		for L in lanterns:
			if L["id"] == l["id"]:
				if l.has("pos"):
					L["pos"] = Vector3(l["pos"][0], l["pos"][1], l["pos"][2])
				if l.has("deposited"):
					L["deposited"] = int(l["deposited"])
				if l.has("lit"):
					L["lit"] = bool(l["lit"])
	var pl: Dictionary = sc.get("player", {})
	if pl.has("pos"):
		p_pos = Vector3(pl["pos"][0], pl["pos"][1], pl["pos"][2])
	if pl.has("carried"):
		carried = int(pl["carried"])
	if pl.has("flames"):
		flames = int(pl["flames"])
	if sc.has("time_left_s"):
		dur0 = float(sc["time_left_s"])
		time_left = dur0


func _emit(name: String, data: Dictionary) -> void:
	events.append({"name": name, "data": data})


func _edge(inp: Dictionary, key: String) -> bool:
	var now: bool = inp.get(key, false)
	var was: bool = prev[key]
	prev[key] = now
	return now and not was


func _in_safe(pos: Vector3) -> Dictionary:
	for L in lanterns:
		if L["lit"] and xz(pos, L["pos"]) < float(T["safe_radius"]):
			return L
	return {}


## Một bước 1/60 s. inp: {move:[x,z], cam_yaw_deg, jump, interact, pulse, dash}
func step(inp: Dictionary) -> void:
	if state != "playing":
		return
	# 1. input
	var jump := _edge(inp, "jump")
	var interact := _edge(inp, "interact")
	var pulse := _edge(inp, "pulse")
	var dash := _edge(inp, "dash")
	steps += 1
	# 2. bộ đếm
	time_left = dur0 - steps * DT
	invuln = max(0, invuln - 1)
	pulse_cd = max(0, pulse_cd - 1)
	dash_cd = max(0, dash_cd - 1)
	for s in shades:
		s["t"] = max(0, s["t"] - 1)
	for m in motes.duplicate():
		if m["ttl"] > 0:
			m["ttl"] -= 1
			if m["ttl"] == 0:
				motes.erase(m)
	# 3. di chuyển Mây + rơi
	var active := fall_wait == 0
	if not active:
		fall_wait -= 1
		if fall_wait == 0:
			p_pos = Vector3.ZERO
			p_vel = Vector3.ZERO
			grounded = true
			invuln = int(round(float(T["invuln_s"]) * 60.0))
	else:
		_move_player(inp, jump, dash)
	active = fall_wait == 0
	# 4. nhặt
	if active:
		for m in motes.duplicate():
			if carried >= int(T["carry_capacity"]):
				break
			if m["born"] < steps and xz(p_pos, m["pos"]) <= float(T["pickup_radius"]) and absf(p_pos.y - m["pos"].y) <= DY_MAX:
				motes.erase(m)
				carried += 1
				_emit("mote_picked", {"carried": carried})
	# 5. tương tác đèn
	if active and interact:
		_interact()
	# 6. vùng an toàn: bóng bên trong đèn sáng bị đẩy ra mép
	var sr := float(T["safe_radius"])
	for s in shades:
		var L := _in_safe(s["pos"])
		if not L.is_empty():
			var d: Vector3 = s["pos"] - L["pos"]
			d.y = 0
			if d.length() < 0.0001:
				d = Vector3.RIGHT
			var r: float = min(sr, d.length() + sr / SAFE_PUSH_TICKS)
			s["pos"] = Vector3(L["pos"].x, s["pos"].y, L["pos"].z) + d.normalized() * r
	# 7. tỏa sáng
	if active and pulse:
		_pulse()
	# 8. Bóng Mực
	for s in shades:
		_move_shade(s, active)
	# 9. chạm
	if active and invuln == 0:
		for s in shades:
			if s["state"] in ["wander", "chase"] and _in_safe(s["pos"]).is_empty() \
					and xz(p_pos, s["pos"]) <= float(T["shade_hit_radius"]) and absf(p_pos.y - s["pos"].y) <= DY_MAX:
				_hit(s)
				break
	# 10. sinh
	_spawn()
	# 11. thắng/thua
	var all_lit := lanterns.all(func(L): return L["lit"])
	if flames <= 0:
		_end("lost", "no_flames")
	elif all_lit:
		score += int(floor(max(time_left, 0.0))) * int(S["per_second_left"]) + flames * int(S["per_flame_left"])
		_end("won", "all_lit")
	elif time_left <= 1e-9:
		_end("lost", "dawn")


func _end(result: String, reason: String) -> void:
	state = result
	_emit("game_over", {"result": result, "reason": reason})


func _move_player(inp: Dictionary, jump: bool, dash: bool) -> void:
	var m: Array = inp.get("move", [0, 0])
	var v := Vector2(m[0], m[1])
	if v.length() > 1.0:
		v = v.normalized()
	var th := deg_to_rad(float(inp.get("cam_yaw_deg", 0.0)))
	var dir := Vector3(v.x * cos(th) + v.y * sin(th), 0, -v.x * sin(th) + v.y * cos(th))
	if dir.length() > 0.0001:
		p_face = dir.normalized()
	if dash and dash_cd == 0 and dash_t == 0:
		dash_t = DASH_TICKS
		dash_cd = DASH_CD_TICKS
		dash_dir = p_face
		_emit("dash", {})
	if dash_t > 0:
		dash_t -= 1
		p_vel = Vector3(dash_dir.x * DASH_V, 0, dash_dir.z * DASH_V)
	else:
		var sp := float(T["player_speed"])
		p_vel = Vector3(dir.x * sp, p_vel.y, dir.z * sp)
		if jump and grounded:
			p_vel.y = JUMP_V
		p_vel.y -= GRAVITY * DT
	p_pos += p_vel * DT
	var on_island := Vector2(p_pos.x, p_pos.z).length() <= ISLAND_R
	if on_island and p_pos.y <= 0.0 and p_vel.y <= 0.0 and p_pos.y > -0.5:
		p_pos.y = 0.0
		p_vel.y = 0.0
		grounded = true
	else:
		grounded = false
	if p_pos.y < FALL_Y:
		flames -= 1
		var lost := carried
		carried = 0
		fall_wait = RESPAWN_WAIT
		p_vel = Vector3.ZERO
		_emit("player_hit", {"by": "fall", "flames": max(flames, 0), "dropped": lost, "lost": lost})


func _interact() -> void:
	var best: Dictionary = {}
	var bd := INF
	for L in lanterns:
		if L["lit"]:
			continue
		var d := xz(p_pos, L["pos"])
		if d <= float(T["interact_radius"]) and d < bd:
			best = L
			bd = d
	if best.is_empty() or carried == 0:
		return
	var cost := int(T["lantern_cost"])
	var amt: int = min(carried, cost - int(best["deposited"]))
	best["deposited"] += amt
	carried -= amt
	score += amt * int(S["per_mote"])
	_emit("deposit", {"lantern_id": best["id"], "amount": amt, "deposited": best["deposited"]})
	if best["deposited"] >= cost:
		best["lit"] = true
		score += int(S["per_lantern"])
		_emit("lantern_lit", {"lantern_id": best["id"]})


func _pulse() -> void:
	var cost := int(T["pulse_cost"])
	if pulse_cd > 0 or carried < cost:
		return
	carried -= cost
	pulse_cd = int(round(float(T["pulse_cooldown_s"]) * 60.0))
	var c := p_pos + Vector3(0, PULSE_H, 0)
	var ids := []
	for s in shades:
		if c.distance_to(s["pos"]) <= float(T["pulse_radius"]):
			var d: Vector3 = s["pos"] - p_pos
			d.y = 0
			s["dir"] = d.normalized() if d.length() > 0.0001 else Vector3.RIGHT
			s["state"] = "stunned"
			s["t"] = int(round(float(T["pulse_stun_s"]) * 60.0))
			s["push_t"] = PUSH_TICKS
			score += int(S["per_stun"])
			ids.append(s["id"])
	_emit("pulse", {"stunned_ids": ids})


func _move_shade(s: Dictionary, player_active: bool) -> void:
	var before: Vector3 = s["pos"]
	var stv: String = s["state"]
	if stv == "spawning":
		if s["t"] == 0:
			s["state"] = "wander"
		return
	if stv == "stunned":
		if s["push_t"] > 0:
			s["push_t"] -= 1
			s["pos"] += s["dir"] * (float(T["pulse_push_m"]) / PUSH_TICKS)
		if s["t"] == 0:
			s["state"] = "wander"
	elif stv == "recoil":
		s["pos"] += s["dir"] * (RECOIL_M / RECOIL_TICKS)
		if s["t"] == 0:
			s["state"] = "wander"
	else:
		var d := xz(s["pos"], p_pos)
		if not player_active:
			s["state"] = "wander"
		elif stv == "wander" and d <= SHADE_DETECT:
			s["state"] = "chase"
		elif stv == "chase" and d > SHADE_LOSE:
			s["state"] = "wander"
		var goal: Vector3 = p_pos if s["state"] == "chase" else s["target"]
		var sp := float(T["shade_speed"]) if s["state"] == "chase" else WANDER_SPEED
		var to := Vector3(goal.x - s["pos"].x, 0, goal.z - s["pos"].z)
		if to.length() <= sp * DT:
			s["pos"] = Vector3(goal.x, s["pos"].y, goal.z)
			if s["state"] == "wander":
				s["target"] = _polar(rng.randf_range(5.0, 35.0), rng.randf_range(0.0, 360.0), s["pos"].y)
		else:
			s["pos"] += to.normalized() * sp * DT
	# bóng ở ngoài vùng an toàn bị chặn ở mép
	var sr := float(T["safe_radius"])
	for L in lanterns:
		if L["lit"] and xz(before, L["pos"]) >= sr and xz(s["pos"], L["pos"]) < sr:
			var d: Vector3 = s["pos"] - L["pos"]
			d.y = 0
			s["pos"] = Vector3(L["pos"].x, s["pos"].y, L["pos"].z) + d.normalized() * sr
	var h := Vector2(s["pos"].x, s["pos"].z)
	if h.length() > ISLAND_R - 2.0:
		h = h.normalized() * (ISLAND_R - 2.0)
		s["pos"] = Vector3(h.x, s["pos"].y, h.y)


func _hit(s: Dictionary) -> void:
	flames -= 1
	var dropped := int(floor(carried / 2.0))
	carried -= dropped
	for i in dropped:
		var a := rng.randf_range(0.0, TAU)
		var r := rng.randf_range(1.5, 2.5)
		_add_mote(Vector3(p_pos.x + r * cos(a), 0.0, p_pos.z + r * sin(a)), "dropped", DROP_TTL)
	invuln = int(round(float(T["invuln_s"]) * 60.0))
	var d: Vector3 = s["pos"] - p_pos
	d.y = 0
	s["dir"] = d.normalized() if d.length() > 0.0001 else Vector3.RIGHT
	s["state"] = "recoil"
	s["t"] = RECOIL_TICKS
	_emit("player_hit", {"by": "shade", "flames": max(flames, 0), "dropped": dropped})


func _spawn() -> void:
	if random_motes and steps % MOTE_EVERY == 0 and motes.size() < MOTE_CAP:
		var free := []
		for pt in mote_points:
			if motes.all(func(m): return xz(m["pos"], pt) > 0.5):
				free.append(pt)
		if not free.is_empty():
			_add_mote(free[rng.randi_range(0, free.size() - 1)], "random", -1)
	if not random_shades or steps < SHADE_FIRST or (steps - SHADE_FIRST) % SHADE_EVERY != 0:
		return
	var n := 2 if steps == SHADE_FIRST else 1
	for i in n:
		if shades.size() >= SHADE_MAX:
			return
		var ok := shade_points.filter(func(pt): return xz(pt, p_pos) >= SHADE_MIN_DIST)
		if ok.is_empty():
			return
		var id := "S%d" % next_shade
		add_shade(ok[rng.randi_range(0, ok.size() - 1)], id, "spawning", SHADE_SPAWNING)
		_emit("shade_spawned", {"id": id})


static func r3(x: float) -> float:
	var v := snappedf(x, 0.001)
	return 0.0 if absf(v) < 0.0005 else v


static func v3(v: Vector3) -> Array:
	return [r3(v.x), r3(v.y), r3(v.z)]


func snapshot(tick: int) -> Dictionary:
	var ls := []
	for L in lanterns:
		ls.append({"id": L["id"], "pos": v3(L["pos"]), "lit": L["lit"], "deposited": L["deposited"]})
	var ss := []
	for s in shades:
		ss.append({"id": s["id"], "pos": v3(s["pos"]), "state": s["state"]})
	var ms := []
	for m in motes:
		ms.append({"id": m["id"], "pos": v3(m["pos"]), "kind": m["kind"], "ttl_s": r3(max(m["ttl"], 0) * DT) if m["ttl"] > 0 else null})
	return {"type": "snapshot", "tick": tick, "sim_tick": steps, "night": 1, "state": state,
		"time_left_s": r3(time_left), "score": score,
		"player": {"pos": v3(p_pos), "flames": flames, "carried": carried, "vel": v3(p_vel),
			"grounded": grounded, "invuln": invuln > 0, "pulse_cd_s": r3(pulse_cd * DT), "dash_cd_s": r3(dash_cd * DT)},
		"lanterns": ls, "shades": ss, "motes_active": motes.size(), "motes": ms}
