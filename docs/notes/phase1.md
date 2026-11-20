# Phase 1: ghi chép

## Giả định (chỗ PRD-0 mơ hồ)

| Chỗ mơ hồ | Giả định | Lý do |
|---|---|---|
| Các con số tuning | Dùng số chuẩn của Ticket-02 ngay từ Phase 1 | Ticket-02 yêu cầu test ẩn Phase 1 vẫn đạt với số chuẩn, nên luật chuẩn tương thích với contract v1.0; cách này tránh làm lại ở Phase 2 |
| "Mất máu" | `flames` = 3 Ngọn Lửa, mỗi lần chạm −1 | Scenario mẫu của contract dùng `flames: 3`. Ban đầu AI chọn 100 (thanh Tỉnh táo) và đã đổi sau khi đối chiếu |
| "Tỏa sáng tốn ánh sáng" | Trừ 3 đom đóm đang mang; nếu thiếu thì không kích hoạt | Ánh sáng chính là đom đóm; luật này tạo lựa chọn giữa tự vệ và thắp đèn |
| Tỏa sáng khi không có Bóng Mực trong tầm | Vẫn kích hoạt, trừ đom đóm, ghi event `pulse` với `stunned_ids: []` | Ticket-02 chỉ chặn khi thiếu đom đóm |
| `per_mote` | Cộng khi **nạp** vào đèn, không cộng khi nhặt | Ticket-02 ghi "+10 mỗi đom đóm nạp" |
| Rơi khỏi đảo | `fall_enabled: true`, đảo r40, rơi khi Y < −10, event `player_hit` `by: "fall"` | Theo bản đồ chuẩn Đêm 1 |
| Vùng an toàn | Chỉ có quanh đèn **đã thắp** | "Bóng Mực sợ đèn" + Ticket-02 |
| Trạng thái Bóng Mực mới sinh | `spawning` 30 tick, vô hại | Người chơi được báo trước; tên trạng thái theo v1.1 |
| `random_motes: false` mà không có `motes` | Không có đom đóm nào | "chỉ có những con được liệt kê" |
| `move` có thành phần ngoài [−1, 1] | Sai định dạng, thoát mã 2 | Contract ghi "mỗi thành phần trong [−1, 1]" |
| Khoảng cách Tỏa Sáng | Đo theo **XZ** (≤ r) kèm chênh cao ≤ 1.5 m | Contract v1.0 mục B quy định mọi khoảng cách tuning đo theo XZ. Ticket-02 đổi sang 3D, nên luật này sẽ đổi ở Phase 2 |
| Tỏa Sáng trúng Bóng Mực đang `spawning` | Bóng Mực bị choáng và người chơi được cộng điểm | Ticket-02: "mỗi con mỗi lần, kể cả con đang choáng" |
| Event `dash` | Có ghi ra output | Contract cho phép `dash` "nếu có"; tên event theo v1.1 |

## Quyết định kiến trúc
- Toàn bộ luật nằm trong `Sim.step()` theo thứ tự 12 bước, và node Godot chỉ dùng để vẽ. Lý do là output phải giống hệt từng byte và Phase 2 có địa hình nhiều tầng.
- Headless chạy hết N bước trong một vòng lặp và không phụ thuộc frame, nên chạy nhanh: 21.600 tick mất khoảng 1.5 s trong Docker.
- Code dùng `preload` thay cho `class_name`, để chạy được cả khi project chưa được import.

## Nhật ký dùng AI
| Bước | Công cụ | Ghi chú |
|---|---|---|
| Đọc đề, brainstorm, thiết kế ngắn, plan | Claude Code (Opus) | Agent chính hỏi đáp nhiều vòng để chốt cơ chế và phong cách |
| Đối chiếu thiết kế với PRD-0 và Ticket-02 | 2 subagent Sonnet chạy song song | Hai subagent phát hiện `flames` = 100 sai và thiếu `headless.sh`, dẫn tới việc chuẩn hóa số |
| Viết lõi, test, Docker, GUI | Claude Code (Opus) | Agent chính làm theo plan `docs/superpowers/plans/2026-11-20-phase1.md` |

**Lỗi của AI và cách phát hiện**
- Test `pickup` vẫn dùng bán kính cũ 1.2 m sau khi đổi sang số chuẩn. Bộ test bắt được lỗi này. AI đã sửa test thành `T["pickup_radius"]` để không còn gắn cứng số.
- Một biến trong GUI (`focus`) không suy được kiểu, nên lần chạy GUI đầu tiên bị lỗi parse. Lỗi được phát hiện khi chạy chụp ảnh `DDL_SHOT`.
- Lệnh `git mv README.md` chạy sau khi README mới đã được ghi, khiến hai file bị đảo. Lỗi được phát hiện ngay bằng `head`, và hai file đã được khôi phục từ git.

- Reviewer độc lập (Opus) tìm ra 1 lỗi Critical: Tỏa Sáng đo 3D, sai với contract v1.0 (XZ). Reviewer cũng tìm ra 2 lỗi Important: scenario có `deposited` lớn hơn chi phí đèn khiến lượng nạp bị âm, và file output trong Docker thuộc root. Sau đó reviewer tìm thêm 1 lỗi Minor: sai số float làm lần chạm trễ 1 tick. Mỗi lỗi có test hồi quy đỏ trước, xanh sau (`test_pulse_xz_edge`, `test_deposit_overfull_scenario`, `test_chase_exact_tick`); bộ test đạt 29/29.

**Token:** Phase 1 dùng ước tính khoảng 400–500k token, phần lớn cho việc đọc tài liệu và hai subagent kiểm tra (mỗi subagent khoảng 115k). Token được tiết kiệm bằng cách gom các bước sửa test vào một script, chạy test theo tên thay vì cả bộ, và đọc ảnh bằng chứng thay vì mô tả dài.

## Đánh giá nhanh
- Đạt: headless chạy theo contract và tất định (cả trên Windows lẫn trong Docker), input sai định dạng trả mã thoát 2, GUI chơi được từ đầu tới thắng hoặc thua và chơi lại được bằng phím R.
- Chưa kiểm: bản GUI chưa được chạy trực tiếp trên macOS/Linux, vì mới chạy trên Windows; headless trong Docker đã chạy được. Game chưa có âm thanh.
- Harness gồm AGENTS.md, hook Stop chặn kết thúc khi test đỏ, và CI GitHub Actions.
