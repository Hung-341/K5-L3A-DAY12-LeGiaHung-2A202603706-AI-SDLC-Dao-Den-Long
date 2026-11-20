# Đảo Đèn Lồng (Day 12 · AI SDLC)

> Video demo: *(bổ sung ở Phase 4)*  ·  Tài liệu lab gốc: [LAB-README.md](LAB-README.md)

Game 3D góc nhìn thứ ba (Godot 4.7.2). Mây đội nón lá treo đèn lồng nhỏ, nhặt đom đóm trên đảo trôi giữa biển mây, nạp vào 5 Đèn Lồng Lớn, né Bóng Mực. Thắp hết đèn trước bình minh thì thắng.

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
| Chuột | Xoay camera (Esc để nhả chuột, click để bắt lại) |
| Space | Nhảy |
| Shift | Lướt |
| E | Nạp đom đóm vào đèn gần nhất |
| F hoặc chuột trái | Tỏa Sáng |
| R | Chơi lại sau khi thắng/thua |

## Luật và cách tính điểm

- Đom đóm nhặt tự động khi đi qua (≤ 1.0 m), mang tối đa 10. Đứng gần đèn (≤ 2.0 m) bấm E để nạp; đèn cần 10 đom đóm, nạp nhiều lần được.
- Tỏa Sáng tốn **3 đom đóm đang mang**, làm choáng Bóng Mực trong 5 m (2 s) và đẩy lùi 4 m. Hồi chiêu 3 s.
- Bóng Mực chạm: mất 1 Ngọn Lửa (có 3), rơi một nửa số đom đóm đang mang ra quanh Mây, bất tử 1.5 s. Rơi khỏi đảo: mất 1 Ngọn Lửa và toàn bộ đom đóm, hồi sinh ở giữa đảo sau 1 s.
- Đèn đã thắp tạo vùng an toàn 6 m mà Bóng Mực không vào được.
- Thắng: thắp đủ 5 đèn. Thua: hết Ngọn Lửa, hoặc hết 300 s (bình minh).
- **Điểm:** +10 mỗi đom đóm *nạp vào đèn* · +100 mỗi đèn thắp · +5 mỗi Bóng Mực trúng Tỏa Sáng · khi thắng thêm `floor(giây còn lại) × 2 + 50 × Ngọn Lửa còn lại`.

Toàn bộ số liệu nằm trong [game.contract.json](game.contract.json). Từ Phase 1 đã dùng **số liệu chuẩn của Ticket-02**, lý do ở [docs/notes/phase1.md](docs/notes/phase1.md).

## Test và headless

```bash
python3 tests/run_tests.py              # 29 scenario headless, gồm kiểm tra tất định và mã thoát 2
```

- Contract: [game.contract.json](game.contract.json) (v1.0). Output JSONL gồm snapshot, event, end theo Test Contract.
- `fall_enabled: true`: đảo bán kính 40 m, rơi khi Y < −10. Không có khái niệm nào để `null`.
- Bằng chứng từng phase: [docs/proof/](docs/proof/). Ghi chép, giả định, nhật ký AI: [docs/notes/](docs/notes/).

## Sáng tạo của tôi

- **Phong cách "đảo đồ chơi trong mơ":** nhân vật chibi đầu to, camera nhìn chéo từ trên cao có tilt-shift (DOF gần/xa), hoa hồng tím rải khắp đảo, trăng lưỡi liềm hồng. Màu chính theo bảng chuẩn; hồng tím chỉ dùng cho chi tiết trang trí.
- Bóng Mực có mắt tím phát sáng, răng nanh trắng, phình xẹp như đang thở; lúc vừa sinh ra thì nhỏ lại (trạng thái `spawning`, vô hại 0.5 s) để người chơi kịp thấy.
- Toàn bộ phần thêm chỉ nằm trong `scripts/view.gd`, không đụng `sim.gd`, nên output headless không đổi. Bằng chứng: 29/29 test vẫn đạt ([run_tests.txt](docs/proof/phase1/run_tests.txt)).

## Harness AI

[AGENTS.md](AGENTS.md) · hook Stop chặn kết thúc khi test đỏ ([.claude/settings.json](.claude/settings.json)) · CI chạy test mỗi lần push ([.github/workflows/test.yml](.github/workflows/test.yml)) · công cụ chụp ảnh bằng chứng `DDL_SHOT`.
