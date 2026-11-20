extends RefCounted
## Đo bộ nhớ tiến trình (RSS, MB) cho bench/soak. Linux: /proc; macOS: ps; Windows: PowerShell.

static func rss_mb() -> float:
	var pid := OS.get_process_id()
	match OS.get_name():
		"Linux", "FreeBSD":
			var f := FileAccess.open("/proc/self/status", FileAccess.READ)
			if f:
				for line in f.get_as_text().split("\n"):
					if line.begins_with("VmRSS:"):
						return float(line.split(":")[1].strip_edges().split(" ")[0]) / 1024.0
		"macOS":
			var out := []
			if OS.execute("ps", ["-o", "rss=", "-p", str(pid)], out) == 0 and out.size() > 0:
				return float(str(out[0]).strip_edges()) / 1024.0
		"Windows":
			var out := []
			if OS.execute("powershell", ["-NoProfile", "-Command", "(Get-Process -Id %d).WorkingSet64" % pid], out) == 0 and out.size() > 0:
				return float(str(out[0]).strip_edges()) / 1048576.0
	return -1.0
