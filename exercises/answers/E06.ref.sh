#!/usr/bin/env bash
# E06 模範解答: E05 の形に --output を1つ足しただけです。
# 値を取る引数は、どれも同じ形（値の確認 → 受け取り → shift 2）にします。
set -Eeuo pipefail

source "${LAB_COMMON:?LAB_COMMON が未設定です。source \"$HOME/bash-lab/labenv.sh\" を実行してください}"

usage() {
  printf '%s\n' 'Usage: argparse2.sh --config FILE --output FILE [--execute]' '既定はドライランです。'
}

config_path=''
output_path=''
execute=false
while (($#)); do
  case "$1" in
    --config) [[ $# -ge 2 ]] || die '--config に値が必要です'; config_path=$2; shift 2 ;;
    --output) [[ $# -ge 2 ]] || die '--output に値が必要です'; output_path=$2; shift 2 ;;
    --execute) execute=true; shift ;;
    -h|--help) usage; exit "$EXIT_OK" ;;
    *) die "不明な引数です: $1" ;;
  esac
done

[[ -n $config_path ]] || die '--config は必須です'
printf 'config=%s output=%s execute=%s\n' "$config_path" "$output_path" "$execute"
