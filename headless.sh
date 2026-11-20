#!/usr/bin/env bash
# Chạy headless theo Test Contract. Ưu tiên Godot 4 cài sẵn (biến GODOT hoặc `godot` trên PATH),
# nếu không có thì chạy trong Docker image `dao-den-long` (tạo bằng build_cmd).
set -eu
ROOT="$(cd "$(dirname "$0")" && pwd)"
args=()
mounts=()
seen=" "
abspath() { case "$1" in /*) printf '%s' "$1" ;; *) printf '%s/%s' "$PWD" "$1" ;; esac; }
while [ $# -gt 0 ]; do
  case "$1" in
    --out|--scenario|--inputs)
      [ $# -ge 2 ] || { echo "thiếu giá trị cho $1" >&2; exit 1; }
      p="$(abspath "$2")"
      d="$(dirname "$p")"
      if [ "$1" = "--out" ]; then mkdir -p "$d"; fi
      case "$seen" in *" $d "*) ;; *) mounts+=(-v "$d:$d"); seen="$seen$d " ;; esac
      args+=("$1" "$p"); shift 2 ;;
    *) args+=("$1"); shift ;;
  esac
done
G="${GODOT:-$(command -v godot || true)}"
if [ -n "$G" ] && "$G" --version 2>/dev/null | grep -q '^4\.'; then
  exec "$G" --headless --path "$ROOT" -- --headless-run ${args[@]+"${args[@]}"}
fi
# chạy bằng uid/gid của người gọi để file output không thuộc root
exec docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp ${mounts[@]+"${mounts[@]}"} dao-den-long \
  godot --headless --path /w -- --headless-run ${args[@]+"${args[@]}"}
