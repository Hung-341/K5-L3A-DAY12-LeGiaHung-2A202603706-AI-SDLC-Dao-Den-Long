# Bằng chứng Phase 3 (Contract v1.2)

Lệnh chạy lại: `python3 tests/run_tests.py` → [run_tests.txt](run_tests.txt) (đạt 69/69 ở tag `phase-3`). Bộ test gồm các test Phase 1–2 còn hiệu lực và 14 test mới. Sau tag, các sửa Minor của reviewer (commit `5e2edc5`) thêm 2 test và nâng bộ test lên 71/71.
Quyết định thiết kế: [ADR 0001](../../adr/0001-lantern-fuel-and-dawn-win.md) · Breaking changes: [CHANGELOG.md](../../../CHANGELOG.md).

| Yêu cầu Ticket-03 | Kiểm chứng | Kết quả |
|---|---|---|
| 1. Dầu: tối đa 100, hao 1/s, thắp xong = 100 | `test_fuel_decay_and_snapshot` | Đạt |
| 1. Hết dầu: tắt, deposited = 0, `lantern_out`, ever_lit | `test_lantern_out` | Đạt |
| 1. Châm dầu `used = min(mang, ceil((100−fuel)/10))`, event `refuel` | `test_refuel` | Đạt |
| 1. Đèn đầy dầu không được chọn khi tương tác | `test_full_lantern_not_selected` | Đạt |
| 1. Thắp lại cần 5, +40 điểm, `relight: true` | `test_relight` | Đạt |
| 2. Dầu < 30 thì mất vùng an toàn (đúng 30 vẫn còn) | `test_low_fuel_loses_safe_zone` | Đạt |
| 2. `drain`: đứng yên, hút 5/s cộng dồn với hao 1/s, event `fuel_drain` mỗi 60 tick | `test_drain` | Đạt |
| 2. drain → chase khi Mây trong 6 m; Tỏa Sáng trúng bóng đang drain được +15 | `test_drain_to_chase_and_pulse_bonus` | Đạt |
| 2. Châm lên ≥ 30 thì bóng bị đẩy ra mép trong ≤ 30 tick và vô hại | `test_refuel_pushes_shades_out` | Đạt |
| 3. Không thắng sớm | `test_no_early_win` | Đạt |
| 3. Thắng `dawn_survived` + điểm bình minh; thua `dawn` khi dưới ngưỡng | `test_dawn_survived`, `test_dawn_lost_below_ratio` | Đạt |
| 3. Ngưỡng Đêm 2 = 4/6, Đêm 3 = 5/7; thời lượng 240/270/300 s | `test_night_thresholds`, `test_contract_fields` | Đạt |
| 4. Sức chứa 10 + 2 × lần thắp, tối đa 20; đèn đặt sẵn không tính | `test_capacity_grows` | Đạt |
| 5. Điểm mới | `test_refuel`, `test_relight`, `test_dawn_survived`, `test_drain_to_chase_and_pulse_bonus`, `test_deposit_lit` | Đạt |
| 6. Chế độ mù màu (được lưu), viền `#00B3FF`, cảnh báo trắng + ⚠ | `scripts/view.gd` (`rim()`, `danger()`, ConfigFile `display/colorblind`); ảnh [colorblind.png](colorblind.png) | Đạt (kiểm bằng tay) |
| 6. Đèn tắt xẹp 20% + vết rách; đèn sắp hết dầu nhấp nháy 1 Hz | `scripts/view.gd`; ảnh [fuel.png](fuel.png) | Đạt (kiểm bằng tay; trong ảnh, thanh dầu bị cắt ở mép trên vì góc camera) |
| HUD đang mang / sức chứa, số đèn cần giữ | ảnh [fuel.png](fuel.png): "Đèn sáng 2/5 (cần 3)", "0/10" | Đạt |
| Test Phase 1–2 không bị thay vẫn đạt | run_tests.txt | Đạt |

Ảnh được chụp bằng `DDL_DEMO=1` (hoặc `cb`). Chế độ này dựng sẵn L1 đầy dầu 80, L2 sắp cạn 20 và L5 đã tắt (`ever_lit`) qua chính `Sim.apply_scenario` mà headless dùng.
