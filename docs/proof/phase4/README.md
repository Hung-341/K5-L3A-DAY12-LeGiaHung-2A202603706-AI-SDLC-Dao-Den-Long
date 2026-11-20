# Bằng chứng Phase 4 (Contract v1.3)

Lệnh chạy lại test: `python3 tests/run_tests.py` → [run_tests.txt](run_tests.txt) (đạt 78/78). Bộ test gồm toàn bộ test Phase 1–3 còn hiệu lực.

## Số đo (máy tự đo, chỉ để tham khảo; máy chấm do giảng viên công bố)
Máy đo: Windows 11 (10.0.26200), NVIDIA GeForce GTX 1660 Ti, **cắm sạc**, Godot 4.7.2 Forward+.

| Mục | Kết quả | Ngưỡng | File |
|---|---|---|---|
| Benchmark `./bench.sh --seed 42 --duration 30` | avg_fps **135.9**, p1_low_fps **43.0**, p95 12.23 ms, load_ms **2754**, peak RSS 584.6 MB, vsync tắt, 4077 khung hình | avg ≥ 60, p1_low ≥ 30, load ≤ 10000 | [bench.json](bench.json) |
| Soak `./headless.sh --soak --seed 7 --nights 10` | crashes **0**, RSS 93.7 → 93.9 MB (×1.002) | crashes = 0, end ≤ 1.2 × start | [soak.json](soak.json) |
| Soak trên Linux (Docker, giống máy chấm không có Godot) | crashes **0**, RSS 113.2 → 113.4 MB | như trên | [soak-linux-docker.json](soak-linux-docker.json) |

Khi máy chạy pin, driver khóa ở 30 FPS (xem retro mục 3), nên bench được đo khi máy cắm sạc.

## Truy vết yêu cầu Ticket-04
| Yêu cầu | Kiểm chứng | Kết quả |
|---|---|---|
| 1. Cảnh bench chuẩn: 200 Bóng Mực wander, 100 đom đóm, L1–L3 sáng 100 dầu; tắt sinh thêm, sát thương, nhặt, hao dầu, kết thúc | `Sim.setup_bench` + cờ `bench` trong `step()`; ảnh [bench-scene.png](bench-scene.png) | Đạt |
| 1. Cửa sổ 1280×720, vsync tắt, camera bay vòng r30, y15, 15 s/vòng, bắt đầu ở (30,15,0); khởi động 3 s, đo `--duration` s rồi thoát mã 0 | `view.gd: _start_bench/_bench_frame`; bench.json `vsync_off: true`, `frames` 4077 | Đạt |
| 1. Công thức avg_fps, p1_low_fps (k = max(1, ceil(0.01N)) dt lớn nhất), p95, load_ms, peak RSS | `view.gd: _write_bench` | Đạt |
| 1. Sáng tạo tắt trong bench | Không gọi `creative.tick` (không có Sương Gai), HUD không cập nhật | Đạt |
| 2. Soak 10 Đêm, seed 7 + i, xoay Đêm 1→2→3, input ngẫu nhiên (mỗi 30 tick đổi hướng; 5% nhảy, 3% lướt, 2% tỏa sáng, 10% tương tác), đo RSS | `headless.gd: _soak`; `test_soak`, `test_soak_deterministic_results` | Đạt |
| 3. Bảng xếp hạng: tên 3–12 ký tự (gồm tiếng Việt có dấu), top 10, điểm giảm dần, bằng điểm thì ai đạt trước đứng trên, ISO 8601 có múi giờ, lưu đĩa, màn hình mở từ menu, nhập tên sau Bình Minh hoặc khi thua | `test_leaderboard_order_top10_export`, `test_leaderboard_name_rules`; GUI | Đạt |
| 3. `<run_cmd> --export-leaderboard out.json` | `./run.sh --export-leaderboard out.json` (đã chạy, xem test) | Đạt |
| 4. Đổi phím mọi hành động, báo trùng, khôi phục mặc định, lưu | Cài đặt → Đổi phím (`_show_keys`, `_input`) | Đạt (kiểm bằng tay) |
| 4. Phụ đề và chỉ báo: Bóng Mực xuất hiện (mũi tên mép màn hình), gió sắp thổi, 10 s cuối, đèn < 30 dầu | Ảnh [a11y-subtitle.png](a11y-subtitle.png) | Đạt |
| 4. Giảm chuyển động (tắt rung camera, chớp màn hình); chữ ≥ 18 px, tùy chọn ×1.25 | Cài đặt; `fs()` đặt sàn 18 px | Đạt (kiểm bằng tay) |
| 5. Clone sạch, tối đa 3 lệnh để chơi; README đủ mục; CHANGELOG 4 phase; CREDITS; LICENSE | `run.sh` tự tải Godot 4.7.2 (macOS/Linux) | Đạt; chưa thử trên máy macOS/Linux thật |
| 5. Release v1.0.0 có bản chạy được | Bản Windows (Godot + game), mã nguồn + `run.sh`, Docker headless | Bản chạy được nằm trên trang Release |
| 6. Contract v1.3, `bench_cmd`, `soak_cmd` | `game.contract.json`; `test_contract_fields` | Đạt |
| 7. Retro, video demo | [docs/notes/retro.md](../../notes/retro.md), [docs/demo/](../../demo/) | Retro đạt; video do người làm quay |
