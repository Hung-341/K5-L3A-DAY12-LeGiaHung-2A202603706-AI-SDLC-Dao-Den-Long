# Phase 3 (Ticket-03 "Đèn cạn dầu"): ghi chép

## Giả định (chỗ Ticket-03 chưa nói)
| Chỗ mơ hồ | Giả định |
|---|---|
| "đi về đèn tắt gần nhất như trước" | Ticket-02 chưa định nghĩa hành vi này. Khi không có đèn yếu, Bóng Mực `wander` giữ cách lang thang cũ (theo các điểm sinh đom đóm) |
| Bóng `drain` có gây hit không | Không. Chỉ `wander` và `chase` gây hit. Bóng `drain` đứng yên; khi Mây vào trong 6 m, nó chuyển `chase` ở bước 8 và chỉ gây hit từ lúc đó |
| Số khóa điểm trong `tuning.score` | Thêm `per_relight`, `per_stun_drain`, `per_lit_at_dawn`; `per_second_left = 0` (bỏ thưởng thời gian) |
| `fuel_drain.fuel` | Là dầu còn lại của đèn sau khi trừ ở tick đó, làm tròn 1 chữ số thập phân |
| Scenario `fuel` khi `lit: false` | Giá trị bị bỏ qua, vì đèn tắt luôn có `fuel = 0` |
| `capacity` khi đang mang vượt sức chứa (scenario) | Mây không bị ép bỏ đom đóm, chỉ không nhặt thêm |

## Test bị thay (không bỏ qua âm thầm)
- `test_win` bị **xóa**, vì luật thắng sớm `all_lit` đã bị thay. Lý do được ghi ngay tại chỗ trong `tests/run_tests.py`.
- `test_contract_fields`, `test_deposit_lit`, `test_pause` được **sửa** theo bộ khóa điểm mới, trường `relight` và thời lượng 240 s.

## Nhật ký AI, lỗi, token
- **Lỗi AI 1:** đoạn chặn Bóng Mực ở mép vùng an toàn vẫn kiểm `lit` thay vì `_safe(L)`, nên đèn dưới 30 dầu vẫn chặn bóng. `test_low_fuel_loses_safe_zone` bắt được lỗi này. AI đã sửa và ghi vào ADR (mục 3).
- **Lỗi AI 2:** hai lần script heredoc bị bash cắt sai quote, nên không có thay đổi nào được áp. Lỗi được phát hiện nhờ thông báo lỗi cú pháp của bash. AI đã chuyển sang ghi script ra file rồi chạy, và cách này ổn định hơn.
- **Token Phase 3:** ước tính khoảng 150k. Token được tiết kiệm bằng cách viết test trước (14 test), vá `sim.gd` một lần bằng script và chỉ đọc các dòng FAIL trong output.

## Đánh giá nhanh
- Đạt: bộ test đạt 69/69. Toàn bộ yêu cầu 1–7 có test hoặc ảnh. ADR và CHANGELOG đã có.
- Chưa kiểm kỹ: chế độ mù màu của GUI mới được chụp một ảnh và chưa được chơi trọn một Đêm. Thanh dầu bị cắt trong ảnh do góc camera; Phase 4 sẽ chỉnh camera.
