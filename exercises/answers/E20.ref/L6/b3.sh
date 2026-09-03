#!/usr/bin/env bash
# b3: アーカイブの中身を一覧にして並べ替えます。
# 直し済み: set の行に pipefail を足しました（バグ3種の3つ目、パイプ）。
set -Eeuo pipefail

source "${LAB_COMMON:?LAB_COMMON が未設定です。source \"$HOME/bash-lab/labenv.sh\" を実行してください}"

usage() {
  printf '%s\n' 'Usage: b3.sh --archive FILE' 'アーカイブの中身を並べ替えて表示します。'
}

archive=''
while (($#)); do
  case "$1" in
    --archive) [[ $# -ge 2 ]] || die '--archive に値が必要です'; archive=$2; shift 2 ;;
    -h|--help) usage; exit "$EXIT_OK" ;;
    *) die "不明な引数です: $1" ;;
  esac
done
[[ -n $archive ]] || die '--archive は必須です'
[[ -f $archive ]] || die "アーカイブがありません: $archive"

listing=$(tar -tzf "$archive" | sort)
log INFO "中身: $(printf '%s' "$listing" | tr '\n' ' ')"
log OK "一覧を作りました: $archive"
