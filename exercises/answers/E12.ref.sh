#!/usr/bin/env bash
# E12 模範解答: 既定はドライラン、--execute のときだけ実際にコピーします。
set -Eeuo pipefail

source "${LAB_COMMON:?LAB_COMMON が未設定です。source \"$HOME/bash-lab/labenv.sh\" を実行してください}"

usage() {
  printf '%s\n' 'Usage: copyjob.sh --src DIR --dst DIR [--execute]' '既定はドライランです。'
}

src=''
dst=''
execute=false
while (($#)); do
  case "$1" in
    --src) [[ $# -ge 2 ]] || die '--src に値が必要です'; src=$2; shift 2 ;;
    --dst) [[ $# -ge 2 ]] || die '--dst に値が必要です'; dst=$2; shift 2 ;;
    --execute) execute=true; shift ;;
    -h|--help) usage; exit "$EXIT_OK" ;;
    *) die "不明な引数です: $1" ;;
  esac
done

# 検証は --execute の有無に関係なく、必ず先に行います。
[[ -n $src ]] || die '--src は必須です'
[[ -n $dst ]] || die '--dst は必須です'
require_absolute_safe_path SRC "$src"
require_absolute_safe_path DST "$dst"
[[ -d $src && -r $src ]] || die "コピー元を読み取れません: $src"
[[ $dst != "$src" && $dst != "$src"/* ]] || die 'コピー先をコピー元の配下に置くことはできません'

log INFO "コピー元: $src"
log INFO "コピー先: $dst"
run_or_show "$execute" mkdir -p -- "$dst"
run_or_show "$execute" cp -a -- "$src/." "$dst/"

if [[ $execute == true ]]; then
  [[ -d $dst ]] || die "コピー先を確認できません: $dst"
  log OK "コピーが完了しました: $dst"
else
  log INFO 'ドライラン完了。内容を確認後、--execute を指定してください'
fi
