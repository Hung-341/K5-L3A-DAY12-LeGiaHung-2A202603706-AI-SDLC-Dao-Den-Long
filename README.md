# Đảo Đèn Lồng (Day 12 · AI SDLC)

> Video demo: *(bổ sung ở Phase 4)*  ·  Tài liệu lab gốc: [LAB-README.md](LAB-README.md)

Game 3D góc nhìn thứ ba (Godot 4.7.2). Mây đội nón lá treo đèn lồng nhỏ, nhặt đom đóm trên ba hòn đảo trôi giữa biển mây, nạp vào các Đèn Lồng Lớn, né Bóng Mực và Gió Lạc. Thắp hết đèn của cả ba Đêm (Đảo Bến, Đảo Cau, Đảo Chuông) trước bình minh thì thắng.

## Cài và chạy (macOS / Linux)

```bash
docker build -t dao-den-long .                                   # build_cmd: image headless (Godot 4.7.2)
./headless.sh --seed 1 --night 1 --ticks 600 --out out/a.jsonl   # headless_cmd
godot --path .                                                   # run_cmd: bản có giao diện (cần Godot 4.7.x)
```

- `headless.sh` dùng Godot 4 cài sẵn nếu có (`GODOT` hoặc `godot` trên PATH), nếu không thì chạy trong Docker image. Mọi đường dẫn `--out/--scenario/--inputs` (tương đối hoặc tuyệt đối) đều dùng được.
- Bản có giao diện cần Godot 4.7.x ([tải tại godotengine.org](https://godotengine.org/download)); bản xuất sẵn sẽ có ở Release `v1.0.0`.

## Điều khiển

| Phím | Việc |
|---|---|
| WASD | Đi (theo hướng camera) |
| Chuột | Xoay camera (độ nhạy chỉnh trong Cài đặt) |
| Space | Nhảy |
| Shift | Lướt |
| E | Nạp đom đóm vào đèn / châm dầu |
| Q | Gió Đèn (5 đom đóm): thổi bay Sương Gai |
| Cuộn chuột | Zoom camera |
| F hoặc chuột trái | Tỏa Sáng |
| Esc hoặc P | Tạm dừng (Tiếp tục / Chơi lại Đêm / Cài đặt / Về menu) |

## Luật và cách tính điểm

- Đom đóm nhặt tự động khi đi qua (≤ 1.0 m), mang tối đa 10. Đứng gần đèn (≤ 2.0 m) bấm E để nạp; đèn cần 10 đom đóm, nạp nhiều lần được.
- Tỏa Sáng tốn **3 đom đóm đang mang**, làm choáng Bóng Mực trong 5 m (2 s) và đẩy lùi 4 m. Hồi chiêu 3 s.
- Bóng Mực chạm: mất 1 Ngọn Lửa (có 3), rơi một nửa số đom đóm đang mang ra quanh Mây, bất tử 1.5 s. Rơi khỏi đảo: mất 1 Ngọn Lửa và toàn bộ đom đóm, hồi sinh ở giữa đảo sau 1 s.
- Đèn đã thắp tạo vùng an toàn 6 m mà Bóng Mực không vào được.
- Ba Đêm: 5 / 6 / 7 đèn, 300 / 330 / 360 s. Đêm 2 có cầu tre và bục nhảy; Đêm 3 có 3 tầng, dốc, gió mạnh. Gió Lạc cướp đom đóm khi Mây mang ≥ 5; Bùa Gió tăng tốc 7.2 m/s và bỏ hồi chiêu Lướt trong 10 s.
- **Từ Phase 3:** đèn có dầu (hao 1/s, Bóng Mực hút 5/s khi dầu < 30), hết dầu thì tắt; thắp lại cần 5 đom đóm; châm dầu bằng E. Thắng khi sống tới bình minh với ≥ 60% đèn đang sáng (3/5, 4/6, 5/7); thua nếu hết Ngọn Lửa hoặc thiếu đèn lúc bình minh. Đêm dài 240 / 270 / 300 s.
- **Điểm (mỗi Đêm, tổng = cộng các Đêm đã thắng):** +5 mỗi đom đóm nạp vào đèn · +100 thắp lần đầu · +40 thắp lại · +5 mỗi Bóng Mực trúng Tỏa Sáng (+15 nếu nó đang hút dầu) · khi thắng: mỗi đèn sáng +50 + floor(dầu), mỗi Ngọn Lửa +50.

Toàn bộ số liệu nằm trong [game.contract.json](game.contract.json). Từ Phase 1 đã dùng **số liệu chuẩn của Ticket-02**, lý do ở [docs/notes/phase1.md](docs/notes/phase1.md).

## Test và headless

```bash
python3 tests/run_tests.py              # 29 scenario headless, gồm kiểm tra tất định và mã thoát 2
```

- Contract: [game.contract.json](game.contract.json) (v1.2). `--night 1|2|3`. Thay đổi phá vỡ tương thích: [CHANGELOG.md](CHANGELOG.md). Output JSONL gồm snapshot, event, end theo Test Contract.
- `fall_enabled: true`: đảo bán kính 40 m, rơi khi Y < −10. Không có khái niệm nào để `null`.
- Bằng chứng từng phase: [docs/proof/](docs/proof/). Ghi chép, giả định, nhật ký AI: [docs/notes/](docs/notes/).

## Sáng tạo của tôi

Phần thêm chia hai loại. Cả hai đều không đổi luật hay số liệu chuẩn.

**A. Chỉ có trong bản giao diện** (`scripts/view.gd`, `scripts/creative.gd`; headless không nạp hai file này, nên output contract không đổi):
- **Sương Gai:** kẻ địch mới (ticket cho phép thêm kẻ địch ngoài Bóng Mực và Gió Lạc). Mỗi 4 đom đóm Mây đang mang thu hút thêm 1 Sương Gai, tối đa 5. Chúng tới từ hướng bất kỳ, nhanh 6 m/s, chạm thì cướp 1 đom đóm và **không trừ Ngọn Lửa**. Người chơi phải chọn: ôm nhiều để thắp và châm dầu nhanh, hay nạp sớm cho an toàn.
- **Gió Đèn (Q):** tốn 5 đom đóm, thổi bay Sương Gai trong 9 m, hồi 4 s. Không tác động Bóng Mực, vì luật chuẩn quy định Bóng Mực chỉ bị Tỏa Sáng đẩy và không chết.
- **Viền tối:** mang càng nhiều đom đóm, rìa màn hình càng tối. Ánh sáng môi trường chuẩn (`0.15 + 0.55 × đèn sáng/tổng`) giữ nguyên.
- **Đảo "đồ chơi trong mơ":** nhân vật chibi, tilt-shift; cây, đá, cỏ, hoa (có cuống và cánh, không phát sáng để không nhầm với đom đóm); hàng rào gỗ đánh dấu vùng an toàn 6 m. Trang trí **không có va chạm** và được đặt tránh đèn, điểm đom đóm, bục nhảy, để không đổi bản đồ chuẩn.
- **Cảm giác điều khiển:** nội suy hình giữa các tick, camera góc nhìn thứ ba xoay tự do (chuột ngang/dọc, cuộn để zoom, không xuyên đất), nhớ phím 0.1 s. Bóng Mực để lại vệt mực khi đuổi; tốc độ thật vẫn là 4.0 m/s.
- Âm thanh tổng hợp bằng code (`scripts/sfx.gd`), không dùng file âm thanh ngoài.

**B. Lựa chọn thiết kế trong khuôn luật** (trong `sim.gd`, có test):
- Đom đóm sinh ở **điểm trống xa Mây nhất**: ticket chỉ nói "một điểm trống". Xem `test_mote_spawn_farthest_free_point`.
- Bóng Mực lang thang theo **4 tính cách** theo id: bám đuôi ở 14 m, tuần tra mép đảo, rình quanh đèn, đi ngẫu nhiên. Tốc độ ≤ 4.0 m/s; luật đuổi, hút dầu, gây hit giữ nguyên. Xem `test_wander_personalities_speed_capped`.

Bằng chứng phần cũ vẫn đúng: toàn bộ test headless vẫn đạt ([docs/proof/](docs/proof/)).

## Harness AI

[AGENTS.md](AGENTS.md) · skill [verify-game](.claude/skills/verify-game/SKILL.md) · hook Stop chặn kết thúc khi test đỏ ([.claude/settings.json](.claude/settings.json)) · CI chạy test mỗi lần push ([.github/workflows/test.yml](.github/workflows/test.yml)) · công cụ chụp ảnh bằng chứng `DDL_SHOT`.
