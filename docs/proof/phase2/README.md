# Bằng chứng Phase 2 (Contract v1.1)

Chạy lại: `python3 tests/run_tests.py` → [run_tests.txt](run_tests.txt) (52/52 đạt ở tag `phase-2`, gồm toàn bộ test Phase 1).
Bảng acceptance criteria đầy đủ cho từng tính năng: [docs/notes/phase2.md](../../notes/phase2.md).

| Yêu cầu Ticket-02 | Kiểm chứng | Kết quả |
|---|---|---|
| Số liệu chuẩn (Phần 1) | `game.contract.json` + toàn bộ test đọc số từ contract | Đạt |
| Thứ tự 12 bước, tạm dừng | `test_pause`; `Sim.step()` ghi chú từng bước | Đạt |
| Bản đồ chuẩn Đêm 1/2/3 | `test_v11_snapshot_fields`, `test_bridge_and_gap_night2`, `test_pad_night2`, `test_night3_cliff_and_ramp`, `test_night3_pad_to_tier2`; ảnh [night1](night1.png), [night2](night2.png), [night3](night3.png) | Đạt |
| Lướt, nhảy | `test_dash`, `test_dash_air_keeps_height`, `test_jump` | Đạt |
| Rơi khỏi đảo, bị đánh, recoil | `test_fall_respawn`, `test_dropped_motes_pickable`, `test_recoil` | Đạt |
| Tỏa Sáng 3D | `test_pulse_3d_edge`, `test_pulse` | Đạt |
| Vùng an toàn đẩy 30 tick | `test_safe_push_on_lit`, `test_safe` | Đạt |
| Gió Lạc | `test_drifter_steal`, `test_drifter_idle_when_poor`, `test_drifter_drop_on_pulse`, `test_drifter_spawn` | Đạt |
| Bùa Gió | `test_charm`, `test_charm_dash_no_cd` | Đạt |
| Gió mạnh Đêm 3 | `test_wind` | Đạt (báo trước bằng chữ trên HUD và âm thanh, chưa có hạt lá) |
| Snapshot/scenario/event v1.1, `--night 1..3` | `test_v11_snapshot_fields`, `test_night_bad` | Đạt |
| Một Đêm 21.600 tick ≤ 30 s | `test_full_night_perf` (Windows); Docker Đêm 3 chạy 2 lần, `cmp` giống hệt | Đạt |
| Chuỗi 3 Đêm, Menu, Ông Đăng, Bình Minh, chơi lại | GUI (`scripts/view.gd`) | Đạt (kiểm bằng tay) |
| Tạm dừng Esc/P, Cài đặt lưu | GUI, `user://settings.cfg` | Đạt (kiểm bằng tay) |
| Âm thanh (nhạc + 10 hiệu ứng) | `scripts/sfx.gd` | Đạt (kiểm bằng tay) |
| HUD đầy đủ, bảng màu, ánh sáng môi trường | ảnh night1..3 | Đạt |
| ≥ 30 FPS ở 1280×720 | Chạy tự động 420 frame mỗi Đêm: **109.7 / 109.2 / 106.2 FPS** trung bình | Đạt |

Máy đo: Windows 11, Godot 4.7.2 (Forward+). Lệnh đo FPS: `DDL_NIGHT=n DDL_AUTOPLAY=1 DDL_SHOT_FRAMES=420 DDL_SHOT=... godot --path . --resolution 1280x720` (in `avg_fps=`).
