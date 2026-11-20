#!/usr/bin/env bash
# Benchmark (bench_cmd): ./bench.sh --seed 42 --duration 30 --out bench.json
# Mở cửa sổ 1280x720 (cần màn hình/GPU, không chạy trong Docker), tắt vsync, ghi kết quả JSON.
set -eu
ROOT="$(cd "$(dirname "$0")" && pwd)"
. "$ROOT/tools/godot.sh"
G="$(godot_or_fetch "$ROOT")"
args=()
while [ $# -gt 0 ]; do
  case "$1" in
    --out) case "$2" in /*) args+=("$1" "$2") ;; *) args+=("$1" "$PWD/$2") ;; esac; shift 2 ;;
    *) args+=("$1"); shift ;;
  esac
done
exec "$G" --path "$ROOT" --resolution 1280x720 -- --bench ${args[@]+"${args[@]}"}
