# Changelog

## [phase-3] Contract v1.2 "Đèn cạn dầu"

### Breaking changes
- **Luật thắng:** bỏ thắng sớm khi thắp hết đèn. Giờ chỉ thắng ở tick bình minh nếu còn sống và có ≥ 60% đèn đang sáng. `game_over.reason` thêm `dawn_survived`, bỏ `all_lit`.
- **Thời lượng Đêm:** 300/330/360 s đổi thành 240/270/300 s.
- **Điểm:** thay toàn bộ công thức:
  - +5 mỗi đom đóm nạp vào đèn.
  - +100 thắp lần đầu, +40 thắp lại.
  - +5 mỗi Bóng Mực trúng Tỏa Sáng, +15 nếu nó đang hút dầu.
  - Khi thắng: mỗi đèn sáng +50 + floor(fuel), mỗi Ngọn Lửa +50.
  - Bỏ thưởng thời gian.
- **Đèn có nhiên liệu:** hao 1/s, tắt khi hết dầu (`deposited` về 0). Đèn sáng nhận châm dầu. Đèn đầy dầu không được chọn khi tương tác.
- **Vùng an toàn:** đèn có dầu < 30 thì mất vùng an toàn.
- **Bóng Mực:** thêm trạng thái `drain`.
- **Sức chứa:** đổi từ 10 cố định thành `10 + 2 × số lần thắp thành công`, tối đa 20.
- **Contract output:**
  - Snapshot: mỗi đèn thêm `fuel`, `ever_lit`, `relit_count`; `player` thêm `capacity`; Bóng Mực thêm `target_lantern_id`.
  - Event mới: `refuel`, `lantern_out`, `fuel_drain`. `lantern_lit` thêm `relight`.
- **`game.contract.json`:** `contract_version` thành `1.2`. `tuning` thêm `fuel_max`, `fuel_decay_per_s`, `fuel_per_mote`, `relight_cost`, `win_ratio`, `drain_per_s`, `low_fuel_threshold`, `capacity_max`. Bộ khóa `score` cũng đổi.

### Thêm
- Scenario: đèn nhận `lit`, `fuel`, `ever_lit` (`lit: true` mà không có `fuel` thì fuel = 100); `player.successful_lights`; `shades[].target_lantern_id`; trạng thái `drain`.
- GUI:
  - Thanh dầu trên đèn, nhấp nháy 1 Hz khi dầu < 30. Đèn tắt xẹp 20% và có vết rách.
  - Dòng nhắc "E — Châm dầu".
  - HUD hiện "đang mang / sức chứa" và "Đèn sáng k/n (cần m)".
- Cài đặt "Bảng màu dễ phân biệt" (được lưu): viền và mắt Bóng Mực đổi sang `#00B3FF`, cảnh báo UI đổi sang trắng kèm ⚠.
- ADR: [docs/adr/0001-lantern-fuel-and-dawn-win.md](docs/adr/0001-lantern-fuel-and-dawn-win.md).

## [phase-2] Contract v1.1 "Ba hòn đảo"
- Số liệu và bản đồ chuẩn 3 Đêm, lướt, Gió Lạc, Bùa Gió, gió mạnh, tạm dừng.
- Tỏa Sáng đo 3D từ chân + 0.8 m, thay cho XZ của v1.0.
- Chuỗi 3 Đêm, menu, cài đặt, âm thanh, HUD đầy đủ.

## [phase-1] Contract v1.0
- Đêm 1, chế độ headless, Docker, bộ test scenario.
