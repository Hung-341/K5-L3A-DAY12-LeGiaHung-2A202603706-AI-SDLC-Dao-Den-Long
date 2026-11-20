# shellcheck shell=bash
# Tìm Godot 4.x để chạy game: biến GODOT → `godot` trên PATH → bản đã tải trong .godot-bin/.
# Không có thì tải bản chính thức Godot 4.7.2 (macOS universal / Linux x86_64, arm64) vào .godot-bin/.
GODOT_VERSION=4.7.2

find_godot() {
  local root="$1" c
  for c in "${GODOT:-}" "$(command -v godot 2>/dev/null || true)" \
           "$root/.godot-bin/godot" "$root/.godot-bin/Godot.app/Contents/MacOS/Godot"; do
    if [ -n "$c" ] && [ -x "$c" ] && "$c" --version 2>/dev/null | grep -q '^4\.'; then
      printf '%s' "$c"
      return 0
    fi
  done
  return 1
}

fetch_godot() {
  local root="$1" base name
  base="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable"
  case "$(uname -s)" in
    Darwin) name="Godot_v${GODOT_VERSION}-stable_macos.universal" ;;
    Linux)
      case "$(uname -m)" in
        aarch64|arm64) name="Godot_v${GODOT_VERSION}-stable_linux.arm64" ;;
        *) name="Godot_v${GODOT_VERSION}-stable_linux.x86_64" ;;
      esac ;;
    *) echo "Chưa hỗ trợ tự tải Godot trên $(uname -s). Cài Godot ${GODOT_VERSION} rồi đặt biến GODOT." >&2
       return 1 ;;
  esac
  mkdir -p "$root/.godot-bin"
  echo "Đang tải Godot ${GODOT_VERSION} (một lần, ~60 MB) vào .godot-bin/ ..." >&2
  curl -fL --progress-bar "$base/$name.zip" -o "$root/.godot-bin/godot.zip" || return 1
  (cd "$root/.godot-bin" && unzip -oq godot.zip && rm godot.zip) || return 1
  if [ -f "$root/.godot-bin/$name" ]; then
    mv "$root/.godot-bin/$name" "$root/.godot-bin/godot"
    chmod +x "$root/.godot-bin/godot"
  fi
  find_godot "$root"
}

godot_or_fetch() {
  find_godot "$1" || fetch_godot "$1"
}
