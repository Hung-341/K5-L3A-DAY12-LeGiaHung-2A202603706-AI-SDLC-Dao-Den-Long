# AGENTS.md — Đảo Đèn Lồng (Godot 4.7.2)

## Lệnh
- Test (bắt buộc xanh trước khi xong việc): `python tests/run_tests.py` (biến `GODOT` trỏ tới Godot 4 console nếu không có trên PATH)
- Headless: `./headless.sh --seed 1 --night 1 --ticks 600 --out out/a.jsonl [--scenario f] [--inputs f]`
- Build image chấm: `docker build -t dao-den-long .`
- Chơi / bench / soak: `./run.sh`, `./bench.sh --seed 42 --duration 30 --out bench.json` (cắm sạc, cần GPU), `./headless.sh --soak --seed 7 --nights 10 --out soak.json`
- Bằng chứng (test, ảnh, FPS, Docker): skill `.claude/skills/verify-game`. Ảnh: `DDL_NIGHT=n DDL_AUTOPLAY=1 DDL_SHOT=... godot --path . --resolution 1280x720`
- Sau khi thêm/đổi script: `godot --headless --path . --import`

## Kiến trúc
- `scripts/sim.gd`: TOÀN BỘ luật chơi trong `step()`, theo thứ tự 12 bước của Ticket-02. Không phụ thuộc node.
- `Sim.level(n)` / `ground_at(n,x,z)`: bản đồ chuẩn 3 Đêm (Ticket-02 Phần 2). Góc: điểm = (r cos a, y, r sin a).
- `scripts/headless.gd`: đọc tham số (`--night 1..3`), validate (sai định dạng → exit 2), ghi JSONL v1.1. `scripts/view.gd`: chỉ vẽ + menu/HUD. `scripts/sfx.gd`: âm thanh tổng hợp.
- Số liệu đọc từ `game.contract.json` (`Sim.load_tuning()`), hằng số khác là `const` đầu `sim.gd`.

## Quy tắc
- Không dùng `class_name`; dùng `preload` (image Docker và máy chấm có thể chưa import).
- Không dùng RNG toàn cục; chỉ `sim.rng` (seed từ `--seed`). Output phải giống hệt từng byte giữa hai lần chạy.
- Sáng tạo thêm chỉ ở `view.gd` hoặc tắt khi headless; không được đổi output headless.
- Contract hiện tại: v1.3 (thêm bench_cmd, soak_cmd; cảnh bench = `Sim.setup_bench`, cờ `bench` tắt sinh/hit/nhặt/hao/kết thúc).
- Sáng tạo chỉ ở GUI nằm trong `scripts/creative.gd` (không gọi trong bench/headless).
- Hiệu năng GUI: không gán vật liệu / cỡ chữ / theme mỗi khung hình; bench phải giữ p1_low ≥ 30.
- Contract v1.2 (dầu đèn, drain, thắng dawn_survived; xem docs/adr/0001). Dầu lưu số nguyên đơn vị 1/60 (`Sim.FU`); vùng an toàn luôn qua `_safe(L)`, không kiểm `lit` trực tiếp.
- Luật bị thay: xóa/sửa test kèm lý do ngay trong test + CHANGELOG.md.
- Contract trước: v1.1. Tên trạng thái Bóng Mực cố định: spawning, wander, chase, recoil, stunned.
- So "trong bán kính r" luôn cộng `EPS`; so mép vùng an toàn dùng dung sai (lỗi float đã gặp ở Phase 2).
- Mỗi luật mới có ít nhất một test trong `tests/run_tests.py`; test sai vì đổi yêu cầu thì sửa kèm lý do trong `docs/notes/`.
- Không sửa tay file output; không viết test luôn đạt.
- Commit nhỏ, subject tiếng Anh, body tiếng Việt; không ghi co-author AI.
