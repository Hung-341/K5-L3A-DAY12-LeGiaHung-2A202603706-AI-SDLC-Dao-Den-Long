extends Node3D
## Bản có giao diện: chuỗi 3 Đêm, tạm dừng, cài đặt, âm thanh, HUD. Chỉ đọc trạng thái Sim để vẽ.
## Điều khiển: WASD đi, chuột xoay camera, Space nhảy, Shift lướt, E nạp đèn, F/chuột trái tỏa sáng, Esc/P tạm dừng.

const Sim = preload("res://scripts/sim.gd")
const Sfx = preload("res://scripts/sfx.gd")
const Creative = preload("res://scripts/creative.gd")
const Leaderboard = preload("res://scripts/leaderboard.gd")
const C := {
	"sky": Color("#0E1430"), "fog": Color("#1B2350"), "grass": Color("#2F5D50"), "sand": Color("#C9B48A"),
	"wood": Color("#6B4A2F"), "sea": Color("#12384A"), "lamp_on": Color("#FFB347"), "lamp_core": Color("#FFE9B0"),
	"lamp_off": Color("#5B5F6E"), "mote": Color("#FFF6C2"), "mote_halo": Color("#FFE58A"), "shade": Color("#120A1A"),
	"shade_rim": Color("#7A3CFF"), "shade_stun": Color("#3A3450"), "coat": Color("#E8E2D0"), "scarf": Color("#C8102E"),
	"gold": Color("#F2C14E"), "drifter": Color("#8FA3B8"), "danger": Color("#FF5A5F"), "ui": Color("#F5F1E6"),
	"pink": Color("#F4A6D7"), "lilac": Color("#B48CFF"), "skin": Color("#F6D7B8"),  # điểm nhấn "giấc mơ", ngoài bảng bắt buộc
}
const INTRO := {
	1: "Ông Đăng: \"Đêm đầu tiên, sương đen mới phủ Đảo Bến. Gom đom đóm, thắp lại năm ngọn đèn nhé, Mây.\"",
	2: "Ông Đăng: \"Đảo Cau có hai nửa, nối bằng cây cầu tre. Bục nhảy sẽ đưa con qua biển mây. Cẩn thận Gió Lạc!\"",
	3: "Ông Đăng: \"Đảo Chuông cao ba tầng, gió thổi mạnh. Ngọn đèn cuối nằm cạnh tháp chuông. Trời sắp sáng rồi.\"",
}

var sim
var mode := "menu"   # menu | intro | play | result | dawn
var night := 1
var total := 0
var yaw := 0.0
var sens := 0.25
var volume := 0.8
var colorblind := false  # "Bảng màu dễ phân biệt" (Ticket-03 mục 6)
var big_text := false   # Ticket-04: chữ lớn ×1.25
var skin := 0  # phụ kiện; áo #E8E2D0, khăn #C8102E, nón lá + đèn lồng giữ nguyên theo PRD/bảng màu
const SKINS := ["Cổ điển", "Hoa cài nón", "Đèn cá chép", "Ba lô lá"]
var orbit: Array = []   # đom đóm bay quanh Mây = số đang mang (bổ sung cho thanh HUD bắt buộc)
var paused := false
var world: Node3D
var cam: Camera3D
var env: Environment
var player: Node3D
var mote_nodes := {}
var shade_nodes := {}
var drifter_nodes := {}
var charm_nodes := {}
var lantern_nodes := {}
var ui: CanvasLayer
var hud: Control
var lbl := {}
var cells := []
var arrow: Polygon2D
var panel: VBoxContainer
var sfx: Sfx
var last_sec := -1
var mats := {}
var nights_won := 0
var run_seed := 0
var saved_run := false
# ---- benchmark (Ticket-04 mục 1) ----
const SysInfo = preload("res://scripts/sysinfo.gd")
var bench := {}          # rỗng = chơi bình thường
var bench_t0 := 0        # usec lúc khung hình đầu của cảnh bench
var bench_last := 0
var bench_dts: Array = []
var bench_load_ms := 0
var bench_peak_mb := -1.0
var bench_next_mem := 0.0
var creative
var pitch := 40.0       # camera góc nhìn thứ ba: xoay dọc (chuột), zoom (cuộn chuột)
var cam_dist := 17.0
var trails: Array = []  # vệt mực sau Bóng Mực đang đuổi
var trail_t := 0.0
var hud_panels := []
var cell_styles := []
var menu_bg: ColorRect
const BUFFER_TICKS := 6
var buffer := {"jump": 0, "dash": 0, "pulse": 0}
var held := {"jump": false, "dash": false, "pulse": false}
var prev_pos := {}
var cam_focus := Vector3.ZERO
var body_yaw := 0.0
var walk_t := 0.0


func _ready() -> void:
	_load_settings()
	sfx = Sfx.new()
	add_child(sfx)
	sfx.set_volume(volume)
	sfx.music()
	ui = CanvasLayer.new()
	add_child(ui)
	_build_hud()
	menu_bg = ColorRect.new()
	menu_bg.color = Color(C.sky, 0.72)
	menu_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(menu_bg)
	creative = Creative.new()
	add_child(creative)
	creative.setup(self, ui)
	panel = VBoxContainer.new()
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(panel)
	var args := OS.get_cmdline_user_args()
	if "--bench" in args:
		_start_bench(args)
		return
	_load_night(int(OS.get_environment("DDL_NIGHT")) if OS.get_environment("DDL_NIGHT") != "" else 1)
	_show_menu()


func _arg(args: PackedStringArray, key: String, def: String) -> String:
	var i := args.find(key)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else def


func _start_bench(args: PackedStringArray) -> void:
	bench = {"seed": int(_arg(args, "--seed", "42")), "duration": float(_arg(args, "--duration", "30")),
		"out": _arg(args, "--out", "bench.json")}
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_load_night(1)
	sim = Sim.new(int(bench.seed), Sim.load_tuning(), 1)
	sim.setup_bench(int(bench.seed))
	creative.reset(sim)  # Sương Gai không sinh trong bench (không gọi creative.tick)
	for d in [mote_nodes, shade_nodes]:
		for n in d.values():
			n.queue_free()
		d.clear()
	mode = "bench"
	panel.visible = false
	menu_bg.visible = false


## Gọi mỗi khung hình trong cảnh bench: camera bay vòng, đo dt, ghi bench.json khi đủ thời gian.
func _bench_frame() -> void:
	var now := Time.get_ticks_usec()
	if bench_t0 == 0:
		bench_t0 = now
		bench_last = now
		bench_load_ms = Time.get_ticks_msec()  # từ lúc tiến trình khởi động tới khung hình đầu của cảnh bench
	var el := (now - bench_t0) / 1e6
	var a := TAU * el / 15.0  # ngược chiều kim đồng hồ nhìn từ trên (cùng quy ước góc của bản đồ chuẩn)
	cam.position = Vector3(30.0 * cos(a), 15.0, 30.0 * sin(a))
	cam.look_at(Vector3.ZERO)
	(cam.attributes as CameraAttributesPractical).dof_blur_far_distance = 40.0
	var dt_ms := (now - bench_last) / 1000.0
	bench_last = now
	if el >= 3.0:
		bench_dts.append(dt_ms)
		if OS.get_name() == "Linux" and el >= bench_next_mem:  # /proc rẻ: lấy mẫu mỗi giây
			bench_peak_mb = maxf(bench_peak_mb, SysInfo.rss_mb())
			bench_next_mem = el + 1.0
	elif el >= 2.5 and bench_peak_mb < 0.0:  # macOS/Windows: gọi tiến trình ngoài tốn ~100 ms, chỉ đo ngoài khoảng đo
		bench_peak_mb = SysInfo.rss_mb()
	if el >= 3.0 + bench.duration:
		bench_peak_mb = maxf(bench_peak_mb, SysInfo.rss_mb())
		_write_bench()
		get_tree().quit(0)


func _write_bench() -> void:
	var n := bench_dts.size()
	var total := 0.0
	for d in bench_dts:
		total += d
	var sorted := bench_dts.duplicate()
	sorted.sort()
	var k := maxi(1, ceili(0.01 * n))
	var worst := 0.0
	for i in k:
		worst += sorted[n - 1 - i]
	var p95: float = sorted[clampi(ceili(0.95 * n) - 1, 0, n - 1)]
	var info := Engine.get_version_info()
	var data := {"contract_version": "1.3",
		"avg_fps": snappedf(1000.0 * n / total, 0.1),
		"p1_low_fps": snappedf(1000.0 / (worst / k), 0.1),
		"frame_ms_p95": snappedf(p95, 0.01),
		"frames": n,
		"load_ms": bench_load_ms,
		"peak_mem_mb": snappedf(bench_peak_mb, 0.1),
		"vsync_off": DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED,
		"renderer": "Godot %s, %s, %s" % [info.string, ProjectSettings.get_setting("rendering/renderer/rendering_method"), RenderingServer.get_video_adapter_name()],
		"os": "%s %s" % [OS.get_name(), OS.get_version()]}
	var f := FileAccess.open(bench.out, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  ", false) + "\n")
	f.close()
	print(JSON.stringify(data))


# ---------------- cài đặt ----------------
func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://settings.cfg") == OK:
		volume = cf.get_value("audio", "volume", volume)
		sens = cf.get_value("input", "mouse_sensitivity", sens)
		colorblind = cf.get_value("display", "colorblind", colorblind)
		skin = cf.get_value("player", "skin", skin)


func _save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("audio", "volume", volume)
	cf.set_value("input", "mouse_sensitivity", sens)
	cf.set_value("display", "colorblind", colorblind)
	cf.set_value("player", "skin", skin)
	cf.save("user://settings.cfg")


# ---------------- màn hình menu ----------------
func _clear_panel() -> void:
	for c in panel.get_children():
		c.queue_free()
	panel.visible = true
	menu_bg.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _title(t: String, size := 34) -> void:
	var l := _label(panel, t, size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(760, 0)
	l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _button(t: String, f: Callable) -> void:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(320, 48)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(f)
	panel.add_child(b)


func _show_menu() -> void:
	mode = "menu"
	paused = false
	total = 0
	nights_won = 0
	saved_run = false
	_clear_panel()
	_title("Đảo Đèn Lồng", 52)
	_title("Giữ ba hòn đảo sáng tới bình minh", 22)
	_button("Bắt đầu", func(): _start_night(1))
	_button("Chọn Đêm", _show_select)
	_button("Bảng xếp hạng", _show_leaderboard)
	_button("Trang phục: " + SKINS[skin], func():
		skin = (skin + 1) % SKINS.size()
		_save_settings()
		_show_menu())
	_button("Cài đặt", _show_settings)
	_button("Thoát", func(): get_tree().quit())


## Nhập tên lưu điểm (sau Bình Minh hoặc khi thua). Mỗi lượt chơi lưu một lần.
func _name_entry() -> void:
	if saved_run:
		return
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var le := LineEdit.new()
	le.placeholder_text = "Tên (3–12 ký tự)"
	le.max_length = 12
	le.custom_minimum_size = Vector2(240, 44)
	le.add_theme_font_size_override("font_size", fs(22))
	var msg := _label(panel, "Tổng điểm %d · %d Đêm thắng" % [total, nights_won], fs(20))
	msg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var b := Button.new()
	b.text = "Lưu điểm"
	b.add_theme_font_size_override("font_size", fs(22))
	b.pressed.connect(func():
		if not Leaderboard.valid_name(le.text):
			msg.text = "⚠ Tên 3–12 ký tự: chữ, số hoặc _"
			return
		Leaderboard.save_entries(Leaderboard.add(Leaderboard.load_entries(), le.text, total, nights_won, run_seed))
		saved_run = true
		row.queue_free()
		msg.text = "Đã lưu vào Bảng xếp hạng ✓")
	row.add_child(le)
	row.add_child(b)
	panel.add_child(row)


func _show_leaderboard() -> void:
	_clear_panel()
	_title("Bảng xếp hạng", 40)
	var e := Leaderboard.load_entries()
	if e.is_empty():
		_title("Chưa có điểm nào. Hãy giữ đảo sáng tới bình minh!", 22)
	for i in e.size():
		_title("%2d.  %-12s  %6d điểm  ·  %d Đêm  ·  %s" % [i + 1, e[i].name, e[i].score, e[i].nights_won, str(e[i].achieved_at).substr(0, 10)], 20)
	_button("Quay lại", _show_menu)


## Chọn Đêm: thêm vào menu, không đổi chuỗi bắt buộc (vẫn giới thiệu → chơi → kết quả → Đêm kế).
func _show_select() -> void:
	_clear_panel()
	_title("Chọn Đêm", 40)
	for n in [1, 2, 3]:
		_button("Đêm %d · %s" % [n, Sim.level(n).name], func():
			total = 0
			nights_won = 0
			saved_run = false
			_start_night(n))
	_button("Quay lại", _show_menu)


func _show_settings() -> void:
	_clear_panel()
	_title("Cài đặt", 40)
	for item in [["Âm lượng", "volume", 0.0, 1.0], ["Độ nhạy chuột", "sens", 0.05, 1.0]]:
		var l := _label(panel, item[0], 22)
		l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var s := HSlider.new()
		s.min_value = item[2]
		s.max_value = item[3]
		s.step = 0.01
		s.value = get(item[1])
		s.custom_minimum_size = Vector2(320, 32)
		s.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		s.value_changed.connect(func(v):
			set(item[1], v)
			sfx.set_volume(volume)
			_save_settings())
		panel.add_child(s)
	var cb := CheckButton.new()
	cb.text = "Bảng màu dễ phân biệt"
	cb.button_pressed = colorblind
	cb.add_theme_font_size_override("font_size", 22)
	cb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cb.toggled.connect(func(on):
		colorblind = on
		_save_settings())
	panel.add_child(cb)
	_button("Quay lại", func(): _show_pause() if paused else _show_menu())


func _start_night(n: int) -> void:
	_load_night(n)
	mode = "intro"
	paused = false
	_clear_panel()
	_title("Đêm %d · %s" % [n, Sim.level(n).name], 44)
	_title(INTRO[n], 22)
	_button("Vào đêm", _play)


func _play() -> void:
	mode = "play"
	paused = false
	panel.visible = false
	menu_bg.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _show_pause() -> void:
	paused = true
	_clear_panel()
	_title("Tạm dừng", 40)
	_button("Tiếp tục", _play)
	_button("Chơi lại Đêm", func(): _start_night(night))
	_button("Cài đặt", _show_settings)
	_button("Về menu", _show_menu)


func _show_result() -> void:
	mode = "result"
	_clear_panel()
	if sim.state == "won":
		total += sim.score
		nights_won += 1
		sfx.play("win")
		if night == 3:
			mode = "dawn"
			env.background_color = Color("#F4B9A8")
			env.ambient_light_energy = 1.2
			_title("Bình Minh", 56)
			_title("Ba hòn đảo đã sáng trở lại. Tổng điểm: %d" % total, 26)
			_name_entry()
			_button("Về menu", _show_menu)
		else:
			_title("Đêm %d hoàn thành!" % night, 42)
			_title("Điểm đêm này: %d · Tổng: %d" % [sim.score, total], 24)
			_button("Đêm kế tiếp", func(): _start_night(night + 1))
	else:
		sfx.play("lose")
		_title("Mây đã thua Đêm %d" % night, 42)
		_title("Hết Ngọn Lửa." if sim.flames <= 0 else "Bình minh lên nhưng đảo chưa đủ sáng (cần %d đèn)." % ceili(float(sim.T["win_ratio"]) * sim.lanterns.size() - 1e-9), 24)
		_name_entry()
		_button("Chơi lại Đêm", func(): _start_night(night))
		_button("Về menu", _show_menu)


# ---------------- thế giới ----------------
func rim() -> Color:
	return Color("#00B3FF") if colorblind else C.shade_rim


func danger() -> Color:
	return Color("#FFFFFF") if colorblind else C.danger


## Viền Bóng Mực: chỉ vẽ mặt sau của quả cầu lớn hơn = đường viền, thân đen vẫn lộ ra (#120A1A / #7A3CFF).
func _rim_mat() -> StandardMaterial3D:
	var key := "rim|%s" % colorblind
	if not mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = rim()
		m.emission_enabled = true
		m.emission = rim()
		m.emission_energy_multiplier = 1.5
		m.cull_mode = BaseMaterial3D.CULL_FRONT
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mats[key] = m
	return mats[key]


func _mat(c: Color, emit := 0.0, alpha := 1.0) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [c.to_html(), emit, alpha]
	if mats.has(key):
		return mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c, alpha)
	m.roughness = 0.9
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	mats[key] = m
	return m


func _mesh(mesh: Mesh, mat: Material, pos := Vector3.ZERO, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	if mesh.get_aabb().size.length() < 1.0:  # vật nhỏ (mắt, nanh, đom đóm, hoa) không đổ bóng
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else world).add_child(mi)
	return mi


var _mesh_cache := {}


func _sphere(r: float) -> SphereMesh:
	var key := "s%s" % r
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2
	s.radial_segments = 12 if r < 0.3 else (20 if r < 2.0 else 48)
	s.rings = 6 if r < 0.3 else (10 if r < 2.0 else 24)
	_mesh_cache[key] = s
	return s


func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var key := "c%s|%s|%s" % [top, bottom, h]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 64 if maxf(top, bottom) > 5.0 else 12
	c.rings = 1
	_mesh_cache[key] = c
	return c


func _disc(center: Vector3, r: float, top: float, depth := 8.0) -> void:
	_mesh(_cyl(r, r, 0.6), _mat(C.grass), center + Vector3(0, top - 0.3, 0))
	_mesh(_cyl(r, r * 0.7, depth), _mat(C.sand), center + Vector3(0, top - 0.6 - depth / 2, 0))


func _load_night(n: int) -> void:
	night = n
	if world:
		world.queue_free()
	for d in [mote_nodes, shade_nodes, drifter_nodes, charm_nodes, lantern_nodes]:
		d.clear()
	world = Node3D.new()
	add_child(world)
	var seed := randi()
	if total == 0 and nights_won == 0:
		run_seed = seed
	sim = Sim.new(seed, Sim.load_tuning(), n)
	if OS.get_environment("DDL_DEMO") != "":  # chỉ để chụp bằng chứng: đèn đầy / sắp cạn / đã tắt
		sim.apply_scenario({"player": {"pos": [6, 0, 14]}, "lanterns": [{"id": "L1", "lit": true, "fuel": 80},
			{"id": "L2", "lit": true, "fuel": 20}, {"id": "L5", "ever_lit": true}]})
		colorblind = OS.get_environment("DDL_DEMO") == "cb"
	yaw = 0.0
	last_sec = -1
	trails.clear()
	orbit.clear()
	if creative:
		creative.reset(sim)
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = C.sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.75, 1.0)
	env.ambient_light_energy = 0.15
	env.fog_enabled = true
	env.fog_light_color = C.fog
	env.fog_density = 0.006
	env.glow_enabled = true
	env.glow_bloom = 0.25
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.8, 0.75, 1.0)
	moon.light_energy = 0.45
	moon.shadow_enabled = true
	moon.rotation_degrees = Vector3(-55, 30, 0)
	world.add_child(moon)
	var sea := PlaneMesh.new()
	sea.size = Vector2(700, 700)
	_mesh(sea, _mat(C.sea, 0.15), Vector3(35, -14, 0))
	_mesh(_sphere(9.0), _mat(C.pink, 1.6), Vector3(-60, 55, 120))
	_mesh(_sphere(8.6), _mat(C.sky), Vector3(-56, 57, 118))
	_build_terrain(n)
	for L in sim.lanterns:
		_make_lantern(L)
	player = _make_player()
	cam = Camera3D.new()
	cam.fov = 45
	var ca := CameraAttributesPractical.new()
	ca.dof_blur_far_enabled = true
	ca.dof_blur_far_transition = 18.0
	ca.dof_blur_near_enabled = true
	ca.dof_blur_near_distance = 8.0
	ca.dof_blur_near_transition = 4.0
	ca.dof_blur_amount = 0.12
	cam.attributes = ca
	world.add_child(cam)


func _build_terrain(n: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 7 + n
	var deco: Array = []
	match n:
		1:
			_disc(Vector3.ZERO, 40.0, 0.0)
			deco = [Vector3.ZERO, 38.0]
		2:
			_disc(Vector3.ZERO, 28.0, 0.0)
			_disc(Vector3(70, 0, 0), 28.0, 0.0)
			var bridge := _mesh(BoxMesh.new(), _mat(C.wood), Vector3(35, -0.15, 0))
			bridge.scale = Vector3(18, 0.3, 4)
			deco = [Vector3.ZERO, 26.0, Vector3(70, 0, 0), 26.0]
		3:
			_disc(Vector3.ZERO, 45.0, 0.0)
			# tầng 1: vành khăn r12–24, nửa z > 0, cao 3 m
			var t1 := CSGCombiner3D.new()
			world.add_child(t1)
			var outer := CSGCylinder3D.new()
			outer.radius = 24.0
			outer.height = 3.0
			outer.sides = 48
			outer.material = _mat(C.grass)
			t1.add_child(outer)
			var inner := CSGCylinder3D.new()
			inner.radius = 12.0
			inner.height = 3.2
			inner.sides = 32
			inner.operation = CSGShape3D.OPERATION_SUBTRACTION
			t1.add_child(inner)
			var half := CSGBox3D.new()
			half.size = Vector3(60, 3.4, 30)
			half.position = Vector3(0, 0, -15)
			half.operation = CSGShape3D.OPERATION_SUBTRACTION
			t1.add_child(half)
			t1.position = Vector3(0, 1.5, 0)
			_mesh(_cyl(8, 8, 6), _mat(C.sand.darkened(0.1)), Vector3(0, 3, 0))
			_mesh(_cyl(8, 8, 0.2), _mat(C.grass), Vector3(0, 6.0, 0))
			_mesh(_cyl(2, 2, 8), _mat(C.wood), Vector3(0, 10, 0))
			_mesh(_cyl(0.1, 2.6, 2.0), _mat(C.wood.darkened(0.3)), Vector3(0, 15, 0))
			for a in [30.0, 150.0]:
				var ramp := _mesh(BoxMesh.new(), _mat(C.sand), Sim._polar(27.0, a, 1.5))
				ramp.rotation = Vector3(0, -deg_to_rad(a), 0)
				ramp.rotate_object_local(Vector3.FORWARD, -atan2(3.0, 6.0))
				ramp.scale = Vector3(6.7, 0.3, 3.0)
			deco = [Vector3.ZERO, 44.0]
	for pad in sim.LV.pads:
		_mesh(_cyl(1, 1, 0.15), _mat(C.gold, 1.5), pad.pos + Vector3(0, 0.08, 0))
	_decorate(deco, r)


func _make_lantern(L: Dictionary) -> void:
	var n := Node3D.new()
	n.position = L.pos
	world.add_child(n)
	_mesh(_cyl(0.3, 0.4, 3.0), _mat(C.wood), Vector3(0, 1.5, 0), n)
	var lamp := _mesh(BoxMesh.new(), _mat(C.lamp_off), Vector3(0, 3.5, 0), n)
	lamp.scale = Vector3(1.1, 1.3, 1.1)
	_mesh(_cyl(0.0, 1.0, 0.7), _mat(C.wood), Vector3(0, 4.5, 0), n)
	var light := OmniLight3D.new()
	light.light_color = C.lamp_on
	light.omni_range = 9.0
	light.light_energy = 0.0
	light.position = Vector3(0, 3.5, 0)
	n.add_child(light)
	var ring := _mesh(_cyl(6.0, 6.0, 0.05), _mat(C.lamp_on, 0.4, 0.12), Vector3(0, 0.05, 0), n)
	ring.visible = false
	# vết rách trên giấy đèn tắt (phân biệt không cần màu)
	var tear := _mesh(BoxMesh.new(), _mat(Color("#1A1A22")), Vector3(0.2, 3.4, 0.56), n)
	tear.scale = Vector3(0.12, 0.7, 0.02)
	tear.rotation_degrees.z = 25
	# thanh dầu: nền + phần đầy, quay về camera trong _process
	var bar := Node3D.new()
	bar.position = Vector3(0, 5.4, 0)
	n.add_child(bar)
	var bg := _mesh(BoxMesh.new(), _mat(Color("#1B2350"), 0.0, 0.8), Vector3.ZERO, bar)
	bg.scale = Vector3(2.0, 0.22, 0.05)
	var fill := _mesh(BoxMesh.new(), _mat(C.lamp_on, 2.0), Vector3(0, 0, 0.03), bar)
	fill.scale = Vector3(2.0, 0.16, 0.05)
	lantern_nodes[L.id] = {"lamp": lamp, "light": light, "ring": ring, "tear": tear, "bar": bar, "fill": fill}


## Mây: chibi đầu to, áo kem, khăn đỏ, nón lá treo đèn lồng nhỏ.
func _make_player() -> Node3D:
	var p := Node3D.new()
	world.add_child(p)
	_mesh(_cyl(0.32, 0.45, 0.8), _mat(C.coat), Vector3(0, 0.45, 0), p)
	var scarf := TorusMesh.new()
	scarf.inner_radius = 0.22
	scarf.outer_radius = 0.36
	_mesh(scarf, _mat(C.scarf), Vector3(0, 0.88, 0), p)
	_mesh(_sphere(0.48), _mat(C.skin), Vector3(0, 1.32, 0), p)
	for x in [-0.16, 0.16]:
		_mesh(_sphere(0.06), _mat(Color("#2A1E2E")), Vector3(x, 1.36, 0.43), p)
	_mesh(_cyl(0.0, 0.95, 0.45), _mat(C.sand), Vector3(0, 1.85, 0), p)
	_mesh(_cyl(0.005, 0.005, 0.45), _mat(C.wood), Vector3(0.7, 1.45, 0.3), p)
	var lan: MeshInstance3D
	match skin:
		2:  # đèn cá chép: thân dài màu cam, đuôi vàng
			lan = _mesh(_sphere(0.12), _mat(C.lamp_on, 3.0), Vector3(0.7, 1.15, 0.3), p)
			lan.scale = Vector3(0.9, 0.9, 1.8)
			_mesh(_cyl(0.0, 0.1, 0.18), _mat(C.gold, 2.0), Vector3(0.7, 1.15, 0.08), p).rotation_degrees.x = -90
		_:
			lan = _mesh(_sphere(0.12), _mat(C.lamp_on, 3.0), Vector3(0.7, 1.15, 0.3), p)
	if skin == 1:  # vòng hoa hồng tím cài vành nón
		for k in 8:
			var a := k * TAU / 8
			_mesh(_sphere(0.08), _mat(C.pink if k % 2 == 0 else C.lilac), Vector3(cos(a) * 0.62, 1.72, sin(a) * 0.62), p)
	if skin == 3:  # ba lô lá
		var bag := _mesh(_sphere(0.28), _mat(C.grass.lightened(0.25)), Vector3(0, 0.6, -0.38), p)
		bag.scale = Vector3(1.0, 1.2, 0.6)
	var l := OmniLight3D.new()
	l.light_color = C.lamp_on
	l.omni_range = 4.5
	l.light_energy = 1.2
	lan.add_child(l)
	return p


func _make_shade() -> Node3D:
	var s := Node3D.new()
	world.add_child(s)
	var r := _mesh(_sphere(0.78), _rim_mat(), Vector3.ZERO, s)
	r.name = "rim"
	var body := _mesh(_sphere(0.7), _mat(C.shade), Vector3.ZERO, s)
	body.name = "body"
	for x in [-0.22, 0.22]:
		_mesh(_sphere(0.09), _mat(rim(), 3.0), Vector3(x, 0.18, 0.6), s).name = "eye%d" % int(x > 0)
	for x in [-0.15, 0.0, 0.15]:
		var f := _mesh(_cyl(0.0, 0.06, 0.18), _mat(Color.WHITE), Vector3(x, -0.12, 0.64), s)
		f.rotation_degrees.x = 180
	return s


func _make_drifter() -> Node3D:
	var d := Node3D.new()
	world.add_child(d)
	for i in 4:
		var seg := _mesh(BoxMesh.new(), _mat(C.drifter, 0.6, 0.8), Vector3(0, 0, -i * 0.45), d)
		seg.scale = Vector3(0.7 - i * 0.12, 0.06, 0.45)
		seg.name = "s%d" % i
	return d


func _make_charm() -> Node3D:
	var c := Node3D.new()
	world.add_child(c)
	var b := _mesh(BoxMesh.new(), _mat(C.gold, 1.0), Vector3(0, 1.0, 0), c)
	b.scale = Vector3(0.62, 0.86, 0.06)
	var f := _mesh(BoxMesh.new(), _mat(C.scarf, 0.8), Vector3(0, 1.0, 0.01), c)
	f.scale = Vector3(0.5, 0.74, 0.08)
	return c


# ---------------- HUD ----------------
func fs(n: int) -> int:
	return int(round(maxi(n, 18) * (1.25 if big_text else 1.0)))  # tối thiểu 18 px ở 1280×720


func _label(parent: Node, text := "", size := 22) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", C.ui)
	l.add_theme_color_override("font_outline_color", C.sky)
	l.add_theme_constant_override("outline_size", 6)
	parent.add_child(l)
	return l


func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)
	for i in 5:
		var pn := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(C.sky, 0.6)
		sb.border_color = Color(C.gold, 0.8)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(12)
		pn.add_theme_stylebox_override("panel", sb)
		pn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.add_child(pn)
		hud_panels.append(pn)
	for k in ["flames", "clock", "right", "prompt", "dash", "pulse", "warn", "cap", "windq"]:
		lbl[k] = _label(hud)
	lbl.clock.add_theme_font_size_override("font_size", 30)
	lbl.right.add_theme_color_override("font_color", C.gold)
	lbl.flames.add_theme_color_override("font_color", C.lamp_on)
	lbl.warn.add_theme_color_override("font_color", C.drifter)
	for i in 20:
		var c := Panel.new()
		var cs := StyleBoxFlat.new()
		cs.set_corner_radius_all(9)
		c.add_theme_stylebox_override("panel", cs)
		cell_styles.append(cs)
		c.size = Vector2(18, 26)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.add_child(c)
		cells.append(c)
	arrow = Polygon2D.new()
	arrow.polygon = PackedVector2Array([Vector2(18, 0), Vector2(-12, -12), Vector2(-6, 0), Vector2(-12, 12)])
	arrow.color = C.lamp_on
	hud.add_child(arrow)


func _update_hud(t: float) -> void:
	var vp := get_viewport().get_visible_rect().size
	hud.visible = mode == "play" and not paused
	var tl: float = max(sim.time_left, 0.0)
	lbl.flames.text = "Ngọn Lửa  " + "♥ ".repeat(sim.flames) + "♡ ".repeat(max(0, 3 - sim.flames))
	lbl.flames.position = Vector2(24, 18)
	lbl.clock.text = ("⚠ " if colorblind and tl <= 30 else "") + "%02d:%02d" % [int(tl) / 60, int(tl) % 60]
	lbl.clock.position = Vector2(vp.x / 2 - 40, 14)
	lbl.clock.add_theme_color_override("font_color", danger() if tl <= 30 else C.ui)
	lbl.clock.visible = tl > 30 or int(t * 4) % 2 == 0
	var lit: int = sim.lanterns.filter(func(L): return L.lit).size()
	var need := ceili(float(sim.T["win_ratio"]) * sim.lanterns.size() - 1e-9)
	lbl.right.text = "Đèn sáng %d/%d (cần %d)   Điểm %d" % [lit, sim.lanterns.size(), need, sim.score]
	lbl.right.add_theme_color_override("font_color", C.gold if lit >= need else danger())
	lbl.right.position = Vector2(vp.x - 400, 18)
	var cap: int = sim.capacity()
	for i in cells.size():
		cells[i].visible = i < cap
		cells[i].size = Vector2(18, 26)
		cells[i].position = Vector2(vp.x / 2 - cap * 11 + i * 22, vp.y - 56)

	lbl.cap.text = "%d/%d" % [sim.carried, cap]
	lbl.cap.position = Vector2(vp.x / 2 + cap * 11 + 8, vp.y - 60)
	lbl.dash.text = "Lướt " + ("✓" if sim.dash_cd == 0 or sim.charm_t > 0 else "%.1fs" % (sim.dash_cd / 60.0))
	lbl.pulse.text = "Tỏa Sáng " + ("✓" if sim.pulse_cd == 0 and sim.carried >= 3 else ("%.1fs" % (sim.pulse_cd / 60.0) if sim.pulse_cd > 0 else "cần 3"))
	lbl.dash.position = Vector2(vp.x - 230, vp.y - 126)
	lbl.pulse.position = Vector2(vp.x - 230, vp.y - 92)
	var wc: int = creative.wind_cost()
	lbl.windq.text = "Q Gió Đèn (%d) " % wc + ("✓" if creative.wind_cd == 0.0 and sim.carried >= wc else ("%.1fs" % creative.wind_cd if creative.wind_cd > 0 else "thiếu"))
	lbl.windq.position = Vector2(vp.x - 230, vp.y - 58)
	# khung bo góc cho các cụm HUD
	var boxes := [Rect2(12, 10, 230, 44), Rect2(vp.x / 2 - 70, 8, 140, 50), Rect2(vp.x - 412, 10, 400, 44),
		Rect2(vp.x - 242, vp.y - 132, 230, 112), Rect2(vp.x / 2 - sim.capacity() * 11 - 12, vp.y - 66, sim.capacity() * 22 + 70, 46)]
	for i in hud_panels.size():
		hud_panels[i].position = boxes[i].position
		hud_panels[i].size = boxes[i].size
	for i in cell_styles.size():
		cell_styles[i].bg_color = C.mote_halo if i < sim.carried else Color(C.ui, 0.15)
	var near := ""
	var best = null
	var bd := INF
	for L in sim.lanterns:
		if L.lit:
			if Sim.xz(sim.p_pos, L.pos) <= 2.0 and L.fuel < sim._fmax():
				near = "E — Châm dầu (%d/100)" % int(L.fuel / float(Sim.FU))
			continue
		var d := Sim.xz(sim.p_pos, L.pos)
		if d <= 2.0:
			near = "E — Nạp ánh sáng (%d/%d)" % [L.deposited, int(sim.T["relight_cost"]) if L.ever_lit else int(sim.T["lantern_cost"])]
		if d < bd:
			bd = d
			best = L
	lbl.prompt.text = near
	lbl.prompt.position = Vector2(vp.x / 2 - 140, vp.y - 110)
	var warn := ""
	if sim.wind_warning():
		warn = "Lá bay… gió sắp nổi!"
	elif sim.wind_on:
		warn = "Gió mạnh!"
	if sim.charm_t > 0:
		warn += "   Bùa Gió %ds" % ceili(sim.charm_t / 60.0)
	lbl.warn.text = warn
	lbl.warn.position = Vector2(vp.x / 2 - 120, 56)
	# mũi tên tới đèn chưa sáng gần nhất khi nó ở ngoài màn hình
	arrow.visible = false
	if best != null:
		var wp: Vector3 = best.pos + Vector3(0, 3.5, 0)
		var behind := cam.is_position_behind(wp)
		var sp := cam.unproject_position(wp)
		if behind or not Rect2(Vector2.ZERO, vp).has_point(sp):
			var c := vp / 2
			var dir := (sp - c) * (-1.0 if behind else 1.0)
			arrow.visible = true
			arrow.rotation = dir.angle()
			arrow.position = c + dir.normalized() * (min(vp.x, vp.y) / 2 - 40)


# ---------------- vòng lặp ----------------
func _unhandled_input(e: InputEvent) -> void:
	if mode != "play":
		return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= e.relative.x * sens
		pitch = clampf(pitch + e.relative.y * sens * 0.6, 12.0, 75.0)
	elif e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		cam_dist = clampf(cam_dist * (0.9 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 7.0, 32.0)
	elif e is InputEventKey and e.pressed and not e.echo and e.keycode in [KEY_ESCAPE, KEY_P]:
		if paused:
			_play()
		else:
			_show_pause()


func _key(k: Key) -> bool:
	return Input.is_physical_key_pressed(k)


func _physics_process(_dt: float) -> void:
	if mode == "bench":
		prev_pos = {"player": sim.p_pos}
		for e in sim.shades:
			prev_pos[e.id] = e.pos
		sim.step({})
		sim.events.clear()
		return
	if mode != "play" or paused:
		return
	var mx := (1.0 if _key(KEY_A) else 0.0) - (1.0 if _key(KEY_D) else 0.0)  # phải màn hình là -x của contract
	var mz := (1.0 if _key(KEY_W) else 0.0) - (1.0 if _key(KEY_S) else 0.0)
	if OS.get_environment("DDL_AUTOPLAY") != "":
		mz = 0.6
		yaw += 0.3
	# lưu vị trí tick trước để _process nội suy (hình mượt dù logic chạy 60 tick/s)
	prev_pos = {"player": sim.p_pos}
	for e in sim.shades + sim.drifters:
		prev_pos[e.id] = e.pos
	# nhớ phím 0.1 s: gửi cạnh false→true vào đúng tick hành động hợp lệ (chỉ ở lớp nhập phím, không đổi luật)
	var want := {"jump": _key(KEY_SPACE), "dash": _key(KEY_SHIFT),
		"pulse": _key(KEY_F) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)}
	var ready := {"jump": sim.grounded, "dash": sim.dash_t == 0 and (sim.dash_cd == 0 or sim.charm_t > 0),
		"pulse": sim.pulse_cd == 0 and sim.carried >= int(sim.T["pulse_cost"])}
	var send := {}
	for k in want:
		if want[k] and not held[k]:
			buffer[k] = BUFFER_TICKS
		held[k] = want[k]
		send[k] = buffer[k] > 0 and ready[k]
		if send[k]:
			buffer[k] = 0
		buffer[k] = max(0, buffer[k] - 1)
	sim.step({"move": [mx, mz], "cam_yaw_deg": yaw, "jump": send.jump, "interact": _key(KEY_E),
		"pulse": send.pulse, "dash": send.dash})
	for ev in sim.events:
		match ev.name:
			"mote_picked", "charm_picked": sfx.play("pick")
			"lantern_lit": sfx.play("lit")
			"refuel": sfx.play("pick")
			"lantern_out": sfx.play("out")
			"pulse": sfx.play("pulse")
			"player_hit": sfx.play("hit")
			"dash": sfx.play("dash")
			"shade_spawned": sfx.play("spawn")
	if sim.grounded == false and sim.p_vel.y > 6.6 and sim.p_vel.y <= 7.0:
		sfx.play("jump")
	if sim.wind_enabled and not sim.wind_on and (Sim.WIND_EVERY - sim.steps % Sim.WIND_EVERY) == Sim.WIND_WARN:
		sfx.play("wind")
	var sec := int(ceil(sim.time_left))
	if sec <= 10 and sec != last_sec and sec > 0:
		sfx.play("tick")
	last_sec = sec
	sim.events.clear()
	creative.tick(_dt, _key(KEY_Q))
	if sim.state != "playing":
		_show_result()


var _frames := 0
var _fps_sum := 0.0
var _fps_n := 0


func _process(_dt: float) -> void:  # _dt dùng cho làm mượt camera/xoay
	_frames += 1
	if OS.get_environment("DDL_AUTOPLAY") != "" and mode == "menu" and _frames == 5:
		_start_night(night)
		_play()
	if mode == "play" and _frames > 60:
		_fps_sum += Engine.get_frames_per_second()
		_fps_n += 1
	var shot := OS.get_environment("DDL_SHOT")  # bằng chứng: chụp màn hình sau N frame rồi thoát
	var limit := int(OS.get_environment("DDL_SHOT_FRAMES")) if OS.get_environment("DDL_SHOT_FRAMES") != "" else 120
	if shot != "" and _frames == limit:
		get_viewport().get_texture().get_image().save_png(shot)
		print("avg_fps=%.1f samples=%d" % [_fps_sum / max(1, _fps_n), _fps_n])
		get_tree().quit()
	var t := Time.get_ticks_msec() / 1000.0
	var a := Engine.get_physics_interpolation_fraction()
	var ppos := _lerp_pos("player", sim.p_pos, a)
	var moving := Vector2(sim.p_vel.x, sim.p_vel.z).length() > 0.5 and mode == "play" and not paused
	walk_t = walk_t + _dt * 12.0 if moving and sim.grounded else 0.0
	player.position = ppos + Vector3(0, absf(sin(walk_t)) * 0.12, 0)
	body_yaw = lerp_angle(body_yaw, atan2(sim.p_face.x, sim.p_face.z), minf(1.0, _dt * 14.0))
	player.rotation = Vector3(0, body_yaw, sin(walk_t) * 0.06)
	player.visible = sim.fall_wait == 0 and (sim.invuln == 0 or int(t * 12) % 2 == 0)
	var th := deg_to_rad(yaw)
	var fwd := Vector3(sin(th), 0, cos(th))
	var target := ppos + Vector3(0, 1.0, 0)
	cam_focus = target if cam_focus.distance_to(target) > 12.0 else cam_focus.lerp(target, minf(1.0, _dt * 10.0))
	var far := 1.0 + clampf(Vector2(sim.p_vel.x, sim.p_vel.z).length() - 7.0, 0.0, 10.0) * 0.03  # kéo xa khi lướt/bay
	var pr := deg_to_rad(pitch)
	var want_cam := cam_focus - fwd * cos(pr) * cam_dist * far + Vector3(0, sin(pr) * cam_dist * far, 0)
	var g: float = sim.ground(want_cam.x, want_cam.z)
	want_cam.y = maxf(want_cam.y, (g if g > Sim.NO_GROUND else cam_focus.y - 2.0) + 1.0)  # không xuyên đất
	cam.position = want_cam
	cam.look_at(cam_focus)
	var focus := cam_focus
	(cam.attributes as CameraAttributesPractical).dof_blur_far_distance = cam.position.distance_to(focus) + 6.0
	_sync(sim.motes, mote_nodes, func(): return _mesh(_sphere(0.22), _mat(C.mote, 4.0)),
		func(n, m): n.position = m.pos + Vector3(0, 0.7 + 0.15 * sin(t * 3.0 + n.get_instance_id()), 0))
	_sync(sim.shades, shade_nodes, _make_shade, func(n, s):
		n.position = _lerp_pos(s.id, s.pos, a)
		if Sim.xz(s.pos, sim.p_pos) > 0.1:
			n.look_at(Vector3(sim.p_pos.x, s.pos.y, sim.p_pos.z), Vector3.UP, true)
		var look := "%s|%s" % [s.state == "stunned", colorblind]
		if n.get_meta("look", "") != look:
			n.set_meta("look", look)
			n.get_node("body").material_override = _mat(C.shade_stun if s.state == "stunned" else C.shade)
			n.get_node("rim").material_override = _rim_mat()
			for e in ["eye0", "eye1"]:
				n.get_node(e).material_override = _mat(rim(), 3.0)
		n.scale = Vector3.ONE * (0.4 if s.state == "spawning" else 1.0 + 0.06 * sin(t * 5.0)))
	_sync(sim.drifters, drifter_nodes, _make_drifter, func(n, d):
		n.position = _lerp_pos(d.id, d.pos, a)
		n.rotation.y = t * 2.0
		for i in 4:
			n.get_node("s%d" % i).position.y = 0.25 * sin(t * 6.0 - i * 0.9))
	_sync(sim.charms, charm_nodes, _make_charm, func(n, c):
		n.position = c.pos
		n.visible = c.available
		n.rotation.y = t * 1.5)
	var lit := 0
	var blink := int(t * 2.0) % 2 == 0  # 1 Hz: sáng 0.5 s, tối 0.5 s
	for L in sim.lanterns:
		var ln: Dictionary = lantern_nodes[L.id]
		var fuel: float = L.fuel / float(Sim.FU)
		var low: bool = L.lit and fuel < float(sim.T["low_fuel_threshold"])
		var on: bool = L.lit and (not low or blink)
		var cost: int = int(sim.T["relight_cost"]) if L.ever_lit else int(sim.T["lantern_cost"])
		ln.lamp.material_override = _mat(C.lamp_on, 3.0) if on else _mat(C.lamp_off.lerp(C.lamp_on, snappedf(float(L.deposited) / cost * 0.5, 0.05)))
		ln.lamp.scale = Vector3(1.1, 1.3, 1.1) if L.lit else Vector3(1.1 * 0.8, 1.3 * 0.8, 1.1 * 0.8)  # đèn tắt xẹp 20%
		ln.tear.visible = not L.lit
		ln.light.light_energy = (2.5 if not low else 1.4) if on else 0.0
		ln.ring.visible = L.lit and not low
		ln.bar.visible = L.lit and (not low or blink)
		ln.bar.look_at(cam.global_position, Vector3.UP, true)
		var f := clampf(fuel / 100.0, 0.0, 1.0)
		ln.fill.scale.x = 2.0 * max(f, 0.001)
		ln.fill.position.x = -1.0 + f
		ln.fill.material_override = _mat(danger() if low else C.lamp_on, 2.0)
		lit += int(L.lit)
	if mode != "dawn":
		env.ambient_light_energy = 0.15 + 0.55 * lit / sim.lanterns.size()
	creative.render(t)
	_update_orbit(t, ppos)
	if mode == "bench":
		_bench_frame()
	_update_trails(_dt)
	_update_hud(t)


func _update_orbit(t: float, center: Vector3) -> void:
	while orbit.size() < sim.carried:
		orbit.append(_mesh(_sphere(0.09), _mat(C.mote, 4.0)))
	while orbit.size() > sim.carried:
		orbit.pop_back().queue_free()
	for i in orbit.size():
		var a: float = t * 1.6 + i * TAU / maxf(1.0, orbit.size())
		orbit[i].position = center + Vector3(cos(a) * 0.95, 1.1 + 0.35 * sin(t * 2.3 + i), sin(a) * 0.95)


## Vệt mực sau Bóng Mực đang đuổi: chỉ là hình, tốc độ thật vẫn theo luật.
func _update_trails(dt: float) -> void:
	trail_t += dt
	if trail_t >= 0.06 and not paused:
		trail_t = 0.0
		for s in sim.shades:
			if s.state == "chase" and trails.size() < 80:
				var m := _mesh(_sphere(0.35), _mat(rim(), 0.8, 0.35), s.pos - Vector3(0, 0.3, 0))
				trails.append([m, 0.6])
	for tr in trails.duplicate():
		tr[1] -= dt
		tr[0].scale = Vector3.ONE * maxf(tr[1] / 0.6, 0.01)
		if tr[1] <= 0.0:
			tr[0].queue_free()
			trails.erase(tr)


func _multi(mesh: Mesh, mat: Material, xf: Array) -> void:
	if xf.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	world.add_child(mi)


## Điểm trang trí hợp lệ: có đất phẳng, tránh xa đèn / điểm đom đóm / bục nhảy / bùa / điểm xuất phát
## (trang trí không có va chạm, nên đặt ngoài lối chơi để không đè lên luật bản đồ chuẩn).
func _free_spot(p: Vector3, clear: float) -> float:
	var g: float = sim.ground(p.x, p.z)
	if g <= Sim.NO_GROUND:
		return Sim.NO_GROUND
	for d in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		if absf(sim.ground(p.x + d.x * clear, p.z + d.z * clear) - g) > 0.01:
			return Sim.NO_GROUND
	var avoid: Array = sim.LV.lanterns.map(func(v): return [v, 7.5]) + sim.LV.motes.map(func(v): return [v, 1.6]) \
		+ sim.LV.pads.map(func(v): return [v.pos, 3.0]) + sim.LV.charms.map(func(v): return [v, 2.0]) + [[sim.LV.start, 3.0]]
	for a in avoid:
		if Sim.xz(p, a[0]) < a[1] + clear:
			return Sim.NO_GROUND
	return g


func _decorate(deco: Array, r: RandomNumberGenerator) -> void:
	var stems := []
	var petals := [[], []]
	var centers := []
	var grass := []
	var rocks := []
	var trunks := []
	var crowns := []
	var pines := []
	for k in range(0, deco.size(), 2):
		var c: Vector3 = deco[k]
		var rad: float = deco[k + 1]
		for i in 900:
			var p: Vector3 = c + Sim._polar(sqrt(r.randf()) * rad, r.randf_range(0, 360))
			var g := _free_spot(p, 0.2)
			if g <= Sim.NO_GROUND:
				continue
			var b := Basis(Vector3.UP, r.randf_range(0, TAU))
			if i % 9 == 0:   # hoa: cuống + vành cánh + nhụy, không phát sáng (khác đom đóm)
				var h := r.randf_range(0.25, 0.45)
				stems.append(Transform3D(b, Vector3(p.x, g + h / 2, p.z)).scaled_local(Vector3(1, h / 0.4, 1)))
				petals[i % 2].append(Transform3D(b, Vector3(p.x, g + h, p.z)))
				centers.append(Transform3D(b, Vector3(p.x, g + h + 0.03, p.z)))
			else:            # bụi cỏ
				var sc := r.randf_range(0.6, 1.3)
				grass.append(Transform3D(b.scaled(Vector3(sc, sc * r.randf_range(0.8, 1.6), sc)), Vector3(p.x, g, p.z)))
		for i in 60:
			var p: Vector3 = c + Sim._polar(r.randf_range(6.0, rad), r.randf_range(0, 360))
			var g := _free_spot(p, 1.0)
			if g <= Sim.NO_GROUND:
				continue
			var sc := r.randf_range(0.5, 1.4)
			rocks.append(Transform3D(Basis(Vector3.UP, r.randf_range(0, TAU)).scaled(Vector3(sc * 1.3, sc * 0.7, sc)), Vector3(p.x, g + 0.15 * sc, p.z)))
		for i in 45:
			var p: Vector3 = c + Sim._polar(r.randf_range(8.0, rad - 1.0), r.randf_range(0, 360))
			var g := _free_spot(p, 2.0)
			if g <= Sim.NO_GROUND:
				continue
			var sc := r.randf_range(0.8, 1.3)
			trunks.append(Transform3D(Basis().scaled(Vector3(sc, sc, sc)), Vector3(p.x, g + 1.1 * sc, p.z)))
			if i % 2 == 0:
				crowns.append(Transform3D(Basis().scaled(Vector3(sc, sc * 0.9, sc)), Vector3(p.x, g + 3.0 * sc, p.z)))
			else:
				pines.append(Transform3D(Basis().scaled(Vector3(sc, sc, sc)), Vector3(p.x, g + 3.2 * sc, p.z)))
	var stem := _cyl(0.02, 0.02, 0.4)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.03
	ring.outer_radius = 0.16
	var blade := _cyl(0.0, 0.09, 0.45)
	var rock := _sphere(0.6)
	var pine := _cyl(0.0, 1.5, 3.4)
	_multi(stem, _mat(C.grass.lightened(0.2)), stems)
	_multi(ring, _mat(C.pink), petals[0])
	_multi(ring, _mat(C.lilac), petals[1])
	_multi(_sphere(0.06), _mat(C.gold), centers)
	_multi(blade, _mat(C.grass.lightened(0.12)), grass)
	_multi(rock, _mat(Color("#5C5A70")), rocks)
	_multi(_cyl(0.35, 0.45, 2.2), _mat(C.wood), trunks)
	_multi(_sphere(1.6), _mat(C.grass.lightened(0.15)), crowns)
	_multi(pine, _mat(C.grass.darkened(0.1)), pines)
	# hàng rào gỗ quanh đèn (đánh dấu vùng an toàn 6 m, không va chạm)
	var posts := []
	for L in sim.LV.lanterns:
		for k in 10:
			var p: Vector3 = L + Sim._polar(6.6, k * 36.0 + 18.0)
			var g: float = sim.ground(p.x, p.z)
			if g > Sim.NO_GROUND and absf(g - L.y) < 0.01:
				posts.append(Transform3D(Basis(), Vector3(p.x, g + 0.45, p.z)))
	var post := BoxMesh.new()
	post.size = Vector3(0.18, 0.9, 0.18)
	_multi(post, _mat(C.wood), posts)


## Nội suy giữa vị trí tick trước và tick hiện tại; bỏ qua khi dịch chuyển xa (hồi sinh).
func _lerp_pos(id: String, cur: Vector3, a: float) -> Vector3:
	var p: Vector3 = prev_pos.get(id, cur)
	return cur if p.distance_to(cur) > 3.0 else p.lerp(cur, a)


func _sync(items: Array, nodes: Dictionary, make: Callable, update: Callable) -> void:
	var alive := {}
	for it in items:
		alive[it.id] = true
		if not nodes.has(it.id):
			nodes[it.id] = make.call()
		update.call(nodes[it.id], it)
	for id in nodes.keys():
		if not alive.has(id):
			nodes[id].queue_free()
			nodes.erase(id)
