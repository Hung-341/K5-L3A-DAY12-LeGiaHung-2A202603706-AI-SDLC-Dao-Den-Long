# Phase 2 (Ticket-02 "Ba hòn đảo"): spec, giả định, ghi chép

## Acceptance criteria (Phần 3) và test tương ứng

| Tính năng | Tiêu chí nghiệm thu ("làm A thì thấy B") | Kiểm chứng |
|---|---|---|
| Gió Lạc | Khi Mây mang ≥ 5 và cách ≤ 15 m, Gió Lạc chuyển `chase`. Khi chạm (XZ ≤ 1.2), Gió Lạc cướp min(3, đang mang), ghi event `drifter_steal` và chuyển `flee`; Mây không mất Ngọn Lửa. Khi Mây mang < 5, Gió Lạc giữ `idle` | `test_drifter_steal`, `test_drifter_idle_when_poor` |
| Gió Lạc + Tỏa Sáng | Khi bị trúng lúc `flee` và đang mang đồ, Gió Lạc thả toàn bộ thành đom đóm `dropped` và ghi event `drifter_drop` | `test_drifter_drop_on_pulse` |
| Lịch sinh Gió Lạc | Đêm 2–3 sinh D1 ở tick 1200; Đêm 1 không có Gió Lạc | `test_drifter_spawn` |
| Bùa Gió | Khi nhặt, game ghi event `charm_picked {C1, 600}`, tốc độ thành 7.2 m/s và `available=false`. Lướt không hồi chiêu nhưng người chơi vẫn phải nhấn lại | `test_charm`, `test_charm_dash_no_cd` |
| Lướt | 14 m/s trong 12 tick (2.8 m), hồi 90 tick tính từ lúc bắt đầu, trên không giữ nguyên độ cao | `test_dash`, `test_dash_air_keeps_height` |
| Chuỗi 3 Đêm | Menu → giới thiệu (tên đảo, lời Ông Đăng) → chơi → kết quả → Đêm kế. Thắng Đêm 3 thì game ra màn Bình Minh với tổng điểm; thua thì người chơi chơi lại Đêm đó | GUI, ảnh `docs/proof/phase2/` |
| Tạm dừng | Headless: input `pause` tạo event `paused`; `sim_tick`, thời gian và spawn đứng yên; snapshot có `state: "paused"`. GUI: Esc/P mở Tiếp tục / Chơi lại Đêm / Cài đặt / Về menu | `test_pause`; GUI |
| Cài đặt | Âm lượng và độ nhạy chuột được lưu vào `user://settings.cfg` và vẫn giữ khi mở lại | GUI (ConfigFile) |
| Âm thanh | Nhạc nền đêm và 10 hiệu ứng: nhặt, thắp, tỏa sáng, bị đánh, nhảy, lướt, thắng, thua, Bóng Mực xuất hiện, đếm ngược 10 s | `scripts/sfx.gd` (tổng hợp bằng code) |
| HUD | Ngọn Lửa ở trên trái, mm:ss ở trên giữa (đỏ nhấp nháy khi ≤ 30 s), đèn k/n và điểm ở trên phải, thanh đom đóm 10 ô ở dưới giữa, hồi chiêu Lướt và Tỏa Sáng ở dưới phải, dòng nhắc "E — Nạp ánh sáng (x/10)", mũi tên chỉ tới đèn chưa sáng gần nhất khi đèn ở ngoài màn hình | Ảnh `night1..3.png` |
| Bảng màu, ánh sáng môi trường | Màu đúng mã hex của bảng chuẩn; `ambient = 0.15 + 0.55 × lit/total` | `scripts/view.gd` (hằng `C`, `_process`) |
| Bản đồ chuẩn | Đêm 2: cầu đi được, lệch khỏi cầu thì rơi, bục nhảy đưa sang đảo kia. Đêm 3: vách tầng chặn, dốc dẫn lên tầng 1, bục nhảy đưa lên tầng 2. Gió mạnh nổi mỗi 30 s và được báo trước 2 s | `test_bridge_and_gap_night2`, `test_pad_night2`, `test_night3_cliff_and_ramp`, `test_night3_pad_to_tier2`, `test_wind` |
| Số liệu chuẩn / rơi / bị đánh | Khi rơi, Mây mất 1 Ngọn Lửa, mất hết đom đóm và hồi sinh sau 60 tick. Khi bị đánh, Mây rơi floor(n/2) đom đóm ra vành 1.5–2.5 m (sống 480 tick), và bóng chuyển `recoil` | `test_fall_respawn`, `test_dropped_motes_pickable`, `test_recoil`, `test_jump` |
| Vùng an toàn | Khi đèn vừa thắp, Bóng Mực bên trong bị đẩy ra mép 6 m trong ≤ 30 tick và vô hại trong lúc đó | `test_safe_push_on_lit`, `test_safe` |
| Hiệu năng | Headless chạy một Đêm 21.600 tick trong ≤ 30 s; GUI đạt ≥ 30 FPS ở 1280×720 | `test_full_night_perf`; số đo FPS ở `docs/proof/phase2/README.md` |

## Thay đổi so với Phase 1 và test bị thay
- **Tỏa Sáng đo 3D từ chân + 0.8 m** (v1.1), thay cho XZ (v1.0). Test `test_pulse_xz_edge` của Phase 1 được **thay** bằng `test_pulse_3d_edge`, vì luật cũ không còn hiệu lực.
- **Đẩy lùi diễn ra dần trong 15 tick** (Phase 1 đã làm như vậy). `test_pulse` đo ở tick 20.
- **Event `player_hit` khi rơi** được đổi thành `dropped: 0, lost: n`, vì đom đóm bị mất chứ không rơi ra đất.
- **`invuln` trong snapshot** giữ kiểu boolean như v1.0. Ticket chỉ gắn hậu tố `_s` cho `dash_cd_s`, `pulse_cd_s`, `charm_s`.
- Các luật đã chuẩn hóa từ Phase 1 (số liệu, bản đồ Đêm 1, thứ tự 12 bước) giữ nguyên, nên test Phase 1 không phải sửa.

## Giả định (chỗ Ticket-02 chưa nói)
| Chỗ mơ hồ | Giả định |
|---|---|
| Điểm xuất phát Đêm 2, 3 | Đêm 2: (0,0,0). Đêm 3: (0,0,−28) trên tầng 0, vì tâm Đêm 3 là tầng 2 có tháp chuông |
| Bóng Mực trên địa hình nhiều tầng | Bóng Mực lơ lửng cách mặt đất một khoảng cố định, mặc định 1.0 m. Nó không leo vách cao hơn 0.35 m và không ra biển mây |
| "Điểm sương ngẫu nhiên" của Gió Lạc | Điểm được chọn ngẫu nhiên trong các điểm sinh Bóng Mực của Đêm; Gió Lạc bay ở độ cao 1.5 m |
| Thời gian `spawning` | 30 tick, vô hại (giữ như Phase 1) |
| `night_start` | Event được ghi ngay sau snapshot tick 0, với `tick: 0` |
| Tương tác đèn ở tầng khác | Cần chênh cao ≤ 1.5 m (như khi nhặt và khi chạm) |
| Scenario khai `state` mà thiếu `state_ticks_left` | Trạng thái dùng đủ thời lượng của nó: stunned 120, recoil 60, spawning 30, flee 240 |
| Điểm sinh Bóng Mực nằm trong vùng an toàn của đèn đã sáng | Điểm đó được coi là không hợp lệ và bị bỏ qua |
| Trạng thái `removed` của Gió Lạc | Gió Lạc bị xóa khỏi mảng `drifters` và không xuất hiện với state `removed` |
| `pause` trong headless | Khi đang tạm dừng, các nút khác vẫn được đọc để không tạo cạnh false→true giả lúc tiếp tục |

## Nhật ký AI, lỗi, token
- Claude Code (Opus) viết toàn bộ phần này theo ticket. Mỗi tính năng có test headless trước khi viết GUI.
- **Lỗi AI 1:** khi chặn Bóng Mực ở mép vùng an toàn, phép so dùng `>= sr` chính xác tuyệt đối. Sai số float khiến bóng ở mép (5.9999) lọt vào trong. `test_safe_push_on_lit` bắt được lỗi này; AI đã sửa bằng dung sai 1e-3.
- **Lỗi AI 2:** Bóng Mực vẫn chạy AI đuổi trong lúc đang bị đẩy khỏi vùng an toàn, nên không ra kịp trong 30 tick. Cùng test đó bắt được lỗi; AI đã đóng băng AI đuổi trong lúc bóng bị đẩy.
- **Lỗi AI 3:** AI ghi đè `view.gd` khi file đã đổi trên đĩa, nên lệnh ghi bị từ chối. AI đọc lại file rồi ghi, và không có nội dung nào bị mất.
- **Reviewer độc lập (Opus) sau khi gắn tag** không tìm thấy lỗi Critical và tìm ra 3 lỗi Important:
  - Bóng Mực gây hit theo thứ tự trong mảng thay vì theo id tăng dần.
  - Scenario khai `state` mà thiếu số tick thì trạng thái kết thúc ngay.
  - `invuln` xuất số giây thay vì boolean.

  Reviewer cũng tìm ra 1 lỗi Minor: điểm sinh nằm trong vùng an toàn. Mỗi lỗi có test đỏ trước, xanh sau (`test_hit_order_by_id`, `test_scenario_state_default_duration`, `test_invuln_bool`). Lỗi "khe ở mép dốc" không tái hiện được (`test_ramp_edge_no_gap` đạt ngay) nên không được sửa. Bộ test đạt 56/56.
- **Token Phase 2:** ước tính khoảng 250–300k, phần lớn cho việc viết `sim.gd`, `view.gd` và các test. Để tiết kiệm, agent chính không dùng subagent trong lúc viết và chỉ dùng một reviewer ở cuối.

## Đánh giá nhanh
- Đạt: bộ test đạt 56/56, gồm toàn bộ test Phase 1 (hồi quy). Ba Đêm chạy được cả headless lẫn GUI. GUI đạt khoảng 106–110 FPS.
- Chưa làm: hiệu ứng lá bay khi gió sắp nổi mới chỉ có chữ trên HUD và âm thanh, chưa có hạt lá. Phần sáng tạo (thanh Tỉnh táo, thể lực) được dời sang sau, theo yêu cầu "làm phần bắt buộc trước".
