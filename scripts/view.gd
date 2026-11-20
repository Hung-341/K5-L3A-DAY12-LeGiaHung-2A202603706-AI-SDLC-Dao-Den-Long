extends Node3D
## Bản có giao diện: đọc trạng thái Sim để vẽ. Không chứa luật chơi.
## Điều khiển: WASD đi, chuột xoay camera, Space nhảy, Shift lướt, E nạp đèn, F/chuột trái tỏa sáng, R chơi lại, Esc nhả chuột.

const Sim = preload("res://scripts/sim.gd")
const C := {
	"sky": Color("#0E1430"), "fog": Color("#1B2350"), "grass": Color("#2F5D50"), "sand": Color("#C9B48A"),
	"wood": Color("#6B4A2F"), "sea": Color("#12384A"), "lamp_on": Color("#FFB347"), "lamp_core": Color("#FFE9B0"),
	"lamp_off": Color("#5B5F6E"), "mote": Color("#FFF6C2"), "mote_halo": Color("#FFE58A"), "shade": Color("#120A1A"),
	"shade_rim": Color("#7A3CFF"), "shade_stun": Color("#3A3450"), "coat": Color("#E8E2D0"), "scarf": Color("#C8102E"),
	"gold": Color("#F2C14E"), "danger": Color("#FF5A5F"), "ui": Color("#F5F1E6"),
	# điểm nhấn "giấc mơ" (ngoài bảng màu bắt buộc)
	"pink": Color("#F4A6D7"), "lilac": Color("#B48CFF"), "skin": Color("#F6D7B8"),
}

var sim
var yaw := 0.0
var cam: Camera3D
var env: Environment
var player: Node3D
var mote_nodes := {}
var shade_nodes := {}
var lantern_nodes := {}
var hud: Label
var hud_mid: Label
var hud_right: Label
var hud_bottom: Label
var banner: Label


func _ready() -> void:
	_build_world()
	_build_hud()
	_new_game()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _new_game() -> void:
	sim = Sim.new(randi(), Sim.load_tuning())
	for d in [mote_nodes, shade_nodes]:
		for n in d.values():
			n.queue_free()
		d.clear()
	banner.visible = false


func _mat(c: Color, emit := 0.0, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c, alpha)
	m.roughness = 0.9
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


func _mesh(mesh: Mesh, mat: Material, pos := Vector3.ZERO, parent: Node = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2
	return s


func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	return c


func _build_world() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = C.sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.7, 1.0)
	env.ambient_light_energy = 0.15
	env.fog_enabled = true
	env.fog_light_color = C.fog
	env.fog_density = 0.006
	env.glow_enabled = true
	env.glow_bloom = 0.25
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.8, 0.75, 1.0)
	moon.light_energy = 0.5
	moon.shadow_enabled = true
	moon.rotation_degrees = Vector3(-55, 30, 0)
	add_child(moon)
	# đảo: mặt cỏ, vách cát, biển mây phía dưới
	_mesh(_cyl(Sim.ISLAND_R, Sim.ISLAND_R, 0.6), _mat(C.grass), Vector3(0, -0.3, 0))
	_mesh(_cyl(Sim.ISLAND_R, Sim.ISLAND_R * 0.7, 8.0), _mat(C.sand), Vector3(0, -4.6, 0))
	var sea := PlaneMesh.new()
	sea.size = Vector2(600, 600)
	_mesh(sea, _mat(C.sea, 0.15), Vector3(0, -14, 0))
	# trăng lưỡi liềm hồng: hai quả cầu chồng nhau
	_mesh(_sphere(9.0), _mat(C.pink, 1.6), Vector3(-60, 55, 120))
	_mesh(_sphere(8.6), _mat(C.sky), Vector3(-56, 57, 118))
	# hoa hồng tím + đá rải rác (cố định theo seed riêng, chỉ để trang trí)
	var r := RandomNumberGenerator.new()
	r.seed = 7
	for i in 140:
		var p := Sim._polar(r.randf_range(4.0, 38.5), r.randf_range(0, 360))
		var col: Color = C.pink if i % 2 == 0 else C.lilac
		_mesh(_sphere(0.16), _mat(col, 0.6), p + Vector3(0, 0.15, 0))
	for i in 18:
		var p := Sim._polar(r.randf_range(8.0, 37.0), r.randf_range(0, 360))
		var tree := Node3D.new()
		tree.position = p
		add_child(tree)
		_mesh(_cyl(0.35, 0.45, 2.2), _mat(C.wood), Vector3(0, 1.1, 0), tree)
		_mesh(_sphere(1.6), _mat(C.grass.lightened(0.15)), Vector3(0, 3.0, 0), tree)
	# đèn lồng lớn
	for L in sim_lanterns_default():
		var n := Node3D.new()
		n.position = L.pos
		add_child(n)
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
		lantern_nodes[L.id] = {"lamp": lamp, "light": light, "ring": ring}
	player = _make_player()
	cam = Camera3D.new()
	cam.fov = 45
	var ca := CameraAttributesPractical.new()
	ca.dof_blur_far_enabled = true
	ca.dof_blur_far_distance = 32.0
	ca.dof_blur_far_transition = 18.0
	ca.dof_blur_near_enabled = true
	ca.dof_blur_near_distance = 8.0
	ca.dof_blur_near_transition = 4.0
	ca.dof_blur_amount = 0.12
	cam.attributes = ca
	add_child(cam)


func sim_lanterns_default() -> Array:
	var out := []
	for i in Sim.LANTERN_POS.size():
		out.append({"id": "L%d" % (i + 1), "pos": Sim.LANTERN_POS[i]})
	return out


## Mây: chibi đầu to, áo kem, khăn đỏ, nón lá treo đèn lồng nhỏ.
func _make_player() -> Node3D:
	var p := Node3D.new()
	add_child(p)
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
	var lan := _mesh(_sphere(0.12), _mat(C.lamp_on, 3.0), Vector3(0.7, 1.15, 0.3), p)
	var l := OmniLight3D.new()
	l.light_color = C.lamp_on
	l.omni_range = 4.5
	l.light_energy = 1.2
	lan.add_child(l)
	return p


func _make_shade() -> Node3D:
	var s := Node3D.new()
	add_child(s)
	var rim := _mesh(_sphere(0.78), _mat(C.shade_rim, 1.2, 0.35), Vector3.ZERO, s)
	rim.name = "rim"
	var body := _mesh(_sphere(0.7), _mat(C.shade), Vector3.ZERO, s)
	body.name = "body"
	for x in [-0.22, 0.22]:
		_mesh(_sphere(0.09), _mat(C.shade_rim, 3.0), Vector3(x, 0.18, 0.6), s)
	for x in [-0.15, 0.0, 0.15]:
		var f := _mesh(_cyl(0.0, 0.06, 0.18), _mat(Color.WHITE), Vector3(x, -0.12, 0.64), s)
		f.rotation_degrees.x = 180
	return s


func _build_hud() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	hud = _label(cl, Vector2(24, 18), HORIZONTAL_ALIGNMENT_LEFT)
	hud_mid = _label(cl, Vector2(0, 18), HORIZONTAL_ALIGNMENT_CENTER)
	hud_right = _label(cl, Vector2(0, 18), HORIZONTAL_ALIGNMENT_RIGHT)
	hud_bottom = _label(cl, Vector2(0, 0), HORIZONTAL_ALIGNMENT_CENTER)
	hud_bottom.position = Vector2(-300, -90)
	hud_bottom.size = Vector2(600, 60)
	hud_mid.position = Vector2(-150, 18)
	hud_mid.size = Vector2(300, 40)
	hud_right.position = Vector2(-324, 18)
	hud_right.size = Vector2(300, 40)
	banner = _label(cl, Vector2.ZERO, HORIZONTAL_ALIGNMENT_CENTER)
	banner.position = Vector2(-300, -60)
	banner.size = Vector2(600, 120)
	banner.add_theme_font_size_override("font_size", 34)


func _label(parent: Node, pos: Vector2, align: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", C.ui)
	l.add_theme_color_override("font_outline_color", C.sky)
	l.add_theme_constant_override("outline_size", 6)
	parent.add_child(l)
	return l


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= e.relative.x * 0.25
	elif e is InputEventMouseButton and e.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif e is InputEventKey and e.pressed and e.keycode == KEY_R and sim.state != "playing":
		_new_game()


func _key(k: Key) -> bool:
	return Input.is_physical_key_pressed(k)


func _physics_process(_dt: float) -> void:
	# camera phía sau nhìn hướng forward(θ) = (sinθ, 0, cosθ); phải màn hình là -x của contract
	var mx := (1.0 if _key(KEY_A) else 0.0) - (1.0 if _key(KEY_D) else 0.0)
	var mz := (1.0 if _key(KEY_W) else 0.0) - (1.0 if _key(KEY_S) else 0.0)
	sim.step({"move": [mx, mz], "cam_yaw_deg": yaw, "jump": _key(KEY_SPACE), "interact": _key(KEY_E),
		"pulse": _key(KEY_F) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), "dash": _key(KEY_SHIFT)})
	sim.events.clear()


var _frames := 0

func _process(_dt: float) -> void:
	_frames += 1
	var shot := OS.get_environment("DDL_SHOT")  # bằng chứng: chụp màn hình sau N frame rồi thoát
	if shot != "" and _frames == int(OS.get_environment("DDL_SHOT_FRAMES") if OS.get_environment("DDL_SHOT_FRAMES") != "" else "120"):
		get_viewport().get_texture().get_image().save_png(shot)
		get_tree().quit()
	var t := Time.get_ticks_msec() / 1000.0
	var vp := get_viewport().get_visible_rect().size
	hud_mid.position = Vector2(vp.x / 2 - 150, 18)
	hud_right.position = Vector2(vp.x - 324, 18)
	hud_bottom.position = Vector2(vp.x / 2 - 300, vp.y - 70)
	banner.position = Vector2(vp.x / 2 - 300, vp.y / 2 - 60)
	player.position = sim.p_pos
	player.rotation.y = atan2(sim.p_face.x, sim.p_face.z)
	player.visible = sim.fall_wait == 0 and (sim.invuln == 0 or int(t * 12) % 2 == 0)
	var th := deg_to_rad(yaw)
	var fwd := Vector3(sin(th), 0, cos(th))
	var focus: Vector3 = sim.p_pos + Vector3(0, 1.0, 0)
	cam.position = focus - fwd * 13.0 + Vector3(0, 11.0, 0)
	cam.look_at(focus)
	(cam.attributes as CameraAttributesPractical).dof_blur_far_distance = cam.position.distance_to(focus) + 6.0
	_sync(sim.motes, mote_nodes, func(): return _mesh(_sphere(0.22), _mat(C.mote, 4.0)),
		func(n, m): n.position = m.pos + Vector3(0, 0.7 + 0.15 * sin(t * 3.0 + n.get_instance_id()), 0))
	_sync(sim.shades, shade_nodes, _make_shade, func(n, s):
		n.position = s.pos
		if Sim.xz(s.pos, sim.p_pos) > 0.1:
			n.look_at(Vector3(sim.p_pos.x, s.pos.y, sim.p_pos.z), Vector3.UP, true)
		var stun: bool = s.state == "stunned"
		n.get_node("body").material_override.albedo_color = C.shade_stun if stun else C.shade
		n.scale = Vector3.ONE * (0.4 if s.state == "spawning" else 1.0 + 0.06 * sin(t * 5.0)))
	var lit := 0
	for L in sim.lanterns:
		var ln: Dictionary = lantern_nodes[L.id]
		ln.lamp.material_override = _mat(C.lamp_on, 3.0) if L.lit else _mat(C.lamp_off.lerp(C.lamp_on, L.deposited / 10.0 * 0.5))
		ln.light.light_energy = 2.5 if L.lit else 0.0
		ln.ring.visible = L.lit
		lit += int(L.lit)
	env.ambient_light_energy = 0.15 + 0.55 * lit / sim.lanterns.size()
	var tl: float = max(sim.time_left, 0.0)
	hud.text = "Ngọn Lửa  %s" % ("● ".repeat(sim.flames) + "○ ".repeat(max(0, 3 - sim.flames)))
	hud_mid.text = "%02d:%02d" % [int(tl) / 60, int(tl) % 60]
	hud_mid.add_theme_color_override("font_color", C.danger if tl <= 30 and int(t * 4) % 2 == 0 else C.ui)
	hud_right.text = "Đèn %d/%d   Điểm %d" % [lit, sim.lanterns.size(), sim.score]
	var near := ""
	for L in sim.lanterns:
		if not L.lit and Sim.xz(sim.p_pos, L.pos) <= 2.0:
			near = "   E — Nạp ánh sáng (%d/10)" % L.deposited
	hud_bottom.text = "Đom đóm  %s%s%s" % ["■".repeat(sim.carried), "□".repeat(10 - sim.carried), near]
	if sim.state != "playing":
		banner.visible = true
		banner.text = ("Bình minh lên! Thắng — %d điểm" % sim.score if sim.state == "won" else "Thua rồi… — %d điểm" % sim.score) + "\nNhấn R để chơi lại"


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
