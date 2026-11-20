# Kịch bản video demo (dưới 5 phút) và số liệu để trả lời

## Kịch bản quay (khoảng 4 phút 30 giây)
Cắm sạc trước khi quay, vì chạy pin sẽ khóa ở 30 FPS. Quay ở 1280×720.

| Thời điểm | Cảnh | Nói / chỉ vào |
|---|---|---|
| 0:00–0:20 | README trên GitHub, tag `phase-1..4`, Release `v1.0.0` | "Game 3D Godot 4.7.2, 4 phase, mỗi phase một tag" |
| 0:20–1:40 | `./run.sh` → Menu → Đêm 1 | Nhặt đom đóm (thanh 10 ô, đom đóm bay quanh) → E thắp đèn → thanh dầu → F Tỏa Sáng đẩy Bóng Mực → mang ≥ 4 đom đóm thì Sương Gai tới → Q Gió Đèn |
| 1:40–2:10 | Esc → Cài đặt | Đổi phím (thử trùng phím → cảnh báo), mù màu, giảm chuyển động, chữ lớn |
| 2:10–2:30 | Menu → Chọn Đêm 3 | Ba tầng, dốc, bục nhảy lên tháp chuông, gió mạnh có phụ đề |
| 2:30–3:10 | Terminal: `python3 tests/run_tests.py` | "78/78 test headless; có kiểm tất định, mã thoát 2, hiệu năng" |
| 3:10–3:40 | `./headless.sh --seed 1 --night 1 --ticks 600 --out out/a.jsonl` rồi `tail` | Dòng snapshot, event, end theo contract |
| 3:40–4:15 | `./bench.sh --seed 42 --duration 10 --out bench.json` | Camera bay vòng 200 Bóng Mực; đọc avg_fps, p1_low |
| 4:15–4:30 | `docs/proof/`, `AGENTS.md`, `.claude/` (hook, skill), `git log --oneline` | "Bằng chứng từng phase, harness AI, commit nhỏ" |

## Số liệu sẵn sàng khi được hỏi
| Câu hỏi | Trả lời | Nguồn |
|---|---|---|
| Có bao nhiêu test? Chạy thế nào? | 78 scenario headless, một lệnh `python3 tests/run_tests.py`, mất khoảng 1–2 phút | `docs/proof/phase4/run_tests.txt` |
| Tất định không? | Có. Cùng seed, scenario, inputs thì output giống từng byte, cả trên Windows và trong Docker (`cmp`) | `test_determinism`, `test_determinism_night3`, proof phase 1–2 |
| Headless nhanh cỡ nào? | Một Đêm đầy đủ 21.600 tick khoảng 1.5 s trong Docker (ngưỡng ≤ 30 s) | `test_full_night_perf` |
| Benchmark? | avg 135.9 FPS, p1_low 43.0, p95 12.23 ms, load 2.75 s, RSS 585 MB, GTX 1660 Ti, cắm sạc | `docs/proof/phase4/bench.json` |
| Soak? | 10 Đêm, 0 crash, RAM 93.7 → 93.9 MB | `docs/proof/phase4/soak.json` |
| Kiến trúc? | Mọi luật trong `scripts/sim.gd` (`step()` theo thứ tự 12 bước); `headless.gd` = CLI + JSONL; `view.gd` = vẽ; `creative.gd` = phần sáng tạo chỉ ở GUI | `AGENTS.md` |
| Vì sao không dùng physics của Godot? | Contract cần output giống từng byte và địa hình nhiều tầng có vách, dốc, bục; tự tính va chạm thì kiểm soát được và nhanh | ADR 0001, notes phase 1 |
| Xử lý thay đổi yêu cầu (Phase 3)? | ADR 0001; CHANGELOG ghi breaking changes; `test_win` xóa có lý do, 3 test sửa có lý do | `docs/adr/`, `CHANGELOG.md` |
| AI sai ở đâu? | 9 nhóm lỗi, đều có test hoặc quy tắc harness đi kèm | `docs/notes/retro.md` mục 4 |
| Token? | Khoảng 1.9M token, khoảng 70% ở phiên chính; mỗi phase một lượt reviewer độc lập | `docs/notes/retro.md` mục 6 |
| Sáng tạo có phá contract không? | Không. Sương Gai, Gió Đèn, viền tối chỉ ở GUI; headless không nạp `creative.gd`; 78/78 test vẫn đạt | README "Sáng tạo của tôi" |
| Chỗ nào chưa chắc? | Vài chỗ ticket mơ hồ đã chọn và ghi lý do (đèn vừa đầy nhận 1 đom đóm, bóng `drain` không gây hit, điểm xuất phát Đêm 3); GUI chưa thử trên macOS/Linux thật | notes phase 2–3, ADR 0001 mục 7 |
