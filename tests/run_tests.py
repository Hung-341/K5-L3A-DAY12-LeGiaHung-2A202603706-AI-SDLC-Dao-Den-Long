"""Scenario tests chạy headless theo Test Contract v1.0. Chạy: python tests/run_tests.py [tên_test ...]"""
import json, math, os, shutil, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.environ.get("GODOT") or shutil.which("godot") or r"D:\VinAI\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
TMP = tempfile.mkdtemp(prefix="ddl_")
CONTRACT = json.load(open(os.path.join(ROOT, "game.contract.json"), encoding="utf-8"))
T = CONTRACT["tuning"]
EMPTY = {"random_motes": False, "random_shades": False, "motes": [], "shades": []}


def _write(name, obj):
    p = os.path.join(TMP, name)
    with open(p, "w", encoding="utf-8") as f:
        f.write(obj if isinstance(obj, str) else json.dumps(obj))
    return p


def run(seed=1, ticks=60, scenario=None, inputs=None, every=10, tag="r"):
    out = os.path.join(TMP, tag + ".jsonl")
    args = [GODOT, "--headless", "--path", ROOT, "--", "--headless-run", "--seed", str(seed), "--night", "1",
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
