# Bằng chứng Phase 1

Chạy lại: `python3 tests/run_tests.py` → [run_tests.txt](run_tests.txt) (29/29 đạt ở tag `phase-1`).

| Yêu cầu (PRD-0 / Contract v1.0) | Cách kiểm chứng | Bằng chứng | Kết quả |
|---|---|---|---|
| Đi lại theo `move` và `cam_yaw_deg`, tốc độ đúng `player_speed` | `test_speed`, `test_normalize`, `test_yaw90` | run_tests.txt | Đạt |
| Nhảy | GUI (Space) | Chơi tay | Đạt (chưa có test headless riêng) |
| Camera 3D góc nhìn thứ ba | GUI | [gui-hud.png](gui-hud.png) | Đạt |
| Đom đóm rải rác, nhặt tự động ≤ r, sức chứa | `test_pickup`, `test_capacity`, `test_default_level` | run_tests.txt | Đạt |
| Nạp ánh sáng thắp đèn | `test_deposit_lit`, `test_partial`, `test_deposit_out_of_range` | run_tests.txt | Đạt |
| Bóng Mực xuất hiện và đuổi | `test_spawn`, `test_no_flames` | run_tests.txt | Đạt |
| Tỏa sáng xua Bóng Mực, tốn ánh sáng, hồi chiêu | `test_pulse`, `test_pulse_xz_edge`, `test_pulse_cd`, `test_pulse_poor` | run_tests.txt | Đạt |
| Bị chạm mất máu, bất tử, rơi đom đóm | `test_hit` | run_tests.txt | Đạt |
| Bóng Mực sợ đèn (vùng an toàn) | `test_safe` | run_tests.txt | Đạt |
| Thắng / thua (`all_lit`, `dawn`, `no_flames`), điểm | `test_win`, `test_dawn`, `test_no_flames` | run_tests.txt | Đạt |
| HUD | GUI | [gui-hud.png](gui-hud.png) | Đạt |
| Chơi lại sau thắng/thua | GUI (R) | Chơi tay | Đạt |
| Scenario không phát event và không cộng điểm | `test_prelit_no_score`, `test_scenario_player` | run_tests.txt | Đạt |
| Sai định dạng → mã 2 | `test_bad_json`, `test_bad_tick_order`, `test_bad_move`, `test_bad_scenario` | run_tests.txt | Đạt |
| Tất định | `test_determinism`; chạy Docker 2 lần + `cmp` | run_tests.txt; mục dưới | Đạt |
| Chạy trên macOS/Linux | Docker image + `headless.sh` | mục dưới | Đạt cho headless; GUI cần Godot cài sẵn |

## Headless qua Docker (giống máy chấm)

```
$ ./headless.sh --seed 9 --night 1 --inputs in.json --ticks 21600 --out full.jsonl   # đi thẳng +Z
real 0m1.458s, exit=0
{"type":"end","ticks":1500,"state":"lost","score":0}     # rơi khỏi đảo 3 lần → no_flames
$ (chạy lại ra full2.jsonl) && cmp full.jsonl full2.jsonl → DETERMINISTIC-DOCKER
$ ./headless.sh ... --inputs bad.json (tick giảm) → "inputs: tick phải tăng nghiêm ngặt và >= 0", exit=2
```
Máy: Windows 11, Docker Desktop, image `ubuntu:24.04` + Godot 4.7.2 Linux.
