#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

usage() { printf '%s\n' 'Usage: rotate_app_logs.sh --config FILE [--execute]' '既定はドライランです。'; }
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
load_config "$config_path"
[[ -n ${LOG_DIR:-} ]] || die 'LOG_DIR は必須です'
[[ -n ${ARCHIVE_DIR:-} ]] || die 'ARCHIVE_DIR は必須です'
: "${COMPRESS_AFTER_DAYS:=1}"
: "${DELETE_AFTER_DAYS:=30}"
: "${LOG_PATTERN:=*.log}"
require_absolute_safe_path LOG_DIR "$LOG_DIR"
require_absolute_safe_path ARCHIVE_DIR "$ARCHIVE_DIR"
require_integer_range COMPRESS_AFTER_DAYS "$COMPRESS_AFTER_DAYS" 0 3650
require_integer_range DELETE_AFTER_DAYS "$DELETE_AFTER_DAYS" 1 3650
(( DELETE_AFTER_DAYS > COMPRESS_AFTER_DAYS )) || die 'DELETE_AFTER_DAYS は COMPRESS_AFTER_DAYS より大きくしてください'
[[ $LOG_PATTERN == '*.log' ]] || die '安全のため LOG_PATTERN は *.log のみ許可します'
[[ -d $LOG_DIR && -r $LOG_DIR ]] || die "ログディレクトリを読み取れません: $LOG_DIR"
require_command find
require_command gzip

run_or_show "$execute" mkdir -p -- "$ARCHIVE_DIR"
mapfile -d '' logs < <(find "$LOG_DIR" -maxdepth 1 -type f -name "$LOG_PATTERN" -mtime "+$COMPRESS_AFTER_DAYS" -print0)
for log_file in "${logs[@]}"; do
  target="$ARCHIVE_DIR/$(basename "$log_file").$(date '+%Y%m%d_%H%M%S').gz"
  if [[ $execute == true ]]; then
    log INFO "圧縮: $log_file -> $target"
    gzip -c -- "$log_file" >"$target"
    [[ -s $target ]] || die "圧縮ファイルを確認できません: $target"
    : >"$log_file"
  else
    log INFO "[DRY-RUN] 圧縮後に元ログを空にする: $log_file -> $target"
  fi
done
run_or_show "$execute" find "$ARCHIVE_DIR" -maxdepth 1 -type f -name '*.log.*.gz' -mtime "+$DELETE_AFTER_DAYS" -delete
log OK "ログ保守完了: 対象 ${#logs[@]} 件、execute=$execute"
