# Sim: luật chơi (nạp bằng preload, không dùng class_name để chạy được khi chưa import)
extends RefCounted
## Toàn bộ luật chơi của một Đêm. Không phụ thuộc node; GUI và headless cùng gọi step().
## Thứ tự trong step() theo Ticket-02 "Thứ tự xử lý trong một tick".

const DT := 1.0 / 60.0
const FALL_Y := -10.0
const GRAVITY := 20.0
const JUMP_V := 7.0
const DASH_TICKS := 12
const CHARM_SPEED := 7.2
const CHARM_TICKS := 600
const CHARM_RESPAWN := 2700
const MOTE_CAP := 30
const MOTE_INIT := 20
const MOTE_EVERY := 240
const DROP_TTL := 480
const SHADE_FIRST := 300
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
const STEP_UP := 0.35
const EPS := 1e-6  # bù sai số float cộng dồn khi so "trong bán kính r" (<= r)
const RESPAWN_WAIT := 60
const DRIFT_SPEED := 7.0
const DRIFT_IDLE_SPEED := 2.0
const DRIFT_MAX := 2
const DRIFT_EVERY := 1200
const DRIFT_TOUCH := 1.2
const DRIFT_STEAL := 3
const DRIFT_MIN_CARRY := 5
const DRIFT_DETECT := 15.0
const FLEE_TICKS := 240
const DROP_FLEE_TICKS := 120
const WIND_EVERY := 1800
const WIND_TICKS := 300
const WIND_WARN := 120
const WIND_SPEED := 2.0
const TOWER_R := 2.0
const TOWER_TOP := 14.0
const NO_GROUND := -1e9

## Bản đồ chuẩn (Ticket-02 Phần 2). Góc từ +X, điểm = (r cos a, y, r sin a).
static func level(n: int) -> Dictionary:
	var L := {}
	match n:
		1:
			L = {"name": "Đảo Bến", "start": Vector3.ZERO, "every": 480, "max": 6, "speed_mul": 1.0,
				"lanterns": [Vector3(0, 0, 25), Vector3(23.8, 0, 7.7), Vector3(14.7, 0, -20.2), Vector3(-14.7, 0, -20.2), Vector3(-23.8, 0, 7.7)],
				"motes": _ring(8, 12.0, 0.0, 45.0) + _ring(16, 33.0, 0.0, 22.5),
				"shades": _ring(12, 37.0, 15.0, 30.0), "charms": [], "drifters": false, "wind": false, "pads": []}
		2:
			L = {"name": "Đảo Cau", "start": Vector3.ZERO, "every": 420, "max": 8, "speed_mul": 1.0,
				"lanterns": [Vector3(0, 0, 20), Vector3(17, 0, -10), Vector3(-17, 0, -10), Vector3(70, 0, 20), Vector3(87, 0, -10), Vector3(53, 0, -10)],
				"motes": [], "shades": [], "charms": [Vector3(35, 0, 0)], "drifters": true, "wind": false,
				"pads": [{"pos": Vector3(20, 0, 18), "vy": 14.0, "h": 24.0, "dir": Vector3(50, 0, -18).normalized()},
					{"pos": Vector3(50, 0, -18), "vy": 14.0, "h": 24.0, "dir": Vector3(-50, 0, 18).normalized()}]}
			for cx in [0.0, 70.0]:
				var o := Vector3(cx, 0, 0)
				for p in _ring(4, 10.0, 0.0, 90.0) + _ring(8, 22.0, 0.0, 45.0):
					L.motes.append(p + o)
				for p in _ring(8, 26.0, 22.5, 45.0):
					L.shades.append(p + o)
		3:
			L = {"name": "Đảo Chuông", "start": Vector3(0, 0, -28), "every": 360, "max": 10, "speed_mul": 4.5 / 4.0,
				"lanterns": [Vector3(0, 6, 6), Vector3(18, 3, 10), Vector3(-18, 3, 10), Vector3(35, 0, -10), Vector3(-35, 0, -10), Vector3(20, 0, -35), Vector3(-20, 0, -35)],
				"motes": _ring(18, 34.0, 0.0, 20.0) + _ring(8, 18.0, 20.0, 20.0, 3.0) + _ring(4, 5.0, 45.0, 90.0, 6.0),
				"shades": _ring(16, 43.0, 0.0, 22.5), "charms": [Vector3(30, 0, 25), Vector3(-30, 0, 25)], "drifters": true, "wind": true,
				"pads": [{"pos": Vector3(0, 3, 13), "vy": 12.0, "h": 8.0, "dir": Vector3(0, 0, -1)}]}
	L["night"] = n
	return L


static func _ring(n: int, r: float, a0: float, step: float, y := 0.0) -> Array:
	var out := []
	for k in n:
		out.append(_polar(r, a0 + k * step, y))
	return out


static func _polar(r: float, deg: float, y := 0.0) -> Vector3:
	var a := deg_to_rad(deg)
	return Vector3(r * cos(a), y, r * sin(a))


static func xz(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Độ cao mặt đất tại (x, z) của Đêm n, NO_GROUND nếu là biển mây.
static func ground_at(n: int, x: float, z: float) -> float:
	var r := Vector2(x, z).length()
	match n:
		1:
			return 0.0 if r <= 40.0 else NO_GROUND
		2:
			if r <= 28.0 or Vector2(x - 70.0, z).length() <= 28.0 or (x >= 26.0 and x <= 44.0 and absf(z) <= 2.0):
				return 0.0
			return NO_GROUND
		3:
			if r > 45.0:
				return NO_GROUND
			if r <= 8.0:
				return 6.0
			if r >= 12.0 and r <= 24.0 and z > 0.0:
				return 3.0
			for a in [30.0, 150.0]:
				var d := Vector2(cos(deg_to_rad(a)), sin(deg_to_rad(a)))
				var s := Vector2(x, z).dot(d)
				var lat := absf(Vector2(x, z).cross(d))
				if lat <= 1.5 and s >= 24.0 and s <= 30.0:
					return 3.0 * (30.0 - s) / 6.0
			return 0.0
	return NO_GROUND


static func blocked_by_tower(n: int, p: Vector3) -> bool:
	return n == 3 and Vector2(p.x, p.z).length() < TOWER_R and p.y < TOWER_TOP


static func load_tuning() -> Dictionary:
	var f := FileAccess.open("res://game.contract.json", FileAccess.READ)
	return JSON.parse_string(f.get_as_text())["tuning"]


var T: Dictionary
var S: Dictionary
var LV: Dictionary
var night := 1
var rng := RandomNumberGenerator.new()
var events: Array = []
var steps := 0          # sim_tick: số bước gameplay đã chạy (đứng yên khi tạm dừng)
var paused := false
var state := "playing"
var dur0 := 300.0
var time_left := 300.0
var score := 0

var p_pos := Vector3.ZERO
var p_vel := Vector3.ZERO
var p_face := Vector3(0, 0, 1)
var grounded := true
var launched := false
var launch_h := Vector3.ZERO
var flames := 3
var carried := 0
var invuln := 0
var pulse_cd := 0
var dash_cd := 0
var dash_t := 0
var dash_dir := Vector3.ZERO
var charm_t := 0
var fall_wait := 0
var wind_on := false
var wind_t := 0
var wind_dir_deg := 0.0
var wind_enabled := true

var motes: Array = []     # {id, pos, kind, ttl, born}
var shades: Array = []    # {id, pos, off, state, t, push_t, dir, target, born}
var drifters: Array = []  # {id, pos, state, t, stolen, target, born}
var charms: Array = []    # {id, pos, available, respawn}
var lanterns: Array = []  # {id, pos, lit, deposited}
var next_mote := 1
var next_shade := 1
var next_drifter := 1
var random_motes := true
var random_shades := true
var random_drifters := true
var prev := {"jump": false, "interact": false, "pulse": false, "dash": false, "pause": false}


func _init(seed: int, tuning: Dictionary, n := 1) -> void:
	T = tuning
	S = tuning["score"]
	night = n
	LV = level(n)
	rng.seed = seed
	dur0 = float(T["night%d_duration_s" % n])
	time_left = dur0
	flames = int(T["flames"])
	p_pos = LV.start
	random_drifters = LV.drifters
	wind_enabled = LV.wind
	for i in LV.lanterns.size():
		lanterns.append({"id": "L%d" % (i + 1), "pos": LV.lanterns[i], "lit": false, "deposited": 0})
	for i in LV.charms.size():
		charms.append({"id": "C%d" % (i + 1), "pos": LV.charms[i], "available": true, "respawn": 0})
	var pts: Array = LV.motes.duplicate()
	for i in MOTE_INIT:
		var j := rng.randi_range(0, pts.size() - 1)
		_add_mote(pts[j], "random", -1)
		pts.remove_at(j)


func ground(x: float, z: float) -> float:
	return ground_at(night, x, z)


func _add_mote(pos: Vector3, kind: String, ttl: int) -> void:
	motes.append({"id": "M%d" % next_mote, "pos": pos, "kind": kind, "ttl": ttl, "born": steps})
	next_mote += 1


func _num_id(id: String) -> int:
	return int(id.substr(1)) if id.substr(1).is_valid_int() else 0


func add_shade(pos: Vector3, id := "", st := "wander", t := -1) -> void:
	if t < 0:  # scenario khai state mà thiếu state_ticks_left: dùng đủ thời lượng của trạng thái
		t = {"stunned": _ticks("pulse_stun_s"), "recoil": RECOIL_TICKS, "spawning": SHADE_SPAWNING}.get(st, 0)
	if id == "":
		id = "S%d" % next_shade
	next_shade = max(next_shade, _num_id(id) + 1)
	var g := ground(pos.x, pos.z)
	var off: float = pos.y - g if g > NO_GROUND else SHADE_Y
	shades.append({"id": id, "pos": pos, "off": off, "state": st, "t": t, "push_t": 0, "dir": Vector3.RIGHT, "target": pos, "born": steps})


func add_drifter(pos: Vector3, id := "", st := "idle", stolen := 0, t := -1) -> void:
	if t < 0:
		t = FLEE_TICKS if st == "flee" else 0
	if id == "":
		id = "D%d" % next_drifter
	next_drifter = max(next_drifter, _num_id(id) + 1)
	drifters.append({"id": id, "pos": pos, "state": st, "t": t, "stolen": stolen, "target": pos, "born": steps})


## Dựng scenario: không phát event, không cộng điểm. Đã được validate ở driver.
func apply_scenario(sc: Dictionary) -> void:
	random_motes = sc.get("random_motes", true)
	random_shades = sc.get("random_shades", true)
	random_drifters = sc.get("random_drifters", LV.drifters) and LV.drifters
	wind_enabled = sc.get("wind_enabled", LV.wind) and LV.wind
	if sc.has("motes") or not random_motes:
		motes.clear()
		for m in sc.get("motes", []):
			_add_mote(Vector3(m[0], m[1], m[2]), "random", -1)
	if sc.has("shades"):
		shades.clear()
		for s in sc["shades"]:
			var p: Array = s["pos"]
			add_shade(Vector3(p[0], p[1], p[2]), s.get("id", ""), s.get("state", "wander"), int(s.get("state_ticks_left", -1)))
	if sc.has("drifters"):
		drifters.clear()
		for d in sc["drifters"]:
			var p: Array = d["pos"]
			add_drifter(Vector3(p[0], p[1], p[2]), d.get("id", ""), d.get("state", "idle"), int(d.get("stolen", 0)), int(d.get("state_ticks_left", -1)))
	if sc.has("charms"):
		var old := charms.duplicate()
		charms.clear()
		for c in sc["charms"]:
			var pos: Vector3 = LV.charms[0] if not LV.charms.is_empty() else Vector3.ZERO
			for o in old:
				if o.id == c.get("id", ""):
					pos = o.pos
			if c.has("pos"):
				pos = Vector3(c["pos"][0], c["pos"][1], c["pos"][2])
			charms.append({"id": c.get("id", "C%d" % (charms.size() + 1)), "pos": pos,
				"available": c.get("available", true), "respawn": int(c.get("respawn_ticks", 0))})
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
		var g := ground(p_pos.x, p_pos.z)
		grounded = g > NO_GROUND and absf(p_pos.y - g) <= EPS
	for k in [["carried", "carried"], ["flames", "flames"], ["invuln_ticks", "invuln"], ["dash_cd_ticks", "dash_cd"],
			["pulse_cd_ticks", "pulse_cd"], ["charm_ticks", "charm_t"]]:
		if pl.has(k[0]):
			set(k[1], int(pl[k[0]]))
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


func _ticks(key: String) -> int:
	return int(round(float(T[key]) * 60.0))


## Một tick 1/60 s. inp: {move:[x,z], cam_yaw_deg, jump, interact, pulse, dash, pause}
func step(inp: Dictionary) -> void:
	if state != "playing":
		return
	# 1. input (pause trước)
	if _edge(inp, "pause"):
		paused = not paused
		_emit("paused" if paused else "resumed", {})
		if paused:
			return
	if paused:
		for k in ["jump", "interact", "pulse", "dash"]:
			_edge(inp, k)
		return
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
	charm_t = max(0, charm_t - 1)
	for s in shades:
		s["t"] = max(0, s["t"] - 1)
	for d in drifters:
		d["t"] = max(0, d["t"] - 1)
	for c in charms:
		if not c.available:
			c.respawn = max(0, c.respawn - 1)
			if c.respawn == 0:
				c.available = true
	for m in motes.duplicate():
		if m["ttl"] > 0:
			m["ttl"] -= 1
			if m["ttl"] == 0:
				motes.erase(m)
	_update_wind()
	# 3. di chuyển Mây + rơi
	if fall_wait > 0:
		fall_wait -= 1
		if fall_wait == 0:
			p_pos = LV.start
			p_vel = Vector3.ZERO
			grounded = true
			launched = false
			dash_t = 0
			invuln = _ticks("invuln_s")
	else:
		_move_player(inp, jump, dash)
	var active := fall_wait == 0
	# 4. nhặt đom đóm và bùa
	if active:
		for m in motes.duplicate():
			if carried >= int(T["carry_capacity"]):
				break
			if m["born"] < steps and _touch(m["pos"], float(T["pickup_radius"])):
				motes.erase(m)
				carried += 1
				_emit("mote_picked", {"carried": carried})
		for c in charms:
			if c.available and _touch(c.pos, float(T["pickup_radius"])):
				c.available = false
				c.respawn = CHARM_RESPAWN
				charm_t = CHARM_TICKS
				_emit("charm_picked", {"charm_id": c.id, "charm_ticks": CHARM_TICKS})
	# 5. tương tác đèn
	if active and interact:
		_interact()
	# 6. vùng an toàn: bóng bên trong đèn sáng bị đẩy ra mép trong tối đa 30 tick
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
	# 8. Bóng Mực và Gió Lạc
	for s in shades:
		if _in_safe(s["pos"]).is_empty():  # bóng đang bị đẩy khỏi vùng an toàn thì không tự di chuyển
			_move_shade(s, active)
	for d in drifters.duplicate():
		_move_drifter(d, active)
	# 9. chạm: Gió Lạc cướp trước, rồi Bóng Mực
	if active:
		for d in drifters:
			if d.state == "chase" and d.born < steps and xz(p_pos, d.pos) <= DRIFT_TOUCH + EPS and carried > 0:
				var amt: int = min(DRIFT_STEAL, carried)
				carried -= amt
				d.stolen = amt
				d.state = "flee"
				d.t = FLEE_TICKS
				_emit("drifter_steal", {"drifter_id": d.id, "amount": amt, "carried": carried})
		if invuln == 0:
			var by_id := shades.duplicate()
			by_id.sort_custom(func(a, b): return _num_id(a.id) < _num_id(b.id))
			for s in by_id:
				if s["state"] in ["wander", "chase"] and s.born < steps and _in_safe(s["pos"]).is_empty() \
						and _touch(s["pos"], float(T["shade_hit_radius"])):
					_hit(s)
					break
	# 10. sinh
	_spawn()
	# 11. thắng/thua
	if flames <= 0:
		_end("lost", "no_flames")
	elif lanterns.all(func(L): return L["lit"]):
		score += int(floor(max(time_left, 0.0))) * int(S["per_second_left"]) + flames * int(S["per_flame_left"])
		_end("won", "all_lit")
	elif time_left <= 1e-9:
		_end("lost", "dawn")


func _touch(pos: Vector3, r: float) -> bool:
	return xz(p_pos, pos) <= r + EPS and absf(p_pos.y - pos.y) <= DY_MAX


func _end(result: String, reason: String) -> void:
	state = result
	_emit("game_over", {"result": result, "reason": reason})


func _update_wind() -> void:
	if not wind_enabled:
		wind_on = false
		return
	if wind_on:
		wind_t -= 1
		if wind_t <= 0:
			wind_on = false
	elif steps % WIND_EVERY == 0:
		wind_on = true
		wind_t = WIND_TICKS
		wind_dir_deg = snappedf(rng.randf_range(0.0, 360.0), 0.001)


## Số tick tới cơn gió kế tiếp (cho GUI báo trước 2 s).
func wind_warning() -> bool:
	return wind_enabled and not wind_on and (WIND_EVERY - steps % WIND_EVERY) <= WIND_WARN


func _move_player(inp: Dictionary, jump: bool, dash: bool) -> void:
	var m: Array = inp.get("move", [0, 0])
	var v := Vector2(m[0], m[1])
	if v.length() > 1.0:
		v = v.normalized()
	var th := deg_to_rad(float(inp.get("cam_yaw_deg", 0.0)))
	var dir := Vector3(v.x * cos(th) + v.y * sin(th), 0, -v.x * sin(th) + v.y * cos(th))
	if dir.length() > 0.0001:
		p_face = dir.normalized()
	if dash and dash_t == 0 and (dash_cd == 0 or charm_t > 0):
		dash_t = DASH_TICKS
		dash_cd = 0 if charm_t > 0 else _ticks("dash_cooldown_s")
		dash_dir = p_face
		_emit("dash", {})
	var was_grounded := grounded
	if dash_t > 0:
		dash_t -= 1
		var ds := float(T["dash_speed"])
		p_vel = Vector3(dash_dir.x * ds, 0, dash_dir.z * ds)
	else:
		var hv := launch_h if launched else dir * (CHARM_SPEED if charm_t > 0 else float(T["player_speed"]))
		p_vel = Vector3(hv.x, p_vel.y, hv.z)
		if jump and grounded:
			p_vel.y = JUMP_V
			grounded = false
		p_vel.y -= GRAVITY * DT
	var h := Vector3(p_vel.x, 0, p_vel.z) * DT
	if wind_on:
		h += Vector3(cos(deg_to_rad(wind_dir_deg)), 0, sin(deg_to_rad(wind_dir_deg))) * WIND_SPEED * DT
	var nxt := p_pos + h
	var gn := ground(nxt.x, nxt.z)
	if (gn > NO_GROUND and gn > p_pos.y + STEP_UP) or blocked_by_tower(night, nxt):
		nxt = p_pos  # vách đứng / tháp chuông: không đi qua
	nxt.y = p_pos.y + p_vel.y * DT
	p_pos = nxt
	var g := ground(p_pos.x, p_pos.z)
	if g > NO_GROUND and p_vel.y <= 0.0 and (p_pos.y <= g + EPS and p_pos.y >= g - STEP_UP
			or was_grounded and dash_t == 0 and p_pos.y - g <= STEP_UP and p_pos.y > g):
		p_pos.y = g
		p_vel.y = 0.0
		grounded = true
		launched = false
	else:
		grounded = false
	if grounded and not launched:
		for pad in LV.pads:
			if xz(p_pos, pad.pos) <= 1.0 + EPS and absf(p_pos.y - pad.pos.y) <= 0.05:
				launched = true
				launch_h = pad.dir * pad.h
				p_vel = Vector3(launch_h.x, pad.vy, launch_h.z)
				grounded = false
	if p_pos.y < FALL_Y:
		flames -= 1
		var lost := carried
		carried = 0
		fall_wait = 60
		p_vel = Vector3.ZERO
		launched = false
		dash_t = 0
		_emit("player_hit", {"by": "fall", "flames": max(flames, 0), "dropped": 0, "lost": lost})


func _interact() -> void:
	var best: Dictionary = {}
	var bd := INF
	for L in lanterns:
		if L["lit"] or absf(p_pos.y - L["pos"].y) > DY_MAX:
			continue
		var d := xz(p_pos, L["pos"])
		if d <= float(T["interact_radius"]) + EPS and d < bd - EPS:
			best = L
			bd = d
	if best.is_empty() or carried == 0:
		return
	var cost := int(T["lantern_cost"])
	var amt: int = clampi(cost - int(best["deposited"]), 0, carried)
	if amt > 0:
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
	pulse_cd = _ticks("pulse_cooldown_s")
	var c := p_pos + Vector3(0, PULSE_H, 0)  # v1.1: khoảng cách 3D từ chân + 0.8 m
	var r := float(T["pulse_radius"]) + EPS
	var ids := []
	for s in shades:
		if c.distance_to(s["pos"]) <= r:
			var d: Vector3 = s["pos"] - p_pos
			d.y = 0
			s["dir"] = d.normalized() if d.length() > 0.0001 else Vector3.RIGHT
			s["state"] = "stunned"
			s["t"] = _ticks("pulse_stun_s")
			s["push_t"] = PUSH_TICKS
			score += int(S["per_stun"])
			ids.append(s["id"])
	for d in drifters:
		if c.distance_to(d.pos) <= r:
			if d.state == "chase":
				d.state = "flee"
				d.t = FLEE_TICKS
			elif d.state == "flee" and d.stolen > 0:
				var n: int = d.stolen
				for i in n:
					_add_mote(Vector3(d.pos.x, _ground_or(d.pos), d.pos.z), "dropped", DROP_TTL)
				d.stolen = 0
				d.t = DROP_FLEE_TICKS
				_emit("drifter_drop", {"drifter_id": d.id, "amount": n})
	_emit("pulse", {"stunned_ids": ids})


func _ground_or(p: Vector3) -> float:
	var g := ground(p.x, p.z)
	return g if g > NO_GROUND else p_pos.y


## Di chuyển ngang có xét địa hình; dừng nếu gặp vách/biển mây.
func _shade_step(s: Dictionary, delta: Vector3) -> void:
	var nxt: Vector3 = s["pos"] + Vector3(delta.x, 0, delta.z)
	var g0 := ground(s["pos"].x, s["pos"].z)
	var g := ground(nxt.x, nxt.z)
	if g <= NO_GROUND or (g0 > NO_GROUND and g > g0 + STEP_UP) or blocked_by_tower(night, nxt - Vector3(0, s["off"], 0)):
		return
	s["pos"] = Vector3(nxt.x, g + s["off"], nxt.z)


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
			_shade_step(s, s["dir"] * (float(T["pulse_push_m"]) / PUSH_TICKS))
		if s["t"] == 0:
			s["state"] = "wander"
	elif stv == "recoil":
		_shade_step(s, s["dir"] * (RECOIL_M / RECOIL_TICKS))
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
		var sp := float(T["shade_speed"]) * float(LV.speed_mul) if s["state"] == "chase" else WANDER_SPEED
		var to := Vector3(goal.x - s["pos"].x, 0, goal.z - s["pos"].z)
		if to.length() <= sp * DT:
			_shade_step(s, to)
			if s["state"] == "wander":
				s["target"] = _random_point()
		else:
			var pre: Vector3 = s["pos"]
			_shade_step(s, to.normalized() * sp * DT)
			if s["state"] == "wander" and pre == s["pos"]:
				s["target"] = _random_point()
	# bóng ở ngoài vùng an toàn bị chặn ở mép
	var sr := float(T["safe_radius"])
	for L in lanterns:
		if L["lit"] and xz(before, L["pos"]) >= sr - 1e-3 and xz(s["pos"], L["pos"]) < sr:
			var d: Vector3 = s["pos"] - L["pos"]
			d.y = 0
			var e: Vector3 = L["pos"] + d.normalized() * sr
			s["pos"] = Vector3(e.x, s["pos"].y, e.z)


func _random_point() -> Vector3:
	var pts: Array = LV.motes
	return pts[rng.randi_range(0, pts.size() - 1)]


func _move_drifter(d: Dictionary, player_active: bool) -> void:
	var dist := xz(d.pos, p_pos)
	match d.state:
		"idle":
			if player_active and carried >= DRIFT_MIN_CARRY and dist <= DRIFT_DETECT:
				d.state = "chase"
		"chase":
			if not (player_active and carried >= DRIFT_MIN_CARRY and dist <= DRIFT_DETECT):
				d.state = "idle"
		"flee":
			if d.t == 0:
				drifters.erase(d)
				return
	var goal: Vector3
	var sp := DRIFT_SPEED
	if d.state == "chase":
		goal = p_pos
	elif d.state == "flee":
		var away := Vector3(d.pos.x - p_pos.x, 0, d.pos.z - p_pos.z)
		goal = d.pos + (away.normalized() if away.length() > 0.0001 else Vector3.RIGHT) * 10.0
	else:
		goal = d.target
		sp = DRIFT_IDLE_SPEED
	var to := Vector3(goal.x - d.pos.x, 0, goal.z - d.pos.z)
	if to.length() <= sp * DT:
		d.pos = Vector3(goal.x, d.pos.y, goal.z)
		if d.state == "idle":
			d.target = _random_point() + Vector3(0, 1.5, 0)
	else:
		d.pos += to.normalized() * sp * DT


func _hit(s: Dictionary) -> void:
	flames -= 1
	var dropped := int(floor(carried / 2.0))
	carried -= dropped
	for i in dropped:
		var a := rng.randf_range(0.0, TAU)
		var r := rng.randf_range(1.5, 2.5)
		var p := Vector3(p_pos.x + r * cos(a), 0.0, p_pos.z + r * sin(a))
		p.y = _ground_or(p)
		_add_mote(p, "dropped", DROP_TTL)
	invuln = _ticks("invuln_s")
	var d: Vector3 = s["pos"] - p_pos
	d.y = 0
	s["dir"] = d.normalized() if d.length() > 0.0001 else Vector3.RIGHT
	s["state"] = "recoil"
	s["t"] = RECOIL_TICKS
	_emit("player_hit", {"by": "shade", "flames": max(flames, 0), "dropped": dropped})


func _spawn() -> void:
	if random_motes and steps % MOTE_EVERY == 0 and motes.size() < MOTE_CAP:
		var free := []
		for pt in LV.motes:
			if motes.all(func(m): return m["pos"].distance_to(pt) > 0.5):
				free.append(pt)
		if not free.is_empty():
			_add_mote(free[rng.randi_range(0, free.size() - 1)], "random", -1)
	if random_drifters and steps % DRIFT_EVERY == 0 and drifters.size() < DRIFT_MAX:
		var pt: Vector3 = LV.shades[rng.randi_range(0, LV.shades.size() - 1)] + Vector3(0, 1.5, 0)
		var id := "D%d" % next_drifter
		add_drifter(pt, id)
		drifters[-1].target = pt
	if not random_shades or steps < SHADE_FIRST or (steps - SHADE_FIRST) % int(LV.every) != 0:
		return
	var n := 2 if steps == SHADE_FIRST else 1
	for i in n:
		if shades.size() >= int(LV.max):
			return
		var ok: Array = LV.shades.filter(func(pt): return xz(pt, p_pos) >= SHADE_MIN_DIST and _in_safe(pt).is_empty())
		if ok.is_empty():
			return
		var id := "S%d" % next_shade
		var pt: Vector3 = ok[rng.randi_range(0, ok.size() - 1)]
		add_shade(Vector3(pt.x, ground(pt.x, pt.z) + SHADE_Y, pt.z), id, "spawning", SHADE_SPAWNING)
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
		ms.append({"id": m["id"], "pos": v3(m["pos"]), "kind": m["kind"], "ttl_s": r3(m["ttl"] * DT) if m["ttl"] > 0 else null})
	var ds := []
	for d in drifters:
		ds.append({"id": d.id, "pos": v3(d.pos), "state": d.state, "stolen": d.stolen})
	var cs := []
	for c in charms:
		cs.append({"id": c.id, "available": c.available, "respawn_s": r3(c.respawn * DT)})
	return {"type": "snapshot", "tick": tick, "sim_tick": steps, "night": night,
		"state": "paused" if paused and state == "playing" else state,
		"time_left_s": r3(time_left), "score": score,
		"wind": {"active": wind_on, "dir_deg": r3(wind_dir_deg)},
		"player": {"pos": v3(p_pos), "flames": flames, "carried": carried, "vel": v3(p_vel),
			"grounded": grounded, "invuln": invuln > 0, "dash_cd_s": r3(dash_cd * DT),
			"pulse_cd_s": r3(pulse_cd * DT), "charm_s": r3(charm_t * DT)},
		"lanterns": ls, "shades": ss, "motes_active": motes.size(), "motes": ms, "drifters": ds, "charms": cs}
