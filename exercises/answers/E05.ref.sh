#!/usr/bin/env bash
# E05 模範解答: 引数の受け方は4分岐だけです。scripts/backup.sh の14〜21行と同じ形です。
set -Eeuo pipefail

source "${LAB_COMMON:?LAB_COMMON が未設定です。source \"$HOME/bash-lab/labenv.sh\" を実行してください}"

usage() {
  printf '%s\n' 'Usage: argparse.sh --config FILE [--execute]' '既定はドライランです。'
}

config_path=''
execute=false
while (($#)); do
  case "$1" in
    --config) [[ $# -ge 2 ]] || die '--config に値が必要です'; config_path=$2; shift 2 ;;
    --execute) execute=true; shift ;;
    -h|--help) usage; exit "$EXIT_OK" ;;
    *) die "不明な引数です: $1" ;;
  esac
done

[[ -n $config_path ]] || die '--config は必須です'
printf 'config=%s execute=%s\n' "$config_path" "$execute"
