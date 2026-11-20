# Phase 1: ghi chép

## Giả định (chỗ PRD-0 mơ hồ)

| Chỗ mơ hồ | Giả định | Lý do |
|---|---|---|
| Các con số tuning | Dùng số chuẩn của Ticket-02 ngay từ Phase 1 | Ticket-02 yêu cầu test ẩn Phase 1 vẫn đạt với số chuẩn, nên luật chuẩn tương thích với contract v1.0; tránh làm lại ở Phase 2 |
| "Mất máu" | `flames` = 3 Ngọn Lửa, mỗi lần chạm −1 | Scenario mẫu của contract dùng `flames: 3`. Ban đầu chọn 100 (thanh Tỉnh táo), đã đổi sau khi đối chiếu |
| "Tỏa sáng tốn ánh sáng" | Trừ 3 đom đóm đang mang; thiếu thì không kích hoạt | Ánh sáng = đom đóm; tạo lựa chọn giữa tự vệ và thắp đèn |
| Tỏa sáng khi không có Bóng Mực trong tầm | Vẫn kích hoạt, trừ đom đóm, event `pulse` với `stunned_ids: []` | Ticket-02 chỉ chặn khi thiếu đom đóm |
| `per_mote` | Cộng khi **nạp** vào đèn, không cộng khi nhặt | Theo Ticket-02 "+10 mỗi đom đóm nạp" |
| Rơi khỏi đảo | `fall_enabled: true`, đảo r40, rơi khi Y < −10, event `player_hit` `by: "fall"` | Theo bản đồ chuẩn Đêm 1 |
| Vùng an toàn | Chỉ quanh đèn **đã thắp** | "Bóng Mực sợ đèn" + Ticket-02 |
| Trạng thái Bóng Mực mới sinh | `spawning` 30 tick, vô hại | Báo trước cho người chơi; tên trạng thái theo v1.1 |
| `random_motes: false` mà không có `motes` | Không có đom đóm nào | "chỉ có những con được liệt kê" |
| `move` có thành phần ngoài [−1, 1] | Sai định dạng, thoát mã 2 | Contract ghi "mỗi thành phần trong [−1, 1]" |

## Quyết định kiến trúc
- Toàn bộ luật nằm trong `Sim.step()` theo thứ tự 12 bước. Node Godot chỉ để vẽ. Lý do: output phải giống hệt từng byte và Phase 2 có địa hình nhiều tầng.
- Headless chạy hết N bước trong một vòng lặp, không phụ thuộc frame, nên nhanh: 21.600 tick mất khoảng 1.5 s trong Docker.
- Không dùng `class_name` mà dùng `preload`, để chạy được cả khi chưa import project.

## Nhật ký dùng AI
| Bước | Công cụ | Ghi chú |
|---|---|---|
| Đọc đề, brainstorm, thiết kế ngắn, plan | Claude Code (Opus) | Hỏi đáp nhiều vòng để chốt cơ chế và phong cách |
| Đối chiếu thiết kế với PRD-0 và Ticket-02 | 2 subagent Sonnet chạy song song | Phát hiện `flames` = 100 sai và thiếu `headless.sh`, dẫn tới việc chuẩn hóa số |
| Viết lõi, test, Docker, GUI | Claude Code (Opus) | Theo plan `docs/superpowers/plans/2026-11-20-phase1.md` |

**Lỗi của AI và cách phát hiện**
- Test `pickup` vẫn dùng bán kính cũ 1.2 m sau khi đổi sang số chuẩn. Bộ test bắt được. Đã sửa test thành `T["pickup_radius"]` để không còn gắn cứng.
- Một biến trong GUI không suy được kiểu (`focus`), nên lần chạy GUI đầu bị lỗi parse. Phát hiện bằng cách chạy chụp ảnh `DDL_SHOT`.
- Lệnh `git mv README.md` chạy sau khi đã ghi README mới, khiến hai file bị đảo. Phát hiện ngay bằng `head` và đã khôi phục từ git.

**Token:** ước tính khoảng 400–500k token cho Phase 1, phần lớn là đọc tài liệu và hai subagent kiểm tra (mỗi agent khoảng 115k). Đã tiết kiệm bằng cách gom các bước sửa test vào một script, chạy test theo tên thay vì cả bộ, và đọc ảnh bằng chứng thay vì mô tả dài.

## Đánh giá nhanh
- Đạt: headless theo contract, tất định (cả trên Windows lẫn trong Docker), mã thoát 2, GUI chơi được từ đầu tới thắng/thua, chơi lại bằng R.
- Chưa kiểm: bản GUI chạy trực tiếp trên macOS/Linux, vì mới chạy trên Windows; headless trong Docker đã chạy được. Âm thanh chưa có.
- Harness: AGENTS.md, hook Stop chặn kết thúc khi test đỏ, CI GitHub Actions.
