#!/usr/bin/env bash
# E15 模範解答: ある・中身・権限を、途中で止めずに3項目とも確かめます。
set -Eeuo pipefail

source "${LAB_COMMON:?LAB_COMMON が未設定です。source \"$HOME/bash-lab/labenv.sh\" を実行してください}"

usage() {
  printf '%s\n' 'Usage: verify_dir.sh --dir DIR' '終了コード: 0=警告なし、1=警告あり、2=実行エラー'
}

# --- 受ける ----------------------------------------------------------------
dir=''
while (($#)); do
  case "$1" in
    --dir) [[ $# -ge 2 ]] || die '--dir に値が必要です'; dir=$2; shift 2 ;;
    -h|--help) usage; exit "$EXIT_OK" ;;
    *) die "不明な引数です: $1" ;;
  esac
done

# --- 疑う ------------------------------------------------------------------
[[ -n $dir ]] || die '--dir は必須です'
require_absolute_safe_path DIR "$dir"
[[ -d $dir ]] || die "確認するディレクトリがありません: $dir"

# --- 確かめる（ある・中身・権限を3項目とも見ます） --------------------------
target="$dir/index.html"
warnings=0
log INFO "受け入れ試験を開始します: $target"

if [[ -e $target ]]; then
  log OK "ある: $target"
else
  log WARN "ありません: $target"
  ((warnings += 1))
fi

if [[ -s $target ]]; then
  log OK "中身: 空ではありません"
else
  log WARN "中身: 空か、読めません"
  ((warnings += 1))
fi

mode=$(stat -c '%a' -- "$target" 2>/dev/null || printf '取得できません')
if [[ $mode == 644 ]]; then
  log OK "権限: $mode"
else
  log WARN "権限: 644 ではありません（$mode）"
  ((warnings += 1))
fi

# --- 伝える ----------------------------------------------------------------
if ((warnings > 0)); then
  log WARN "受け入れ試験完了: 警告 ${warnings} 件"
  exit "$EXIT_WARNING"
fi
log OK '受け入れ試験完了: 警告なし'
