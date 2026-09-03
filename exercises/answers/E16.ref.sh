#!/usr/bin/env bash
# E16 模範解答: 警告の数で終了コードを 0 / 1 / 2 に出し分けます。
set -Eeuo pipefail

source "${LAB_COMMON:?LAB_COMMON が未設定です。source \"$HOME/bash-lab/labenv.sh\" を実行してください}"

usage() {
  printf '%s\n' 'Usage: report.sh --config FILE' '終了コード: 0=警告なし、1=警告あり、2=実行エラー'
}

# --- 受ける ----------------------------------------------------------------
config_path=''
while (($#)); do
  case "$1" in
    --config) [[ $# -ge 2 ]] || die '--config に値が必要です'; config_path=$2; shift 2 ;;
    -h|--help) usage; exit "$EXIT_OK" ;;
    *) die "不明な引数です: $1" ;;
  esac
done

# --- 疑う ------------------------------------------------------------------
[[ -n $config_path ]] || die '--config は必須です'
load_config "$config_path"
[[ -n ${TARGET_DIR:-} ]] || die 'TARGET_DIR は必須です'
: "${CHECK_FILES:=}"
require_absolute_safe_path TARGET_DIR "$TARGET_DIR"

# --- 確かめる --------------------------------------------------------------
warnings=0
log INFO "点検を開始します: $TARGET_DIR"
for check_name in $CHECK_FILES; do
  if [[ -s "$TARGET_DIR/$check_name" ]]; then
    log OK "あります: $check_name"
  else
    log WARN "ありません: $check_name"
    warnings=$((warnings + 1))
  fi
done

# --- 伝える ----------------------------------------------------------------
if ((warnings > 0)); then
  log WARN "点検完了: 警告 ${warnings} 件"
  exit "$EXIT_WARNING"
fi
log OK '点検完了: 警告なし'
