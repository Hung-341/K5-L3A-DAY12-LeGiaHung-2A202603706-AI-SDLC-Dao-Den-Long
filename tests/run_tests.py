"""Scenario tests chạy headless theo Test Contract v1.0. Chạy: python tests/run_tests.py [tên_test ...]"""
import json, math, os, shutil, subprocess, sys, tempfile

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
    assert set(T["score"]) == {"per_mote", "per_lantern", "per_stun", "per_second_left", "per_flame_left"}


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
    assert events(L, "lantern_lit")[0]["data"] == {"lantern_id": "L1"}
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


def test_win():
    cost = T["lantern_cost"]
    lan = [{"id": f"L{i}", "lit": True} for i in range(1, 5)] + [{"id": "L5", "pos": [0, 0, 5], "deposited": cost - 1}]
    c, L, _ = run(ticks=100, scenario=sc(player={"pos": [0, 0, 3], "carried": 1}, lanterns=lan, time_left_s=100),
                  inputs=_interact())
    go = events(L, "game_over")
    assert go and go[0]["data"] == {"result": "won", "reason": "all_lit"} and go[0]["tick"] == 1
    S = T["score"]
    tl = 100 - 1 / 60
    want = S["per_mote"] + S["per_lantern"] + S["per_second_left"] * math.floor(tl) + S["per_flame_left"] * T["flames"]
    assert end(L) == {"type": "end", "ticks": 1, "state": "won", "score": want}, end(L)


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
    assert s["state"] == "paused" and s["sim_tick"] == 10 and s["time_left_s"] == round(300 - 10 / 60, 3)
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
