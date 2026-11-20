# Thiết kế ngắn: Đảo Đèn Lồng (Phase 1)

## Ý định
Game 3D sinh tồn trong một giấc mơ: Mây thắp đủ 5 đèn ở 5 khu vực của đảo **nhanh nhất có thể**. Muốn về đích sớm thì người chơi phải tính toán: tỉnh táo (máu), thể lực, quãng đường và đom đóm đang mang. Theo triết lý trong vault, game phải vui trước, thử thách phải công bằng (có báo trước, thua là do người chơi, chơi lại nhanh) và mọi ràng buộc phải tạo ra quyết định.

## Mục tiêu / không làm / phản mục tiêu
- **Mục tiêu:** đạt Test Contract v1.0, chơi được Đêm 1 từ đầu tới thắng hoặc thua, có bằng chứng, có tag `phase-1` đúng hạn.
- **Không làm ở Phase 1:** tỉnh táo rút theo thời gian, thể lực, đàn đom đóm di chuyển hoặc nấp ở gốc cây, Ác mộng. Các phần này dời sang đầu Phase 2 và chỉ bật trong bản có giao diện.
- **Phản mục tiêu:** phần sáng tạo làm đổi output headless; đồ họa ngốn thời gian khiến lõi chưa xong; ghi "đạt" cho thứ chưa kiểm chứng.

## Ràng buộc
Godot 4 trên Windows. Giảng viên chạy trên macOS/Linux qua **Docker**. Contract chạy cố định 60 tick mỗi giây, output tất định. Phong cách nhân vật và bối cảnh là bản gốc, không sao chép game có sẵn.

## Các hướng đã cân nhắc
| Hướng | Đánh đổi | Kết quả |
|---|---|---|
| A. Lõi GDScript thuần, tách khỏi phần hiển thị | Tất định và dễ test, nhưng tự viết va chạm | Không chọn |
| **B. Node và physics của Godot, headless chạy cùng scene** | Viết nhanh, một scene duy nhất; rủi ro tất định và tốc độ | **Bạn chọn** |
| C. Headless bằng Python, hiển thị bằng Godot | Hai bản logic dễ lệch nhau | Loại |

Biện pháp giảm rủi ro cho B: chạy `--headless --fixed-fps 60`, đặt gameplay trong `_physics_process`, đo khoảng cách contract bằng phép tính XZ thuần, làm tròn 3 chữ số. **Spike đầu tiên** là chạy cùng seed hai lần và so file bằng `diff`.

## Kiến trúc (B)
- `Main.tscn`: đảo, `Player` (CharacterBody3D), `Shade` (CharacterBody3D), đom đóm và đèn (Node3D, kiểm tra bằng khoảng cách), HUD, camera.
- `Game.gd`: toàn bộ luật chơi (nhặt, nạp, thắp, pulse, bị chạm, thắng/thua, điểm). Phát ra signal cho các sự kiện.
- `HeadlessDriver.gd`: chỉ hoạt động khi có cờ `--headless-run`. Đọc `OS.get_cmdline_user_args()`, dựng scenario, đưa input của tick k vào bước k, ghi JSONL, thoát với mã 0, 1 hoặc 2.
- Các RNG đều là `RandomNumberGenerator` lấy seed từ `--seed`. Không dùng `randf()` toàn cục.
- Docker: image Linux chứa Godot headless cùng phiên bản. `headless_cmd = docker run --rm -v "$PWD":/w dao-den-long godot --headless --path /w --fixed-fps 60 -- --headless-run`.

## Luật chơi và tuning (giả định, khai trong game.contract.json)
| Khóa | Giá trị | Giả định |
|---|---|---|
| player_speed | 5.5 | m/s khi đi bộ |
| carry_capacity | 8 | Mang đầy thì không nhặt thêm |
| lantern_cost | 6 | Bấm interact trong interact_radius để nạp `min(carried, cost - deposited)`. Nạp đủ thì đèn sáng |
| lantern_count_night1 | 5 | Đặt ở 5 khu vực trên vòng tròn bán kính 20 m, L1 ở (0, 0, 20), các đèn sau cách nhau 72° |
| pickup_radius | 1.2 | Nhặt tự động khi đi qua |
| interact_radius | 2.5 | |
| pulse_cost | 2 | **Trừ vào đom đóm đang mang.** Mang không đủ thì pulse không có tác dụng và không phát event |
| pulse_radius | 6 | |
| pulse_stun_s / pulse_push_m / pulse_cooldown_s | 2.5 / 4 / 3 | |
| night1_duration_s | 420 | Hết giờ thì thua với reason `dawn` |
| flames | **100** | Tỉnh táo chính là máu. Mỗi lần Bóng Mực chạm trừ **34** (ghi trong README). Về 0 thì thua với reason `no_flames` |
| invuln_s | 1.5 | |
| hit_drop_ratio | 0.5 | Đánh rơi `floor(carried × 0.5)`. Đom đóm rơi thì biến mất |
| safe_radius | 7 | Chỉ áp dụng quanh đèn **đã thắp**. Bóng Mực không vào được vùng này |
| shade_speed / shade_hit_radius | 3.2 / 1.0 | Đuổi khi người chơi ở trong 12 m, ngoài ra thì đi lang thang |
| fall_enabled | false | Mép đảo bán kính 30 m có tường vô hình |
| score | per_mote 10, per_lantern 100, per_stun 25, per_second_left 2, per_flame_left 1 | Hai khoản thưởng cuối chỉ cộng khi thắng |

- **Sinh đối tượng mặc định:** có 30 đom đóm cố định theo bố cục đảo. Nếu `random_motes` bật thì sinh thêm mỗi 3 giây, tối đa 40 con. Bóng Mực đầu tiên xuất hiện ở giây 20, sau đó mỗi 20 giây một con, tối đa 4 con, sinh ở mép đảo kèm event `shade_spawned`.
- **Nhảy:** chỉ thay đổi `pos.y`, không ảnh hưởng luật nào khác.

## Phong cách (lớp hiển thị)
- Đảo trông như mô hình đồ chơi trong mơ. Camera bám sau lưng nhìn chéo từ trên cao khoảng 50°, có tilt-shift nhẹ.
- Toon shading 2–3 bậc sáng, nhân vật tỉ lệ chibi.
- Đất màu hồng lavender, trời tím đậm. Đèn và đom đóm màu vàng ấm. Bóng Mực là mực đen ánh tím, có răng nanh, không có máu me.
- Khu vực quanh đèn đã thắp chuyển sang hồng ấm.
- Chỉ dùng hình khối có sẵn của Godot, không làm model riêng.

## Để builder tự quyết
Kích thước mesh, shader cụ thể, bố cục 30 đom đóm, công thức nhảy, nội dung HUD (thời gian, tỉnh táo, số đom đóm đang mang, số đèn đã thắp, điểm). Lệnh `run_cmd` ở Phase 1 dùng Godot cài trên máy; bản web hoặc bản xuất chạy được để dành cho Phase 4.

## Kiểm chứng
- Scenario headless cho từng luật: nhặt, nạp và thắp, pulse đủ và thiếu đom đóm, bị chạm có invuln và rơi đom đóm, vùng an toàn, thua `dawn`, thua `no_flames`, thắng `all_lit`, file input sai trả mã 2.
- Chạy hai lần rồi so bằng `diff` để kiểm tra tính tất định.
- Một lệnh chạy toàn bộ kiểm chứng.
- Ảnh chụp game có giao diện.
