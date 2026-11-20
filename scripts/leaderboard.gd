extends RefCounted
## Bảng xếp hạng cục bộ (Ticket-04 mục 3): top 10, score giảm dần, bằng điểm thì ai đạt trước đứng trên.
## Lưu ở user://leaderboard.json (còn sau khi tắt game). DDL_LB_PATH đổi đường dẫn (dùng cho test).

const MAX := 10


static func path() -> String:
	var p := OS.get_environment("DDL_LB_PATH")
	return p if p != "" else "user://leaderboard.json"


## 3–12 ký tự: chữ cái (gồm tiếng Việt có dấu), số, gạch dưới.
static func valid_name(n: String) -> bool:
	var re := RegEx.create_from_string("^[\\p{L}\\p{M}0-9_]{3,12}$")
	return re.search(n.strip_edges()) != null and n.strip_edges() == n


static func load_entries() -> Array:
	if not FileAccess.file_exists(path()):
		return []
	var d = JSON.parse_string(FileAccess.get_file_as_string(path()))
	return d.get("entries", []) if typeof(d) == TYPE_DICTIONARY else []


static func save_entries(entries: Array) -> void:
	var f := FileAccess.open(path(), FileAccess.WRITE)
	f.store_string(JSON.stringify({"entries": entries}, "  ", false))
	f.close()


## Thời điểm hiện tại theo ISO 8601 có múi giờ, ví dụ 2026-11-20T16:05:09+07:00.
static func iso_now() -> String:
	var bias: int = Time.get_time_zone_from_system().get("bias", 0)
	return "%s%s%02d:%02d" % [Time.get_datetime_string_from_system(false, false), "+" if bias >= 0 else "-",
		absi(bias) / 60, absi(bias) % 60]


## Thêm một mục, trả về danh sách mới đã sắp xếp và cắt top 10.
## Thứ tự ổn định: điểm giảm dần; bằng điểm thì mục có sẵn (đạt trước) đứng trên mục mới.
static func add(entries: Array, name: String, score: int, nights_won: int, seed: int) -> Array:
	var e := {"name": name, "score": score, "nights_won": clampi(nights_won, 0, 3), "achieved_at": iso_now(), "seed": seed}
	var out := entries.duplicate()
	var i := out.size()
	while i > 0 and int(out[i - 1]["score"]) < score:
		i -= 1
	out.insert(i, e)
	return out.slice(0, MAX)


static func export_to(file: String) -> int:
	var f := FileAccess.open(file, FileAccess.WRITE)
	if f == null:
		printerr("không ghi được ", file)
		return 1
	f.store_string(JSON.stringify({"entries": load_entries()}, "  ", false) + "\n")
	f.close()
	return 0
