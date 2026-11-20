# Đảo Đèn Lồng (Day 12 · AI SDLC)

> **Video demo:** [Release v1.0.0](https://github.com/Hung-341/K5-L3A-DAY12-LeGiaHung-2A202603706-AI-SDLC-Dao-Den-Long/releases/tag/v1.0.0) (`demo.mp4`) · **Bản chạy được:** cùng trang Release · Tài liệu lab gốc: [LAB-README.md](LAB-README.md)

![Đảo Đèn Lồng: Đêm 1](docs/proof/phase4/night1.png)

Đảo Đèn Lồng là game 3D góc nhìn thứ ba làm bằng Godot 4.7.2. Mây đội nón lá, treo đèn lồng nhỏ và nhặt đom đóm trên ba hòn đảo trôi giữa biển mây để thắp và giữ dầu cho các Đèn Lồng Lớn. Mây phải né Bóng Mực, Gió Lạc và Sương Gai, và **giữ đảo sáng tới bình minh**.

## Yêu cầu hệ thống
- **Chơi:** máy cần macOS 12+ hoặc Linux x86_64/arm64 (có X11/Wayland), GPU hỗ trợ Vulkan hoặc Metal, cùng `curl` và `unzip`. `run.sh` tự tải Godot 4.7.2 chính thức (khoảng 60 MB, một lần) nếu máy chưa có. Trên Windows, người chơi dùng bản Windows trong Release.
- **Headless / soak:** máy cần Godot 4 trên PATH hoặc Docker (image được dựng bằng lệnh `docker build` bên dưới).
- **Test:** máy cần Python 3.8+; bộ test chỉ dùng thư viện chuẩn.

## Cài và chơi (3 lệnh)

```bash
git clone https://github.com/Hung-341/K5-L3A-DAY12-LeGiaHung-2A202603706-AI-SDLC-Dao-Den-Long.git
cd K5-L3A-DAY12-LeGiaHung-2A202603706-AI-SDLC-Dao-Den-Long
./run.sh
```

## Lệnh theo Test Contract v1.3 ([game.contract.json](game.contract.json))

| Việc | Lệnh |
|---|---|
| build_cmd (image headless) | `docker build -t dao-den-long .` |
| run_cmd (chơi) | `./run.sh` |
| headless_cmd | `./headless.sh --seed 1 --night 1 --ticks 600 --out out/a.jsonl [--scenario f.json] [--inputs f.json]` |
| bench_cmd | `./bench.sh --seed 42 --duration 30 --out bench.json` (cần màn hình; tắt vsync) |
| soak_cmd | `./headless.sh --soak --seed 7 --nights 10 --out soak.json` |
| Xuất bảng xếp hạng | `./run.sh --export-leaderboard out.json` |
| Test | `python3 tests/run_tests.py` (78 scenario headless) |

`headless.sh` dùng Godot 4 có sẵn (biến `GODOT` hoặc `godot` trên PATH); nếu máy không có Godot, script chạy trong Docker image `dao-den-long`. Kết quả tự đo nằm ở [docs/proof/phase4/](docs/proof/phase4/): bench avg **135.9 FPS**, p1_low **43.0**, load **2.75 s**; soak 10 Đêm **0 crash**.

## Điều khiển (đổi được trong Cài đặt → Đổi phím)

| Phím mặc định | Việc |
|---|---|
| W A S D | Đi theo hướng camera |
| Chuột / cuộn chuột | Xoay camera góc nhìn thứ ba / zoom |
| Space | Nhảy |
| Shift | Lướt |
| E | Nạp đom đóm vào đèn / châm dầu |
| F hoặc chuột trái | Tỏa Sáng (3 đom đóm) |
| Q | Gió Đèn: thổi bay Sương Gai (phần sáng tạo) |
| P hoặc Esc | Tạm dừng: Tiếp tục / Chơi lại Đêm / Cài đặt / Về menu |

**Cài đặt** gồm âm lượng, độ nhạy chuột, bảng màu dễ phân biệt, giảm chuyển động, chữ lớn ×1.25, đổi phím (có báo trùng và khôi phục mặc định) và trang phục. Mọi tùy chọn đều được lưu.

## Luật và cách tính điểm (v1.2–v1.3)
- **Ba Đêm:** Đảo Bến (5 đèn, 240 s), Đảo Cau (6 đèn, 270 s, cầu tre, bục nhảy), Đảo Chuông (7 đèn, 300 s, 3 tầng, dốc, gió mạnh).
- **Đom đóm:** Mây nhặt đom đóm tự động trong bán kính 1.0 m. Sức chứa là `10 + 2 × số lần thắp thành công`, tối đa 20. Thắp đèn lần đầu cần 10 đom đóm, thắp lại cần 5.
- **Dầu đèn:** đèn sáng có 100 dầu và hao 1/s. Người chơi nhấn E để châm (+10 dầu mỗi đom đóm). Đèn dưới 30 dầu nhấp nháy, mất vùng an toàn 6 m, và Bóng Mực tới hút 5/s. Khi hết dầu, đèn tắt.
- **Kẻ địch:**
  - Bóng Mực đuổi Mây khi ở trong 12 m; mỗi lần chạm, Mây mất 1 Ngọn Lửa (Mây có 3 Ngọn Lửa). Tỏa Sáng làm Bóng Mực choáng 2 s và đẩy nó lùi 4 m.
  - Gió Lạc (Đêm 2–3) cướp 3 đom đóm khi Mây mang ≥ 5.
  - Khi rơi khỏi đảo, Mây mất 1 Ngọn Lửa và mất hết đom đóm.
- **Thắng:** Mây phải còn sống tới bình minh và có ≥ 60% đèn đang sáng (3/5, 4/6, 5/7). Khi thua, người chơi chơi lại Đêm đó; khi thắng Đêm 3, game chuyển sang màn Bình Minh và lưu điểm vào **Bảng xếp hạng** (top 10).
- **Điểm:** +5 mỗi đom đóm nạp vào đèn · +100 thắp lần đầu · +40 thắp lại · +5 mỗi Bóng Mực trúng Tỏa Sáng (+15 nếu nó đang hút dầu) · khi thắng: mỗi đèn sáng +50 + floor(dầu), mỗi Ngọn Lửa +50. Tổng điểm là tổng điểm các Đêm đã thắng.
- Contract đặt `fall_enabled: true`, và không khái niệm nào để `null`.

## Tài liệu
[CHANGELOG.md](CHANGELOG.md) (4 phase, breaking changes) · [ADR 0001](docs/adr/0001-lantern-fuel-and-dawn-win.md) · ghi chép từng phase [docs/notes/](docs/notes/) · bằng chứng [docs/proof/](docs/proof/) · [retro](docs/notes/retro.md) · [kịch bản demo](docs/demo/DEMO-SCRIPT.md) · [CREDITS.md](CREDITS.md) · [LICENSE](LICENSE).

## Sáng tạo của tôi

Phần thêm chia thành hai loại. Cả hai loại đều không đổi luật hay số liệu chuẩn.

**A. Chỉ có trong bản giao diện** (`scripts/view.gd`, `scripts/creative.gd`; headless không nạp hai file này, nên output contract không đổi):
- **Sương Gai** là kẻ địch mới (ticket cho phép thêm kẻ địch ngoài Bóng Mực và Gió Lạc). Mỗi 4 đom đóm Mây đang mang thu hút thêm 1 Sương Gai, tối đa 5. Sương Gai tới từ hướng bất kỳ với tốc độ 4.5 m/s; khi chạm Mây, nó cướp 1 đom đóm và **không trừ Ngọn Lửa**. Người chơi phải chọn giữa việc ôm nhiều đom đóm để thắp và châm dầu nhanh và việc nạp sớm cho an toàn.
- **Gió Đèn (Q)** tốn 5 đom đóm, thổi bay Sương Gai trong bán kính 9 m và hồi chiêu 4 s. Gió Đèn không tác động Bóng Mực, vì luật chuẩn quy định Bóng Mực chỉ bị Tỏa Sáng đẩy và không chết.
- **Phản đòn và phần thưởng:** khi Mây lướt xuyên qua Sương Gai, Sương Gai bị hất văng; khi Mây đáp từ trên xuống đầu Sương Gai, Sương Gai bị đạp vỡ (Mây không nảy thêm, luật nhảy giữ nguyên). Sau mỗi lần thắp đèn thành công, Gió Đèn rẻ hơn 1 đom đóm (tối thiểu 2) và rộng thêm 2 m, còn Sương Gai cần thêm 1 đom đóm mới bị thu hút. Phần thưởng không cộng thời gian và không tăng tầm lướt hay nhảy, vì đó là số liệu chuẩn.
- **Viền tối:** Mây mang càng nhiều đom đóm thì rìa màn hình càng tối. Ánh sáng môi trường chuẩn (`0.15 + 0.55 × đèn sáng/tổng`) giữ nguyên.
- **Đảo "đồ chơi trong mơ":** đảo có nhân vật chibi, hiệu ứng tilt-shift, cây, đá, cỏ và hoa (hoa có cuống và cánh, không phát sáng để không nhầm với đom đóm), cùng hàng rào gỗ đánh dấu vùng an toàn 6 m. Đồ trang trí **không có va chạm** và được đặt tránh đèn, điểm đom đóm và bục nhảy, để bản đồ chuẩn không đổi.
- **Cảm giác điều khiển:** bản giao diện nội suy hình giữa các tick, có camera góc nhìn thứ ba xoay tự do (chuột ngang/dọc, cuộn để zoom, không xuyên đất) và nhớ phím trong 0.1 s. Bóng Mực để lại vệt mực khi đuổi; tốc độ thật của nó vẫn là 4.0 m/s.
- Âm thanh được tổng hợp bằng code (`scripts/sfx.gd`), không dùng file âm thanh ngoài.
- **Chọn Đêm:** menu cho phép chơi thẳng một Đêm bất kỳ; chuỗi giới thiệu → chơi → kết quả → Đêm kế vẫn giữ nguyên.
- **Trang phục:** người chơi chọn phụ kiện (hoa cài nón, đèn cá chép, ba lô lá), và lựa chọn được lưu lại. Áo `#E8E2D0`, khăn `#C8102E`, nón lá và đèn lồng nhỏ giữ đúng PRD và bảng màu.
- **Đom đóm bay quanh Mây:** Mây mang bao nhiêu đom đóm thì có bấy nhiêu con bay quanh người. Thanh 10 ô và "đang mang / sức chứa" trên HUD vẫn được giữ vì đó là yêu cầu bắt buộc.

**B. Lựa chọn thiết kế trong khuôn luật** (trong `sim.gd`, có test):
- Đom đóm sinh ở **điểm trống xa Mây nhất**, trong khi ticket chỉ yêu cầu "một điểm trống". Test tương ứng là `test_mote_spawn_farthest_free_point`.
- Bóng Mực lang thang theo **4 tính cách** theo id: bám đuôi ở 14 m, tuần tra mép đảo, rình quanh đèn và đi ngẫu nhiên. Tốc độ luôn ≤ 4.0 m/s; luật đuổi, hút dầu và gây hit giữ nguyên. Test tương ứng là `test_wander_personalities_speed_capped`.

Phần cũ vẫn đúng, vì toàn bộ test headless vẫn đạt ([docs/proof/](docs/proof/)).

## Harness AI

[AGENTS.md](AGENTS.md) (cập nhật qua 4 phase) · skill [verify-game](.claude/skills/verify-game/SKILL.md) · hook Stop chặn kết thúc khi test đỏ ([.claude/settings.json](.claude/settings.json)) · CI chạy test mỗi lần push ([.github/workflows/test.yml](.github/workflows/test.yml)) · công cụ chụp ảnh bằng chứng `DDL_SHOT`.
