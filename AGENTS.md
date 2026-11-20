# AGENTS.md — Đảo Đèn Lồng (Godot 4.7.2)

## Lệnh
- Test (bắt buộc xanh trước khi xong việc): `python tests/run_tests.py` (biến `GODOT` trỏ tới Godot 4 console nếu không có trên PATH)
- Headless: `./headless.sh --seed 1 --night 1 --ticks 600 --out out/a.jsonl [--scenario f] [--inputs f]`
- Build image chấm: `docker build -t dao-den-long .`
- Ảnh bằng chứng GUI: `DDL_SHOT=docs/proof/phaseN/x.png godot --path . --resolution 1280x720`
- Sau khi thêm/đổi script: `godot --headless --path . --import`

## Kiến trúc
- `scripts/sim.gd`: TOÀN BỘ luật chơi trong `step()`, theo thứ tự 12 bước của Ticket-02. Không phụ thuộc node.
- `scripts/headless.gd`: đọc tham số, validate (sai định dạng → exit 2), ghi JSONL. `scripts/view.gd`: chỉ vẽ.
- Số liệu đọc từ `game.contract.json` (`Sim.load_tuning()`), hằng số khác là `const` đầu `sim.gd`.

## Quy tắc
- Không dùng `class_name`; dùng `preload` (image Docker và máy chấm có thể chưa import).
- Không dùng RNG toàn cục; chỉ `sim.rng` (seed từ `--seed`). Output phải giống hệt từng byte giữa hai lần chạy.
- Sáng tạo thêm chỉ ở `view.gd` hoặc tắt khi headless; không được đổi output headless.
- Mỗi luật mới có ít nhất một test trong `tests/run_tests.py`; test sai vì đổi yêu cầu thì sửa kèm lý do trong `docs/notes/`.
- Không sửa tay file output; không viết test luôn đạt.
- Commit nhỏ, subject tiếng Anh, body tiếng Việt; không ghi co-author AI.
