# Retro: Đảo Đèn Lồng (Day 12 · AI SDLC)

## 1. Tổng hợp 4 phase
| Phase | Yêu cầu chính | Kết quả | Có hỏng phase trước không | Test cuối phase |
|---|---|---|---|---|
| 1 (PRD-0, v1.0) | Đêm 1, headless, contract | Đạt. Số liệu chuẩn của Ticket-02 được áp dụng sớm | — | 29/29 |
| 2 (Ticket-02, v1.1) | 3 Đêm, số liệu và bản đồ chuẩn, Gió Lạc, Bùa, gió, tạm dừng, âm thanh, HUD | Đạt | Không; 1 test Phase 1 được thay có lý do (Tỏa Sáng đo 3D) | 56/56 |
| 3 (Ticket-03, v1.2) | Dầu đèn, `drain`, thắng `dawn_survived`, điểm mới, mù màu | Đạt; có ADR và CHANGELOG | Không; `test_win` bị xóa có lý do, 3 test được sửa | 69/69 ở tag; 71/71 sau sửa Minor |
| 4 (Ticket-04, v1.3) | Bench, soak, bảng xếp hạng, dễ tiếp cận, đóng gói | Đạt trên máy tự đo (avg 135.9 FPS, p1_low 43.0, soak 0 crash) | Không | 78/78 |

Về quy mô, repo có 25 commit tính từ đầu lab tới tag phase-4 và khoảng 3.600 dòng GDScript và Python test. Bộ 78 scenario test headless chạy bằng một lệnh, và CI chạy bộ test này mỗi lần push.

## 2. Điều hiệu quả khi làm với AI
- **Đọc trước ticket của phase sau rồi chuẩn hóa sớm.** Phase 1 đã dùng số liệu chuẩn, bản đồ chuẩn và thứ tự xử lý 12 bước của Ticket-02, nên Phase 2 gần như không phải viết lại phần lõi.
- **Tách luật khỏi hiển thị:** toàn bộ luật nằm trong `Sim.step()`, còn node Godot chỉ dùng để vẽ. Nhờ vậy headless tất định từng byte, chạy nhanh (một Đêm 21.600 tick mất khoảng 1.5 s), và phần sáng tạo không đụng tới output contract.
- **Viết test trước, sửa sau:** mỗi lỗi đều có một test đỏ trước rồi mới xanh. Cách này chứng minh được lỗi có thật và đã được sửa.
- **Reviewer độc lập sau mỗi phase** (do một agent khác với agent đã viết code thực hiện). Reviewer tìm được 1 lỗi Critical và 6 lỗi Important mà agent viết code bỏ sót.
- **Chạy song song hai subagent đối chiếu PRD-0 và Ticket-02** trước khi code. Việc này phát hiện `flames = 100` sai và thiếu `headless.sh` trước khi tốn công viết code.

## 3. Điều không hiệu quả
- Việc vá code bằng heredoc trong bash thất bại 2 lần ở Phase 3 vì bash cắt sai dấu quote, nên thay đổi không được áp. AI đã chuyển sang ghi script vá ra file rồi chạy.
- GDScript không suy được kiểu khi giá trị lấy từ biến không khai kiểu (`sim.*`, `max()`). Lỗi kiểu này lặp lại 4 lần và chỉ lộ ra khi chạy GUI.
- Khi laptop chạy pin, số đo FPS bị khóa ở 30, và điều này suýt dẫn tới chẩn đoán sai.

## 4. Những lần AI sai và cách phát hiện
| Lỗi | Phát hiện bằng | Chỉnh harness |
|---|---|---|
| AI chọn `flames = 100` (theo ý tưởng "thanh Tỉnh táo") trong khi contract mẫu dùng 3 | Subagent đối chiếu PRD-0 | Ghi vào AGENTS.md rằng số liệu lấy từ contract |
| Tỏa Sáng đo 3D ở Phase 1, trái với contract v1.0 (XZ) | Reviewer độc lập | Test biên `test_pulse_xz_edge` (sau đó được thay bằng bản 3D ở Phase 2) |
| Phép so ở mép vùng an toàn bị sai số float; bóng vẫn chạy AI đuổi trong lúc bị đẩy | `test_safe_push_on_lit` | Quy tắc "so bán kính luôn có EPS" trong AGENTS.md |
| Chỗ chặn ở mép vẫn kiểm `lit` sau khi luật đổi sang "dầu ≥ 30" | `test_low_fuel_loses_safe_zone` | Mọi kiểm tra vùng an toàn đi qua `_safe(L)` (ADR 0001) |
| Hit duyệt theo thứ tự mảng thay vì id; scenario thiếu số tick; `invuln` xuất số giây | Reviewer độc lập Phase 2 | 3 test hồi quy |
| Việc đo RAM bằng PowerShell giữa lúc bench làm giật khung hình (p1_low 5.2) | Đọc kết quả bench | Đo RAM ngoài khoảng đo trên Windows/macOS |
| HUD được gán cỡ chữ mỗi khung hình (p1_low 27.5) | Bench 30 s | Chỉ gán khi tùy chọn đổi |
| Bảng xếp hạng xuất `1200.0` thay vì `1200` | Chạy `run.sh --export-leaderboard` | Test kiểm kiểu số nguyên |
| Viền Bóng Mực che hết thân, trông như quả cầu tím, trái với bảng màu | Đọc ảnh bằng chứng bench | Viền được vẽ ở mặt sau (outline) |

## 5. Harness giúp nhiều nhất
1. **Bộ scenario test headless** (`tests/run_tests.py`) cùng **hook Stop** chặn kết thúc khi test đỏ. Hai thành phần này là lưới an toàn cho mọi thay đổi luật.
2. **Skill `verify-game`** mô tả quy trình chụp ảnh, đo FPS và chạy Docker. Ảnh chụp tự động (`DDL_SHOT`) bắt được lỗi GUI và lỗi màu mà test không thấy.
3. **AGENTS.md** ngắn và chỉ ghi lệnh cùng các quy tắc rút ra từ lỗi đã gặp (preload thay `class_name`, EPS, `_safe`).
4. **CI GitHub Actions** chạy test và Docker headless mỗi lần push.

## 6. Token và chi phí (ước tính)
| Phase | Phiên chính | Subagent | Ghi chú |
|---|---|---|---|
| 1 | ~450k | 2 agent đối chiếu (~232k) + 1 reviewer (~131k) | Phần đọc tài liệu chiếm nhiều token |
| 2 | ~280k | 1 reviewer (~141k) | |
| 3 | ~150k | 1 reviewer (~119k) | |
| 4 + đánh bóng | ~400k | 0 | |
| **Tổng** | **~1.9M token** | | Khoảng 70% nằm ở phiên chính |

Các cách tiết kiệm đã dùng:
- Viết test trước, rồi vá code một lần bằng script.
- Chỉ đọc dòng FAIL thay vì cả log.
- Dùng model rẻ hơn (Sonnet) cho việc đối chiếu yêu cầu và model mạnh (Opus) cho review.
- Không chạy agent liên tục: mỗi phase chỉ có một lượt review.

## 7. Nếu làm lại
- Viết hàm `apply_patch` đầy đủ (hoặc dùng Edit) ngay từ đầu thay vì dùng heredoc.
- Khai kiểu cho biến `sim` trong `view.gd` để lỗi lộ ra ngay khi import, không phải đợi chạy GUI.
- Dựng cảnh bench và đo FPS ngay từ Phase 2, không đợi tới Phase 4.
- Thống nhất phong cách hình ảnh với bảng màu bắt buộc sớm hơn, vì ý tưởng tím hồng ban đầu xung đột với bảng màu của Ticket-02.
