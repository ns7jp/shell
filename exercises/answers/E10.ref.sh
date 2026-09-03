#!/usr/bin/env bash
# E10 模範解答: 変更するコマンドは run_or_show を通します。既定はドライランです。
set -Eeuo pipefail

source "${LAB_COMMON:?LAB_COMMON が未設定です。source \"$HOME/bash-lab/labenv.sh\" を実行してください}"

usage() {
  printf '%s\n' 'Usage: dry.sh --dest DIR [--execute]' '既定はドライランです。'
}

# --- 受ける ----------------------------------------------------------------
DEST=''
execute=false
while (($#)); do
  case "$1" in
    --dest) [[ $# -ge 2 ]] || die '--dest に値が必要です'; DEST=$2; shift 2 ;;
    --execute) execute=true; shift ;;
    -h|--help) usage; exit "$EXIT_OK" ;;
    *) die "不明な引数です: $1" ;;
  esac
done

# --- 疑う ------------------------------------------------------------------
[[ -n $DEST ]] || die '--dest は必須です'
require_absolute_safe_path DEST "$DEST"

# --- 動かす ----------------------------------------------------------------
run_or_show "$execute" mkdir -p -- "$DEST"

# --- 伝える ----------------------------------------------------------------
log OK '完了しました'
exit "$EXIT_OK"
