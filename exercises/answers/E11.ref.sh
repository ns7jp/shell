#!/usr/bin/env bash
# E11 模範解答: 冪等は「2回やって同じ」です。名前にも中身にも日時を入れません。
set -Eeuo pipefail

source "${LAB_COMMON:?LAB_COMMON が未設定です。source \"$HOME/bash-lab/labenv.sh\" を実行してください}"

usage() {
  printf '%s\n' 'Usage: idem.sh --dest DIR' '2回実行しても結果は変わりません。'
}

# --- 受ける ----------------------------------------------------------------
dest=''
while (($#)); do
  case "$1" in
    --dest) [[ $# -ge 2 ]] || die '--dest に値が必要です'; dest=$2; shift 2 ;;
    -h|--help) usage; exit "$EXIT_OK" ;;
    *) die "不明な引数です: $1" ;;
  esac
done

# --- 疑う ------------------------------------------------------------------
[[ -n $dest ]] || die '--dest は必須です'
require_absolute_safe_path DEST "$dest"

src="${LAB_FIXTURES:?LAB_FIXTURES が未設定です}/E11/app.conf"
dst="$dest/conf/app.conf"
[[ -f $src ]] || die "教材ファイルがありません: $src"

# --- 動かす ----------------------------------------------------------------
mkdir -p -- "$dest"
install -D -m 0644 -- "$src" "$dst"

# --- 伝える ----------------------------------------------------------------
log OK "配置しました: $dst"
exit "$EXIT_OK"
