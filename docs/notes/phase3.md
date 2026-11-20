# Phase 3 (Ticket-03 "Đèn cạn dầu"): ghi chép

## Giả định (chỗ Ticket-03 chưa nói)
| Chỗ mơ hồ | Giả định |
|---|---|
| "đi về đèn tắt gần nhất như trước" | Ticket-02 chưa định nghĩa hành vi này. Khi không có đèn yếu, Bóng Mực `wander` giữ cách lang thang cũ (theo các điểm sinh đom đóm) |
| Bóng `drain` có gây hit không | Không. Chỉ `wander` và `chase` gây hit. Bóng `drain` đứng yên; khi Mây vào trong 6 m thì nó chuyển `chase` ở bước 8 và chỉ gây hit từ đó |
| Số khóa điểm trong `tuning.score` | Thêm `per_relight`, `per_stun_drain`, `per_lit_at_dawn`; `per_second_left = 0` (bỏ thưởng thời gian) |
| `fuel_drain.fuel` | Dầu còn lại của đèn sau khi trừ ở tick đó, 1 chữ số thập phân |
| Scenario `fuel` khi `lit: false` | Bỏ qua, đèn tắt luôn có `fuel = 0` |
| `capacity` khi đang mang vượt sức chứa (scenario) | Không ép bỏ đom đóm, chỉ không nhặt thêm |

## Test bị thay (không bỏ qua âm thầm)
- `test_win`: **xóa**, vì luật thắng sớm `all_lit` đã bị thay. Lý do ghi ngay tại chỗ trong `tests/run_tests.py`.
- `test_contract_fields`, `test_deposit_lit`, `test_pause`: **sửa** theo bộ khóa điểm mới, trường `relight` và thời lượng 240 s.

## Nhật ký AI, lỗi, token
- **Lỗi AI 1:** đoạn chặn Bóng Mực ở mép vùng an toàn vẫn kiểm `lit` thay vì `_safe(L)`, nên đèn dưới 30 dầu vẫn chặn bóng. `test_low_fuel_loses_safe_zone` bắt được. Đã sửa và ghi vào ADR (mục 3).
- **Lỗi AI 2:** hai lần script heredoc bị bash cắt sai quote, nên không có thay đổi nào được áp. Phát hiện nhờ lỗi cú pháp của bash. Đã đổi sang ghi script ra file rồi chạy; đây là cách ổn định hơn.
- **Token Phase 3:** ước tính khoảng 150k. Tiết kiệm bằng cách viết test trước (14 test) rồi vá `sim.gd` một lần bằng script, đọc output chỉ ở dòng FAIL.

## Đánh giá nhanh
- Đạt: 69/69 test. Toàn bộ yêu cầu 1–7 có test hoặc ảnh. ADR và CHANGELOG đã có.
- Chưa kiểm kỹ: GUI chế độ mù màu mới chụp một ảnh, chưa chơi trọn một Đêm. Thanh dầu bị cắt trong ảnh do góc camera; Phase 4 sẽ chỉnh camera.
