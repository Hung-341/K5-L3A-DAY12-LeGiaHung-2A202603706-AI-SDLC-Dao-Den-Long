---
name: verify-game
description: Chạy và lưu bằng chứng cho Đảo Đèn Lồng (test headless, tất định, ảnh GUI, FPS). Dùng trước khi báo xong việc, trước khi gắn tag phase-N, hoặc khi đổi luật trong scripts/sim.gd.
---

1. `godot --headless --path . --import` nếu vừa thêm/đổi script.
2. `python tests/run_tests.py > docs/proof/phaseN/run_tests.txt` — phải hết FAIL. Test hỏng vì yêu cầu mới: sửa test kèm lý do trong `docs/notes/phaseN.md`, không xóa âm thầm.
3. Ảnh + FPS từng Đêm (in `avg_fps=` ra stdout):
   `DDL_NIGHT=n DDL_AUTOPLAY=1 DDL_SHOT_FRAMES=420 DDL_SHOT=docs/proof/phaseN/nightn.png godot --path . --resolution 1280x720`
   Đọc ảnh để kiểm HUD/màu thật sự đúng, không chỉ kiểm file tồn tại.
4. Headless như máy chấm: `docker build -t dao-den-long .` rồi `./headless.sh --seed 1 --night n --ticks 21600 --out out/x.jsonl` (Git Bash trên Windows: `export MSYS_NO_PATHCONV=1`). Chạy 2 lần, `cmp` để kiểm tất định.
5. Cập nhật bảng yêu cầu → bằng chứng trong `docs/proof/phaseN/README.md`; ghi "chưa đạt" kèm lý do nếu có.
