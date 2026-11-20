extends Node3D
## Sáng tạo của tôi, CHỈ có trong bản giao diện (headless không nạp file này, nên output contract không đổi):
## - Sương Gai: kẻ địch mới, kéo tới nhiều hơn khi Mây mang nhiều đom đóm, chạm thì cướp 1 đom đóm (không trừ Ngọn Lửa).
## - Gió Đèn (Q): tốn 5 đom đóm, thổi bay Sương Gai trong 9 m. Không tác động Bóng Mực (luật chuẩn giữ nguyên).
## - Viền tối: mang càng nhiều đom đóm, rìa màn hình càng tối (không đụng ánh sáng môi trường chuẩn).

const Sim = preload("res://scripts/sim.gd")
const SPEED := 6.0          # nhanh hơn Bóng Mực, tạo áp lực
const TOUCH := 1.0
const PER_MOTES := 4        # mỗi 4 đom đóm đang mang thu hút 1 Sương Gai
const MAX_THORNS := 5
const SPAWN_EVERY := 2.0
const WIND_COST := 5
const WIND_R := 9.0
const WIND_PUSH := 12.0
const WIND_CD := 4.0

var view
var sim
var thorns: Array = []      # {node, pos, push: Vector3, flee}
var spawn_t := 0.0
var wind_cd := 0.0
var rng := RandomNumberGenerator.new()
var vignette: ColorRect
var vig_mat: ShaderMaterial


func setup(v, layer: CanvasLayer) -> void:
	view = v
	vignette = ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform float strength = 0.0;
void fragment() {
	vec2 uv = SCREEN_UV - 0.5;
	float d = length(uv * vec2(1.5, 1.0));
	COLOR = vec4(0.03, 0.02, 0.08, smoothstep(0.30, 0.85, d) * strength);
}"""
	vig_mat = ShaderMaterial.new()
	vig_mat.shader = sh
	vignette.material = vig_mat
	layer.add_child(vignette)
	layer.move_child(vignette, 0)


func reset(new_sim) -> void:
	sim = new_sim
	for t in thorns:
		t.node.queue_free()
	thorns.clear()
	spawn_t = 0.0
	wind_cd = 0.0


func _make_thorn() -> Node3D:
	var n := Node3D.new()
	view.world.add_child(n)
	view._mesh(view._sphere(0.45), view._mat(Color("#2A1640")), Vector3.ZERO, n)
	for i in 10:
		var d := Vector3(cos(i * 2.4), sin(i * 1.7) * 0.8, sin(i * 2.4)).normalized()
		var spike: MeshInstance3D = view._mesh(view._cyl(0.0, 0.1, 0.5), view._mat(Color("#B48CFF"), 1.5), d * 0.5, n)
		spike.look_at_from_position(d * 0.5, d * 2.0, Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT)
		spike.rotate_object_local(Vector3.RIGHT, -PI / 2)
	return n


## Gọi mỗi tick vật lý sau sim.step (chỉ khi đang chơi).
func tick(dt: float, wind_pressed: bool) -> void:
	var cap: int = sim.capacity()
	vig_mat.set_shader_parameter("strength", 0.15 + 0.65 * float(sim.carried) / max(1, cap))
	wind_cd = max(0.0, wind_cd - dt)
	if wind_pressed and wind_cd == 0.0 and sim.carried >= WIND_COST and sim.fall_wait == 0:
		sim.carried -= WIND_COST
		wind_cd = WIND_CD
		view.sfx.play("pulse")
		for t in thorns:
			var d: Vector3 = t.pos - sim.p_pos
			d.y = 0
			if d.length() <= WIND_R:
				t.push = (d.normalized() if d.length() > 0.01 else Vector3.RIGHT) * WIND_PUSH
				t.flee = 2.0
	# số Sương Gai bị thu hút theo số đom đóm đang mang
	var want := mini(MAX_THORNS, sim.carried / PER_MOTES)
	spawn_t += dt
	if thorns.size() < want and spawn_t >= SPAWN_EVERY:
		spawn_t = 0.0
		for i in 12:  # điểm ngẫu nhiên trên đảo, cách Mây 18–28 m, hướng bất kỳ
			var p: Vector3 = sim.p_pos + Sim._polar(rng.randf_range(18.0, 28.0), rng.randf_range(0, 360))
			var g: float = sim.ground(p.x, p.z)
			if g > Sim.NO_GROUND:
				thorns.append({"node": _make_thorn(), "pos": Vector3(p.x, g + 0.8, p.z), "push": Vector3.ZERO, "flee": 0.0})
				view.sfx.play("spawn")
				break
	for t in thorns.duplicate():
		var to: Vector3 = sim.p_pos - t.pos
		to.y = 0
		var vel := Vector3.ZERO
		if t.flee > 0.0:
			t.flee -= dt
			vel = -to.normalized() * SPEED * 0.6
		elif sim.carried >= PER_MOTES / 2 and sim.fall_wait == 0:
			vel = to.normalized() * SPEED
		elif to.length() < 30.0:
			vel = -to.normalized() * 2.0  # tay trắng thì Sương Gai tản đi
		else:
			t.node.queue_free()
			thorns.erase(t)
			continue
		vel += t.push
		t.push = t.push.move_toward(Vector3.ZERO, 30.0 * dt)
		var nxt: Vector3 = t.pos + vel * dt
		var g: float = sim.ground(nxt.x, nxt.z)
		if g > Sim.NO_GROUND:
			t.pos = Vector3(nxt.x, g + 0.8, nxt.z)
		if t.flee <= 0.0 and to.length() <= TOUCH and sim.carried > 0 and sim.fall_wait == 0:
			sim.carried -= 1
			t.flee = 2.5
			view.sfx.play("hit")


func render(t: float) -> void:
	for th in thorns:
		th.node.position = th.pos + Vector3(0, 0.15 * sin(t * 6.0 + th.node.get_instance_id()), 0)
		th.node.rotation.y = t * 3.0
