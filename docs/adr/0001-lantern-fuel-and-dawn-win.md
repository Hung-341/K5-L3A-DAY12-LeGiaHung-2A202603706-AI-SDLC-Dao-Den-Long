# ADR 0001: Đèn có nhiên liệu và luật thắng "giữ sáng tới bình minh"

- Trạng thái: Đã chấp nhận (Phase 3, Ticket-03, Contract v1.2)
- Thay thế: luật "đèn đã sáng không nhận thêm đom đóm", "Bóng Mực không bao giờ vào vùng an toàn", "thắng ngay khi tất cả đèn sáng" của Ticket-02.

## Bối cảnh
Ở Phase 1–2, đèn chỉ có hai trạng thái và chỉ đi một chiều: tắt rồi sáng. Thắp xong là xong. Người chơi giỏi thắp hết đèn trong khoảng 2 phút và game kết thúc sớm. Ticket-03 muốn cuối Đêm phải căng thẳng: đèn có thể tắt trở lại, và mục tiêu là giữ đảo sáng tới bình minh.

## Quyết định
1. **Mô hình trạng thái đèn** chuyển từ `{lit, deposited}` thành `{lit, deposited, fuel, ever_lit, relit_count}`:

   ```
   tắt (ever_lit=false) --nạp đủ 10--> sáng (fuel=100) --hao/bị hút về 0--> tắt (ever_lit=true, deposited=0)
   tắt (ever_lit=true)  --nạp đủ 5---> sáng (fuel=100, relit_count+1)
   sáng (fuel<100)      --châm dầu---> sáng (fuel += 10 × used)
   ```

2. **Dầu lưu bằng số nguyên** theo đơn vị 1/60 (`FU = 60`, đầy = 6000). Hao 1/s tương ứng −1 mỗi tick; mỗi Bóng Mực hút 5/s tương ứng −5 mỗi tick. Chỉ làm tròn khi ghi output (1 chữ số thập phân). Lý do: tránh sai số số thực cộng dồn qua 18.000 tick. Phase 1–2 đã gặp lỗi kiểu này ở mép bán kính.
3. **Vùng an toàn** trở thành hàm `_safe(L) = lit và fuel ≥ 30`, thay cho `lit`. Mọi chỗ trước đây kiểm `lit` (chặn ở mép, đẩy ra, chạm) đều đi qua hàm này. Phase 3 có một test bắt được chỗ chặn ở mép còn sót kiểm `lit` (`test_low_fuel_loses_safe_zone`).
4. **Bóng Mực thêm trạng thái `drain`** vào FSM: `wander → drain` khi cách đèn yếu ≤ 2 m. Từ `drain` sang `chase` nếu Mây trong 6 m, sang `stunned` nếu trúng Tỏa Sáng, sang `wander` nếu đèn tắt, được châm lên ≥ 30 hoặc bóng cách đèn > 2 m. Bóng đang `chase` không đổi mục tiêu.
5. **Thứ tự trong tick:** việc trừ dầu đặt ở bước 2 (bộ đếm), và ngay sau đó đèn hết dầu thì tắt. Xét thắng/thua là bước cuối của tick, kể cả tick bình minh; hết Ngọn Lửa luôn thua trước.
6. **Luật thắng** không còn thắng sớm. Ở tick `time_left ≤ 0`: còn Ngọn Lửa và số đèn sáng ≥ `ceil(win_ratio × tổng)` thì `won/dawn_survived`, ngược lại `lost/dawn`. Thưởng bình minh: mỗi đèn sáng +50 + floor(fuel), mỗi Ngọn Lửa +50.

## Hệ quả
- Điểm và số liệu đọc từ `game.contract.json` (v1.2), không viết cứng trong code.
- Test bị luật mới thay: `test_win` (thắng sớm `all_lit`) bị **xóa**, thay bằng `test_no_early_win`, `test_dawn_survived`, `test_dawn_lost_below_ratio`, `test_night_thresholds`. `test_contract_fields`, `test_deposit_lit` (thêm `relight`) và `test_pause` (thời lượng 240 s) được **sửa**. Lý do ghi ngay trong test.
- GUI: thanh dầu trên đèn, nhấp nháy 1 Hz khi dầu < 30. Đèn tắt xẹp 20% và có vết rách, để phân biệt mà không cần màu.
- Rủi ro: Bóng Mực chỉ chọn đèn yếu khi đang `wander`. Đèn tắt thì bóng lang thang như trước, không cố ý đi tới đèn tắt, vì Ticket-02 chưa định nghĩa hành vi "đi về đèn tắt".
