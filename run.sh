#!/usr/bin/env bash
# Chạy game có giao diện (run_cmd). Tham số thêm được chuyển cho game, ví dụ: ./run.sh --export-leaderboard out.json
set -eu
ROOT="$(cd "$(dirname "$0")" && pwd)"
. "$ROOT/tools/godot.sh"
G="$(godot_or_fetch "$ROOT")"
args=()
while [ $# -gt 0 ]; do
  case "$1" in
    --export-leaderboard) case "$2" in /*) args+=("$1" "$2") ;; *) args+=("$1" "$PWD/$2") ;; esac; shift 2 ;;
    *) args+=("$1"); shift ;;
  esac
done
exec "$G" --path "$ROOT" -- ${args[@]+"${args[@]}"}
