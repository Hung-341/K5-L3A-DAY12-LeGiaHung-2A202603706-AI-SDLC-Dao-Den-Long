"""Scenario tests chạy headless theo Test Contract v1.0. Chạy: python tests/run_tests.py [tên_test ...]"""
import json, math, os, re, shutil, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.environ.get("GODOT") or shutil.which("godot") or r"D:\VinAI\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
TMP = tempfile.mkdtemp(prefix="ddl_")
CONTRACT = json.load(open(os.path.join(ROOT, "game.contract.json"), encoding="utf-8"))
T = CONTRACT["tuning"]
EMPTY = {"random_motes": False, "random_shades": False, "random_drifters": False, "wind_enabled": False,
         "motes": [], "shades": [], "drifters": []}


def _write(name, obj):
    p = os.path.join(TMP, name)
    with open(p, "w", encoding="utf-8") as f:
        f.write(obj if isinstance(obj, str) else json.dumps(obj))
    return p


def run(seed=1, ticks=60, scenario=None, inputs=None, every=10, tag="r", night=1):
    out = os.path.join(TMP, tag + ".jsonl")
    args = [GODOT, "--headless", "--path", ROOT, "--", "--headless-run", "--seed", str(seed), "--night", str(night),
            "--ticks", str(ticks), "--out", out, "--snapshot-every", str(every)]
    if scenario is not None:
        args += ["--scenario", _write(tag + "_sc.json", scenario)]
    if inputs is not None:
        args += ["--inputs", _write(tag + "_in.json", inputs)]
    p = subprocess.run(args, capture_output=True, text=True, timeout=120)
    lines = []
    if os.path.exists(out):
        lines = [json.loads(l) for l in open(out, encoding="utf-8") if l.strip()]
    return p.returncode, lines, out


def sc(**kw):
    d = dict(EMPTY)
    d.update(kw)
    return d


def events(lines, name):
    return [l for l in lines if l["type"] == "event" and l["name"] == name]


def snap(lines, tick):
    return next(l for l in lines if l["type"] == "snapshot" and l["tick"] == tick)


def end(lines):
    assert lines and lines[-1]["type"] == "end", "dòng cuối phải là end"
    return lines[-1]


def near(a, b, tol=0.02):
    return all(abs(x - y) <= tol for x, y in zip(a, b))


# ---------- Task 1: tất định + tốc độ ----------
def test_determinism():
    inp = {"frames": [{"tick": 0, "move": [1, 0.5]}, {"tick": 100, "pulse": True}, {"tick": 101, "pulse": False}]}
    c1, _, o1 = run(seed=7, ticks=1800, inputs=inp, tag="det1")
    c2, _, o2 = run(seed=7, ticks=1800, inputs=inp, tag="det2")
    assert c1 == 0 and c2 == 0
    assert open(o1, "rb").read() == open(o2, "rb").read(), "hai lần chạy khác nhau"


def test_speed():
    c, L, _ = run(ticks=60, scenario=sc(), inputs={"frames": [{"tick": 0, "move": [0, 1]}]})
    assert c == 0
    assert snap(L, 0)["player"]["pos"] == [0, 0, 0] or near(snap(L, 0)["player"]["pos"], [0, 0, 0], 0)
    assert near(snap(L, 60)["player"]["pos"], [0, 0, T["player_speed"]]), snap(L, 60)["player"]["pos"]
    assert end(L)["ticks"] == 60


# ---------- Task 2: contract ----------
def test_contract_fields():
    for k in ["contract_version", "team", "build_cmd", "run_cmd", "headless_cmd", "tuning"]:
        assert k in CONTRACT, k
    for k in ["player_speed", "carry_capacity", "lantern_cost", "pickup_radius", "interact_radius", "pulse_cost",
              "pulse_radius", "night1_duration_s", "flames", "invuln_s", "hit_drop_ratio", "pulse_stun_s",
              "pulse_push_m", "pulse_cooldown_s", "safe_radius", "shade_speed", "shade_hit_radius", "fall_enabled"]:
        assert k in T, k
    assert T["lantern_count_night1"] == 5
    # v1.2 (Ticket-03) thay công thức điểm: thêm per_relight, per_stun_drain, per_lit_at_dawn
    assert {"per_mote", "per_lantern", "per_relight", "per_stun", "per_stun_drain", "per_lit_at_dawn",
            "per_flame_left"} <= set(T["score"])
    for k in ["fuel_max", "fuel_decay_per_s", "fuel_per_mote", "relight_cost", "win_ratio", "drain_per_s",
              "low_fuel_threshold", "capacity_max"]:
        assert k in T, k
    # v1.3 (Ticket-04): thêm bench_cmd, soak_cmd
    assert CONTRACT["contract_version"] == "1.3" and "bench_cmd" in CONTRACT and "soak_cmd" in CONTRACT


# ---------- Task 3: inputs/scenario ----------
def test_bad_tick_order():
    c, _, _ = run(inputs={"frames": [{"tick": 5}, {"tick": 5}]}, tag="bto")
    assert c == 2, c


def test_bad_json():
    c, _, _ = run(inputs="{frames: [", tag="bj")
    assert c == 2, c


def test_bad_move():
    c, _, _ = run(inputs={"frames": [{"tick": 0, "move": [2, 0]}]}, tag="bm")
    assert c == 2, c


def test_bad_scenario():
    c, _, _ = run(scenario={"player": {"pos": "x"}}, tag="bs")
    assert c == 2, c


def test_normalize():
    c, L, _ = run(ticks=60, scenario=sc(), inputs={"frames": [{"tick": 0, "move": [1, 1]}]})
    p = snap(L, 60)["player"]["pos"]
    assert abs(math.hypot(p[0], p[2]) - T["player_speed"]) < 0.02, p


def test_yaw90():
    c, L, _ = run(ticks=60, scenario=sc(), inputs={"frames": [{"tick": 0, "move": [0, 1], "cam_yaw_deg": 90}]})
    assert near(snap(L, 60)["player"]["pos"], [T["player_speed"], 0, 0]), snap(L, 60)["player"]["pos"]


def test_scenario_player():
    c, L, _ = run(ticks=10, scenario=sc(player={"pos": [3, 0, 4], "carried": 2, "flames": 50}, time_left_s=100))
    s = snap(L, 0)
    assert near(s["player"]["pos"], [3, 0, 4]) and s["player"]["carried"] == 2 and s["player"]["flames"] == 50
    assert s["time_left_s"] == 100 and snap(L, 10)["time_left_s"] == round(100 - 10 / 60, 3)


# ---------- Task 4: luật chơi ----------
def test_pickup():
    c, L, _ = run(ticks=5, scenario=sc(motes=[[0, 0, T["pickup_radius"]]]))
    e = events(L, "mote_picked")
    assert len(e) == 1 and e[0]["data"] == {"carried": 1} and e[0]["tick"] == 1, e
    assert end(L)["score"] == 0  # per_mote cộng khi nạp, không cộng khi nhặt


def test_capacity():
    cap = T["carry_capacity"]
    c, L, _ = run(ticks=5, scenario=sc(player={"pos": [0, 0, 0], "carried": cap}, motes=[[0, 0, 0.5]]))
    assert not events(L, "mote_picked") and snap(L, 0)["motes_active"] == 1


def _interact(t=0):
    return {"frames": [{"tick": t, "interact": True}, {"tick": t + 1, "interact": False}]}


def test_deposit_lit():
    cost = T["lantern_cost"]
    c, L, _ = run(ticks=5, scenario=sc(player={"pos": [0, 0, 23], "carried": cost},
                                       lanterns=[{"id": "L1", "pos": [0, 0, 25]}]), inputs=_interact())
    d = events(L, "deposit")
    assert d and d[0]["data"] == {"lantern_id": "L1", "amount": cost, "deposited": cost}, d
    # v1.2 (Ticket-03) thêm trường relight vào lantern_lit
    assert events(L, "lantern_lit")[0]["data"] == {"lantern_id": "L1", "relight": False}
    assert end(L)["score"] == T["score"]["per_lantern"] + cost * T["score"]["per_mote"]


def test_partial():
    cost = T["lantern_cost"]
    c, L, _ = run(ticks=5, scenario=sc(player={"pos": [0, 0, 23.5], "carried": cost + 2}), inputs=_interact())
    assert events(L, "deposit")[0]["data"]["amount"] == cost
    assert snap(L, 0)["player"]["carried"] == cost + 2 and end(L)["state"] == "playing"
    c, L, _ = run(ticks=10, scenario=sc(player={"pos": [0, 0, 23.5], "carried": cost + 2}), inputs=_interact())
    assert snap(L, 10)["player"]["carried"] == 2


def test_deposit_out_of_range():
    c, L, _ = run(ticks=5, scenario=sc(player={"pos": [0, 0, 22.9], "carried": 3}), inputs=_interact())
    assert not events(L, "deposit")


def test_pulse():
    r = T["pulse_radius"] - 0.1
    c, L, _ = run(ticks=30, scenario=sc(player={"pos": [0, 0, 0], "carried": T["pulse_cost"]},
                                        shades=[{"id": "S1", "pos": [r, 1, 0]}]),
                  inputs={"frames": [{"tick": 0, "pulse": True}, {"tick": 1, "pulse": False}]})
    p = events(L, "pulse")
    assert p and p[0]["data"] == {"stunned_ids": ["S1"]} and p[0]["tick"] == 1, p
    s = snap(L, 20)  # đẩy lùi xong sau 15 tick
    assert s["player"]["carried"] == 0 and s["shades"][0]["state"] == "stunned"
    assert s["shades"][0]["pos"][0] >= r + T["pulse_push_m"] - 0.01, s["shades"][0]
    assert end(L)["score"] == T["score"]["per_stun"]


def test_pulse_3d_edge():
    # v1.1 (Ticket-02) thay luật v1.0: tâm = chân + 0.8 m, khoảng cách 3D <= r.
    # Thay test_pulse_xz_edge của Phase 1 (đo XZ): luật cũ bị thay thế, xem docs/notes/phase2.md.
    r = T["pulse_radius"]
    on = math.sqrt(r * r - 0.2 ** 2) - 0.001   # bóng tâm y=1.0 → chênh cao 0.2
    c, L, _ = run(ticks=3, scenario=sc(player={"carried": T["pulse_cost"]},
                                       shades=[{"id": "S1", "pos": [on, 1, 0]}, {"id": "S2", "pos": [0, 1, -(r + 0.01)]}]),
                  inputs={"frames": [{"tick": 0, "pulse": True}]})
    assert events(L, "pulse")[0]["data"] == {"stunned_ids": ["S1"]}, events(L, "pulse")


def test_deposit_overfull_scenario():
    cost = T["lantern_cost"]
    c, L, _ = run(ticks=3, scenario=sc(player={"pos": [0, 0, 23], "carried": 5},
                                       lanterns=[{"id": "L1", "deposited": cost + 2}]), inputs=_interact())
    assert all(e["data"]["amount"] > 0 for e in events(L, "deposit")), events(L, "deposit")
    assert end(L)["score"] >= 0 and snap(L, 0)["player"]["carried"] == 5


def test_chase_exact_tick():
    # bóng cách 3 m, tốc độ 4 m/s, chạm ở 1 m: cần đúng (3-1)/4*60 = 30 tick
    c, L, _ = run(ticks=40, scenario=sc(shades=[{"id": "S1", "pos": [3, 1, 0]}]))
    h = events(L, "player_hit")
    assert h and h[0]["tick"] == int((3 - T["shade_hit_radius"]) / T["shade_speed"] * 60), h


def test_pulse_cd():
    cd = int(T["pulse_cooldown_s"] * 60)
    fr = [{"tick": 0, "pulse": True}, {"tick": 1, "pulse": False}, {"tick": 10, "pulse": True},
          {"tick": 11, "pulse": False}, {"tick": cd + 2, "pulse": True}]
    c, L, _ = run(ticks=cd + 10, scenario=sc(player={"pos": [0, 0, 0], "carried": 8}), inputs={"frames": fr})
    assert [e["tick"] for e in events(L, "pulse")] == [1, cd + 3], events(L, "pulse")


def test_pulse_poor():
    c, L, _ = run(ticks=5, scenario=sc(player={"pos": [0, 0, 0], "carried": T["pulse_cost"] - 1}),
                  inputs={"frames": [{"tick": 0, "pulse": True}]})
    assert not events(L, "pulse") and snap(L, 0)["player"]["carried"] == T["pulse_cost"] - 1


def test_hit():
    inv = int(T["invuln_s"] * 60)
    c, L, _ = run(ticks=inv - 10, scenario=sc(player={"pos": [0, 0, 0], "carried": 5},
                                              shades=[{"id": "S1", "pos": [0.5, 1, 0]}]))
    h = events(L, "player_hit")
    assert len(h) == 1 and h[0]["data"] == {"by": "shade", "flames": T["flames"] - 1, "dropped": 2}, h


def test_no_flames():
    c, L, _ = run(ticks=2000, scenario=sc(shades=[{"id": "S1", "pos": [0.5, 1, 0]}]))
    assert len(events(L, "player_hit")) == T["flames"]
    go = events(L, "game_over")
    assert go and go[0]["data"] == {"result": "lost", "reason": "no_flames"}
    assert end(L)["state"] == "lost" and end(L)["ticks"] < 2000


def test_safe():
    safe = T["safe_radius"]
    c, L, _ = run(ticks=600, scenario=sc(player={"pos": [0, 0, 25]},
                                         lanterns=[{"id": "L1", "lit": True}],
                                         shades=[{"id": "S1", "pos": [0, 1, 12]}]))
    assert not events(L, "player_hit")
    for l in L:
        if l["type"] == "snapshot":
            sp = l["shades"][0]["pos"]
            assert math.hypot(sp[0], sp[2] - 25) >= safe - 0.01, sp


def test_prelit_no_score():
    c, L, _ = run(ticks=5, scenario=sc(lanterns=[{"id": "L1", "lit": True}]))
    assert end(L)["score"] == 0 and not events(L, "lantern_lit") and snap(L, 0)["lanterns"][0]["lit"]


# test_win (thắng sớm khi thắp hết đèn, reason all_lit) đã XÓA ở Phase 3:
# Ticket-03 thay luật thắng bằng "sống tới bình minh và đủ 60% đèn sáng" (dawn_survived), bỏ all_lit.
# Thay bằng test_no_early_win, test_dawn_survived, test_dawn_lost_below_ratio, test_night_thresholds.


def test_dawn():
    c, L, _ = run(ticks=200, scenario=sc(time_left_s=1))
    go = events(L, "game_over")
    assert go and go[0]["data"] == {"result": "lost", "reason": "dawn"} and go[0]["tick"] == 60, go
    assert end(L)["ticks"] == 60


def test_spawn():
    c, L, _ = run(seed=3, ticks=800, scenario={"random_motes": False, "motes": []})
    s = events(L, "shade_spawned")
    assert [(e["tick"], e["data"]["id"]) for e in s] == [(300, "S1"), (300, "S2"), (780, "S3")], s


def test_default_level():
    c, L, _ = run(seed=5, ticks=10)
    s = snap(L, 0)
    assert len(s["lanterns"]) == 5 and s["motes_active"] == 20 and s["player"]["flames"] == T["flames"]
    assert s["state"] == "playing" and s["time_left_s"] == T["night1_duration_s"]


# ---------- Phase 2 / Contract v1.1 ----------
def test_v11_snapshot_fields():
    c, L, _ = run(night=2, ticks=10)
    s = snap(L, 0)
    assert s["night"] == 2 and set(s["wind"]) == {"active", "dir_deg"}
    assert {"vel", "grounded", "invuln", "dash_cd_s", "pulse_cd_s", "charm_s"} <= set(s["player"])
    assert all({"id", "pos", "kind", "ttl_s"} <= set(m) for m in s["motes"])
    assert s["charms"] == [{"id": "C1", "available": True, "respawn_s": 0}] and s["drifters"] == []
    assert len(s["lanterns"]) == 6 and len(snap(run(night=3, ticks=1)[1], 0)["lanterns"]) == 7
    ns = events(L, "night_start")
    assert ns and ns[0]["data"] == {"night": 2}


def test_night_bad():
    c, _, _ = run(night=4, ticks=1, tag="n4")
    assert c != 0


def test_dash():
    fr = [{"tick": 0, "move": [0, 1], "dash": True}, {"tick": 1, "dash": False}, {"tick": 5, "dash": True},
          {"tick": 6, "dash": False}, {"tick": 90, "dash": True}, {"tick": 91, "dash": False}]
    c, L, _ = run(ticks=12, scenario=sc(), inputs={"frames": fr[:1]}, every=12)
    # 12 tick lướt 14 m/s = 2.8 m (không cộng tốc độ chạy)
    assert near(snap(L, 12)["player"]["pos"], [0, 0, 2.8]), snap(L, 12)["player"]["pos"]
    c, L, _ = run(ticks=100, scenario=sc(), inputs={"frames": fr})
    assert [e["tick"] for e in events(L, "dash")] == [1, 91], events(L, "dash")


def test_dash_air_keeps_height():
    fr = [{"tick": 0, "jump": True}, {"tick": 10, "dash": True}]
    c, L, _ = run(ticks=22, scenario=sc(), inputs={"frames": fr}, every=1)
    y1 = snap(L, 11)["player"]["pos"][1]
    y2 = snap(L, 22)["player"]["pos"][1]
    assert y1 > 0.5 and abs(y1 - y2) < 1e-6, (y1, y2)


def test_jump():
    c, L, _ = run(ticks=60, scenario=sc(), inputs={"frames": [{"tick": 0, "jump": True}]}, every=1)
    ys = [l["player"]["pos"][1] for l in L if l["type"] == "snapshot"]
    assert max(ys) > 1.1 and max(ys) < 1.3 and ys[-1] == 0, max(ys)   # đỉnh v²/2g = 1.225


def test_fall_respawn():
    c, L, _ = run(ticks=600, scenario=sc(player={"pos": [39, 0, 0], "carried": 4}),
                  inputs={"frames": [{"tick": 0, "move": [1, 0]}, {"tick": 20, "move": [0, 0]}]}, every=1)
    h = events(L, "player_hit")
    assert h and h[0]["data"] == {"by": "fall", "flames": T["flames"] - 1, "dropped": 0, "lost": 4}, h
    t = h[0]["tick"]
    assert snap(L, t + 60)["player"]["pos"] == [0, 0, 0] and snap(L, t + 60)["player"]["invuln"] > 0


def test_dropped_motes_pickable():
    c, L, _ = run(ticks=200, scenario=sc(player={"carried": 6}, shades=[{"id": "S1", "pos": [0.5, 1, 0]}]), every=1)
    s = snap(L, 1)
    dropped = [m for m in s["motes"] if m["kind"] == "dropped"]
    assert len(dropped) == 3 and all(1.5 - 0.01 <= math.hypot(m["pos"][0], m["pos"][2]) <= 2.5 + 0.01 for m in dropped)
    assert all(abs(m["ttl_s"] - 8.0) < 0.02 for m in dropped)


def test_recoil():
    c, L, _ = run(ticks=30, scenario=sc(shades=[{"id": "S1", "pos": [0.5, 1, 0]}]), every=1)
    assert snap(L, 2)["shades"][0]["state"] == "recoil"


def test_pause():
    fr = [{"tick": 0, "move": [0, 1]}, {"tick": 10, "pause": True}, {"tick": 11, "pause": False},
          {"tick": 40, "pause": True}, {"tick": 41, "pause": False}]
    c, L, _ = run(ticks=60, scenario=sc(), inputs={"frames": fr}, every=10)
    assert [e["name"] for e in L if e["type"] == "event" and e["name"] in ("paused", "resumed")] == ["paused", "resumed"]
    s = snap(L, 30)
    assert s["state"] == "paused" and s["sim_tick"] == 10 and s["time_left_s"] == round(T["night1_duration_s"] - 10 / 60, 3)
    assert snap(L, 60)["sim_tick"] == 30 and end(L)["ticks"] == 60


def test_charm():
    c, L, _ = run(night=2, ticks=40, scenario=sc(player={"pos": [35, 0, 0.5]}),
                  inputs={"frames": [{"tick": 10, "move": [1, 0]}]}, every=10)
    e = events(L, "charm_picked")
    assert e and e[0]["data"] == {"charm_id": "C1", "charm_ticks": 600} and e[0]["tick"] == 1
    s = snap(L, 40)
    assert s["charms"][0]["available"] is False and s["player"]["charm_s"] == round((600 - 39) / 60, 3)
    assert near(s["player"]["pos"], [35 + 7.2 * 30 / 60, 0, 0.5])


def test_charm_dash_no_cd():
    fr = [{"tick": 0, "dash": True}, {"tick": 13, "dash": False}, {"tick": 14, "dash": True}]
    c, L, _ = run(ticks=20, scenario=sc(player={"charm_ticks": 600}), inputs={"frames": fr})
    assert [e["tick"] for e in events(L, "dash")] == [1, 15]


def test_drifter_steal():
    c, L, _ = run(night=2, ticks=60, scenario=sc(player={"carried": 6}, drifters=[{"id": "D1", "pos": [5, 1.5, 0]}]), every=1)
    st = events(L, "drifter_steal")
    assert st and st[0]["data"] == {"drifter_id": "D1", "amount": 3, "carried": 3}, st
    assert snap(L, st[0]["tick"])["drifters"][0]["state"] == "flee" and not events(L, "player_hit")


def test_drifter_idle_when_poor():
    c, L, _ = run(night=2, ticks=60, scenario=sc(player={"carried": 4}, drifters=[{"id": "D1", "pos": [5, 1.5, 0]}]))
    assert not events(L, "drifter_steal") and snap(L, 60)["drifters"][0]["state"] == "idle"


def test_drifter_drop_on_pulse():
    sc2 = sc(player={"carried": 3}, drifters=[{"id": "D1", "pos": [3, 1.5, 0], "state": "flee", "stolen": 3, "state_ticks_left": 200}])
    c, L, _ = run(night=2, ticks=5, scenario=sc2, inputs={"frames": [{"tick": 0, "pulse": True}]}, every=1)
    d = events(L, "drifter_drop")
    assert d and d[0]["data"] == {"drifter_id": "D1", "amount": 3}
    assert len([m for m in snap(L, 1)["motes"] if m["kind"] == "dropped"]) == 3


def test_drifter_spawn():
    c, L, _ = run(night=2, seed=2, ticks=1201, scenario={"random_shades": False})
    assert snap(run(night=2, seed=2, ticks=1210, scenario={"random_shades": False}, every=1210)[1], 1210)["drifters"][0]["id"] == "D1"
    c, L, _ = run(night=1, seed=2, ticks=1210, scenario={"random_shades": False}, every=1210)
    assert snap(L, 1210)["drifters"] == []


def test_pad_night2():
    c, L, _ = run(night=2, ticks=200, scenario=sc(player={"pos": [20, 0, 17.5]}), every=1)
    ys = [l["player"]["pos"][1] for l in L if l["type"] == "snapshot"]
    end_pos = snap(L, 200)["player"]["pos"]
    assert max(ys) > 4.0 and math.hypot(end_pos[0] - 70, end_pos[2]) <= 28 and end_pos[1] == 0, end_pos
    assert not events(L, "player_hit")


def test_bridge_and_gap_night2():
    # trên cầu (z=0) đi được; lệch khỏi cầu (z=5) giữa hai đảo thì rơi
    c, L, _ = run(night=2, ticks=240, scenario=sc(player={"pos": [27, 0, 0]}), inputs={"frames": [{"tick": 0, "move": [1, 0]}]})
    assert not events(L, "player_hit")
    c, L, _ = run(night=2, ticks=240, scenario=sc(player={"pos": [27, 0, 5]}), inputs={"frames": [{"tick": 0, "move": [1, 0]}]})
    assert events(L, "player_hit")[0]["data"]["by"] == "fall"


def test_night3_cliff_and_ramp():
    # vách tầng 1: đi từ r=26 vào tâm theo 90° bị chặn ở y=0
    c, L, _ = run(night=3, ticks=120, scenario=sc(player={"pos": [0, 0, 27]}), inputs={"frames": [{"tick": 0, "move": [0, -1]}]})
    p = snap(L, 120)["player"]["pos"]
    assert p[1] == 0 and p[2] >= 24 - 0.01, p
    # dốc 30°: đi từ r=31 vào trong lên y=3
    a = math.radians(30)
    c, L, _ = run(night=3, ticks=120, scenario=sc(player={"pos": [31 * math.cos(a), 0, 31 * math.sin(a)]}),
                  inputs={"frames": [{"tick": 0, "move": [-math.cos(a), -math.sin(a)]}]})
    p = snap(L, 120)["player"]["pos"]
    assert p[1] == 3 and 12 <= math.hypot(p[0], p[2]) <= 24, p


def test_night3_pad_to_tier2():
    c, L, _ = run(night=3, ticks=120, scenario=sc(player={"pos": [0, 3, 13.5]}), every=1)
    p = snap(L, 120)["player"]["pos"]
    assert p[1] == 6 and math.hypot(p[0], p[2]) <= 8 and not events(L, "player_hit"), p


def test_wind():
    c, L, _ = run(night=3, seed=1, ticks=1810, scenario=sc(wind_enabled=True), every=1810)
    w = snap(L, 1810)["wind"]
    p = snap(L, 1810)["player"]["pos"]
    assert w["active"] and math.hypot(p[0] - 0, p[2] + 28) > 0.3, (w, p)   # 10 tick × 2 m/s = 0.333 m
    c, L, _ = run(night=1, ticks=1810, scenario=sc(), every=1810)
    assert not snap(L, 1810)["wind"]["active"]


def test_safe_push_on_lit():
    c, L, _ = run(ticks=40, scenario=sc(player={"pos": [0, 0, 23], "carried": 10},
                                        shades=[{"id": "S1", "pos": [0, 1, 26]}]),
                  inputs={"frames": [{"tick": 0, "interact": True}]}, every=1)
    assert events(L, "lantern_lit")
    p = snap(L, 31)["shades"][0]["pos"]
    assert math.hypot(p[0], p[2] - 25) >= T["safe_radius"] - 0.01, p


def test_full_night_perf():
    import time
    t = time.time()
    c, L, _ = run(night=3, seed=11, ticks=21600, inputs={"frames": [{"tick": 0, "move": [0.3, 1]}]})
    assert c == 0 and time.time() - t <= 30, time.time() - t


def test_determinism_night3():
    inp = {"frames": [{"tick": 0, "move": [1, 0.2]}, {"tick": 900, "dash": True}, {"tick": 901, "dash": False}]}
    _, _, o1 = run(night=3, seed=5, ticks=4000, inputs=inp, tag="d31")
    _, _, o2 = run(night=3, seed=5, ticks=4000, inputs=inp, tag="d32")
    assert open(o1, "rb").read() == open(o2, "rb").read()


def test_hit_order_by_id():
    # Ticket-02 bước 9: Bóng Mực gây hit xét theo id tăng dần, không theo thứ tự khai báo
    c, L, _ = run(ticks=2, scenario=sc(shades=[{"id": "S2", "pos": [0.5, 1, 0]}, {"id": "S1", "pos": [-0.5, 1, 0]}]), every=1)
    st = {x["id"]: x["state"] for x in snap(L, 1)["shades"]}
    assert st["S1"] == "recoil" and st["S2"] != "recoil", st


def test_scenario_state_default_duration():
    # state khai trong scenario mà thiếu state_ticks_left thì dùng đủ thời lượng của trạng thái đó
    c, L, _ = run(ticks=5, scenario=sc(shades=[{"id": "S1", "pos": [0.5, 1, 0], "state": "stunned"}]), every=1)
    assert not events(L, "player_hit") and snap(L, 5)["shades"][0]["state"] == "stunned"
    sc2 = sc(player={"carried": 3}, drifters=[{"id": "D1", "pos": [3, 1.5, 0], "state": "flee", "stolen": 3}])
    c, L, _ = run(night=2, ticks=8, scenario=sc2, inputs={"frames": [{"tick": 5, "pulse": True}]})
    assert events(L, "drifter_drop"), L[-3:]


def test_invuln_bool():
    c, L, _ = run(ticks=3, scenario=sc(player={"invuln_ticks": 30}), every=1)
    assert snap(L, 1)["player"]["invuln"] is True and snap(L, 0)["player"]["invuln"] is True


def test_ramp_edge_no_gap():
    a = math.radians(30)
    d, perp = (math.cos(a), math.sin(a)), (-math.sin(a), math.cos(a))
    p = [23.98 * d[0] + 1.4 * perp[0], 0, 23.98 * d[1] + 1.4 * perp[1]]
    c, L, _ = run(night=3, ticks=30, scenario=sc(player={"pos": [p[0], 3, p[2]]}))
    assert not events(L, "player_hit"), "rơi ở khe mép dốc"


# ---------- Phase 3 / Contract v1.2 ("Đèn cạn dầu") ----------
def _lit(fuel=None, **kw):
    d = {"id": "L1", "lit": True}
    if fuel is not None:
        d["fuel"] = fuel
    d.update(kw)
    return [d]


def test_fuel_decay_and_snapshot():
    c, L, _ = run(ticks=60, scenario=sc(lanterns=_lit()), every=60)
    l1 = snap(L, 0)["lanterns"][0]
    assert l1["fuel"] == 100 and l1["ever_lit"] is False and l1["relit_count"] == 0
    assert snap(L, 60)["lanterns"][0]["fuel"] == 99.0 and snap(L, 0)["lanterns"][1]["fuel"] == 0
    assert snap(L, 0)["player"]["capacity"] == 10


def test_lantern_out():
    c, L, _ = run(ticks=40, scenario=sc(lanterns=_lit(0.5, deposited=10)), every=1)
    o = events(L, "lantern_out")
    assert o and o[0]["data"] == {"lantern_id": "L1"} and o[0]["tick"] == 30, o
    l1 = snap(L, 30)["lanterns"][0]
    assert (l1["lit"], l1["fuel"], l1["deposited"], l1["ever_lit"]) == (False, 0, 0, True), l1


def test_refuel():
    c, L, _ = run(ticks=3, scenario=sc(player={"pos": [0, 0, 23], "carried": 10}, lanterns=_lit(50)), inputs=_interact())
    r = events(L, "refuel")
    # dầu sau bước 2 của tick 1 = 50 - 1/60 → used = ceil(50.0167/10) = 6
    assert r and r[0]["data"] == {"lantern_id": "L1", "amount": 6, "fuel": 100.0}, r
    assert end(L)["score"] == 6 * T["score"]["per_mote"] and snap(L, 0)["player"]["carried"] == 10


def test_full_lantern_not_selected():
    # L1 đầy dầu ở gần; L2 chưa sáng xa hơn nhưng vẫn trong tầm → chọn L2
    c, L, _ = run(ticks=3, scenario=sc(player={"pos": [0, 0, 23], "carried": 3},
                                       lanterns=[{"id": "L1", "lit": True, "fuel": 100}, {"id": "L2", "pos": [1.5, 0, 22]}]),
                  inputs=_interact())
    assert [e["data"]["lantern_id"] for e in events(L, "deposit")] == ["L2"] and not events(L, "refuel")


def test_relight():
    c, L, _ = run(ticks=3, scenario=sc(player={"pos": [0, 0, 23], "carried": 7},
                                       lanterns=[{"id": "L1", "ever_lit": True}]), inputs=_interact())
    rc = T["relight_cost"]
    assert events(L, "deposit")[0]["data"] == {"lantern_id": "L1", "amount": rc, "deposited": rc}
    assert events(L, "lantern_lit")[0]["data"] == {"lantern_id": "L1", "relight": True}
    assert end(L)["score"] == rc * T["score"]["per_mote"] + T["score"]["per_relight"]
    c, L, _ = run(ticks=3, scenario=sc(player={"pos": [0, 0, 23], "carried": 10}), inputs=_interact(), every=1)
    assert events(L, "lantern_lit")[0]["data"]["relight"] is False and snap(L, 1)["lanterns"][0]["fuel"] == 100.0


def test_capacity_grows():
    c, L, _ = run(ticks=3, scenario=sc(player={"pos": [0, 0, 23], "carried": 10}), inputs=_interact(), every=1)
    assert snap(L, 1)["player"]["capacity"] == 12
    c, L, _ = run(ticks=1, scenario=sc(player={"successful_lights": 9}))
    assert snap(L, 0)["player"]["capacity"] == T["capacity_max"]
    c, L, _ = run(ticks=1, scenario=sc(lanterns=_lit()))
    assert snap(L, 0)["player"]["capacity"] == 10   # đèn đặt sẵn không tính


def test_drain():
    c, L, _ = run(ticks=200, scenario=sc(player={"pos": [0, 0, -30]}, lanterns=_lit(20),
                                         shades=[{"id": "S1", "pos": [0, 1, 21.5]}]), every=1)
    st = [l["shades"][0]["state"] for l in L if l["type"] == "snapshot"]
    assert "drain" in st, st[:10]
    t0 = st.index("drain")
    f = events(L, "fuel_drain")
    assert f and f[0]["data"]["lantern_id"] == "L1" and f[0]["data"]["shade_id"] == "S1", f
    a, b = snap(L, t0 + 1)["lanterns"][0]["fuel"], snap(L, t0 + 61)["lanterns"][0]["fuel"]
    assert abs((a - b) - 6.0) < 0.15, (a, b)   # hao 1 + hút 5 mỗi giây


def test_drain_to_chase_and_pulse_bonus():
    sh = [{"id": "S1", "pos": [0, 1, 20], "state": "drain", "target_lantern_id": "L1"}]
    c, L, _ = run(ticks=3, scenario=sc(player={"pos": [0, 0, 16], "carried": 3}, lanterns=_lit(20), shades=sh),
                  inputs={"frames": [{"tick": 0, "pulse": True}]}, every=1)
    assert events(L, "pulse")[0]["data"] == {"stunned_ids": ["S1"]}
    assert end(L)["score"] == T["score"]["per_stun_drain"]
    c, L, _ = run(ticks=3, scenario=sc(player={"pos": [0, 0, 15]}, lanterns=_lit(20), shades=sh), every=1)
    assert snap(L, 1)["shades"][0]["state"] == "chase"


def test_low_fuel_loses_safe_zone():
    c, L, _ = run(ticks=200, scenario=sc(player={"pos": [0, 0, 25]}, lanterns=_lit(29.9),
                                         shades=[{"id": "S1", "pos": [0, 1, 15]}]))
    assert events(L, "player_hit"), "đèn < 30 dầu phải mất vùng an toàn"
    c, L, _ = run(ticks=200, scenario=sc(player={"pos": [0, 0, 25]}, lanterns=_lit(80),
                                         shades=[{"id": "S1", "pos": [0, 1, 15]}]))
    assert not events(L, "player_hit")


def test_refuel_pushes_shades_out():
    sh = [{"id": "S1", "pos": [0, 1, 21], "state": "drain", "target_lantern_id": "L1"}]
    c, L, _ = run(ticks=40, scenario=sc(player={"pos": [0, 0, 23], "carried": 10}, lanterns=_lit(10), shades=sh),
                  inputs={"frames": [{"tick": 0, "interact": True}]}, every=1)
    assert events(L, "refuel")
    p = snap(L, 31)["shades"][0]["pos"]
    assert math.hypot(p[0], p[2] - 25) >= T["safe_radius"] - 0.01 and not events(L, "player_hit"), p


def test_no_early_win():
    cost = T["lantern_cost"]
    lan = [{"id": f"L{i}", "lit": True} for i in range(1, 5)] + [{"id": "L5", "pos": [0, 0, 5], "deposited": cost - 1}]
    c, L, _ = run(ticks=100, scenario=sc(player={"pos": [0, 0, 3], "carried": 1}, lanterns=lan), inputs=_interact())
    assert events(L, "lantern_lit") and not events(L, "game_over") and end(L)["state"] == "playing"


def test_dawn_survived():
    lan = [{"id": f"L{i}", "lit": True, "fuel": 100} for i in (1, 2, 3)]
    c, L, _ = run(ticks=200, scenario=sc(lanterns=lan, time_left_s=1))
    go = events(L, "game_over")
    assert go and go[0]["data"] == {"result": "won", "reason": "dawn_survived"} and go[0]["tick"] == 60, go
    S = T["score"]
    want = 3 * (S["per_lit_at_dawn"] + 99) + S["per_flame_left"] * T["flames"]
    assert end(L) == {"type": "end", "ticks": 60, "state": "won", "score": want}, end(L)


def test_dawn_lost_below_ratio():
    lan = [{"id": "L1", "lit": True}, {"id": "L2", "lit": True}]
    c, L, _ = run(ticks=200, scenario=sc(lanterns=lan, time_left_s=1))
    assert events(L, "game_over")[0]["data"] == {"result": "lost", "reason": "dawn"} and end(L)["score"] == 0


def test_night_thresholds():
    # Đêm 2 cần 4/6, Đêm 3 cần 5/7
    for night, n_lit, want in [(2, 4, "won"), (2, 3, "lost"), (3, 5, "won"), (3, 4, "lost")]:
        lan = [{"id": f"L{i}", "lit": True} for i in range(1, n_lit + 1)]
        c, L, _ = run(night=night, ticks=100, scenario=sc(lanterns=lan, time_left_s=1), tag=f"th{night}{n_lit}")
        assert end(L)["state"] == want, (night, n_lit, end(L))


def test_drain_event_fuel_matches_snapshot():
    # nhiều bóng cùng hút: fuel trong fuel_drain là dầu cuối tick, khớp snapshot
    sh = [{"id": "S1", "pos": [0, 1, 24], "state": "drain", "target_lantern_id": "L1"},
          {"id": "S2", "pos": [0.5, 1, 24], "state": "drain", "target_lantern_id": "L1"}]
    c, L, _ = run(ticks=60, scenario=sc(player={"pos": [0, 0, -30]}, lanterns=_lit(25), shades=sh), every=60)
    f = events(L, "fuel_drain")
    assert len(f) == 2 and all(e["tick"] == 60 and e["data"]["fuel"] == snap(L, 60)["lanterns"][0]["fuel"] for e in f), f


def test_target_cleared_outside_drain():
    sh = [{"id": "S1", "pos": [0, 1, 24], "state": "drain", "target_lantern_id": "L1"}]
    c, L, _ = run(ticks=2, scenario=sc(player={"pos": [0, 0, 20]}, lanterns=_lit(20), shades=sh), every=1)
    s1 = snap(L, 1)["shades"][0]
    assert s1["state"] == "chase" and s1["target_lantern_id"] is None, s1


# ---------- Phase 4 (thiết kế riêng, vẫn trong luật) ----------
def test_mote_spawn_farthest_free_point():
    # Ticket-02 chỉ nói "một điểm trống": ta chọn điểm trống xa Mây nhất (bằng nhau lấy chỉ số nhỏ)
    c, L, _ = run(ticks=241, scenario={"random_shades": False, "random_drifters": False, "motes": [],
                                       "player": {"pos": [33, 0, 0]}}, every=241)
    m = [x for x in snap(L, 241)["motes"] if x["kind"] == "random"]
    assert len(m) == 1 and near(m[0]["pos"], [-33, 0, 0]), m


def test_initial_motes_far_from_start():
    c, L, _ = run(ticks=1)
    ps = [m["pos"] for m in snap(L, 0)["motes"]]
    far = [p for p in ps if abs(math.hypot(p[0], p[2]) - 33) < 0.01]
    assert len(ps) == 20 and len(far) == 16, ps


def test_wander_personalities_speed_capped():
    # 4 tính cách lang thang khác nhau, không con nào vượt shade_speed
    sh = [{"id": f"S{i}", "pos": [p[0], 1, p[1]]} for i, p in enumerate([(-30, 0), (30, 0), (0, -30), (0, 30)], 1)]
    c, L, _ = run(ticks=300, scenario=sc(player={"pos": [0, 0, 0]}, shades=sh), every=1)
    snaps = [l for l in L if l["type"] == "snapshot"]
    vmax = T["shade_speed"] / 60 + 1e-3
    for a, b in zip(snaps, snaps[1:]):
        for sa, sb in zip(a["shades"], b["shades"]):
            if sb["state"] == "wander":
                assert math.hypot(sb["pos"][0] - sa["pos"][0], sb["pos"][2] - sa["pos"][2]) <= vmax, (sa, sb)
    ends = [x["pos"] for x in snaps[-1]["shades"]]
    assert len({(round(p[0]), round(p[2])) for p in ends}) == 4, ends


# ---------- Phase 4 / Contract v1.3 ----------
def test_soak():
    out = os.path.join(TMP, "soak.json")
    p = subprocess.run([GODOT, "--headless", "--path", ROOT, "--", "--headless-run", "--soak", "--seed", "7",
                        "--nights", "3", "--out", out], capture_output=True, text=True, timeout=300)
    assert p.returncode == 0, p.stderr[-300:]
    d = json.load(open(out, encoding="utf-8"))
    assert d["nights"] == 3 and d["crashes"] == 0 and len(d["results"]) == 3, d
    assert all(r in ("won", "lost") for r in d["results"]) and d["duration_s"] > 0, d
    assert d["mem_start_mb"] > 0 and d["mem_end_mb"] <= 1.2 * d["mem_start_mb"], d


def test_soak_deterministic_results():
    outs = []
    for i in range(2):
        out = os.path.join(TMP, f"soak{i}.json")
        subprocess.run([GODOT, "--headless", "--path", ROOT, "--", "--headless-run", "--soak", "--seed", "3",
                        "--nights", "2", "--out", out], capture_output=True, text=True, timeout=300)
        outs.append(json.load(open(out, encoding="utf-8"))["results"])
    assert outs[0] == outs[1], outs


def _lb(env, *args):
    return subprocess.run([GODOT, "--headless", "--path", ROOT, "--"] + list(args), capture_output=True,
                          text=True, timeout=60, env=env)


def test_leaderboard_order_top10_export():
    env = dict(os.environ, DDL_LB_PATH=os.path.join(TMP, "lb.json"))
    for i, sc_ in enumerate([300, 500, 500, 100, 700, 200, 650, 50, 400, 450, 600, 10]):
        assert _lb(env, "--lb-add", f"P{i:02d}", str(sc_), str(i % 4), str(i)).returncode == 0
    out = os.path.join(TMP, "lb_out.json")
    assert _lb(env, "--export-leaderboard", out).returncode == 0
    e = json.load(open(out, encoding="utf-8"))["entries"]
    assert len(e) == 10, len(e)
    assert [x["score"] for x in e] == sorted([x["score"] for x in e], reverse=True)
    assert [x["name"] for x in e if x["score"] == 500] == ["P01", "P02"]   # bằng điểm: ai đạt trước đứng trên
    assert all(set(x) == {"name", "score", "nights_won", "achieved_at", "seed"} for x in e)
    assert all(re.match(r"^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d[+-]\d\d:\d\d$", x["achieved_at"]) for x in e), e[0]


def test_leaderboard_name_rules():
    env = dict(os.environ, DDL_LB_PATH=os.path.join(TMP, "lb2.json"))
    for bad in ["ab", "abcdefghijklm", "a b c", "bad-name!"]:
        assert _lb(env, "--lb-add", bad, "1", "0", "1").returncode == 2, bad
    for good in ["abc", "Mây_01", "Nguyễn_Văn"]:
        assert _lb(env, "--lb-add", good, "1", "0", "1").returncode == 0, good


if __name__ == "__main__":
    names = sys.argv[1:] or [n for n in list(globals()) if n.startswith("test_")]
    bad = 0
    for n in names:
        try:
            globals()[n]()
            print("PASS", n)
        except Exception as e:
            bad += 1
            print("FAIL", n, "-", type(e).__name__, e)
    print(f"{len(names) - bad}/{len(names)} passed")
    sys.exit(1 if bad else 0)
