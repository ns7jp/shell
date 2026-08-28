#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

usage() { printf '%s\n' 'Usage: server_audit.sh --config FILE [--output FILE]' '終了コード: 0=正常、1=警告あり、2=実行エラー'; }
config_path=''
output_path=''
while (($#)); do
  case "$1" in
    --config) [[ $# -ge 2 ]] || die '--config に値が必要です'; config_path=$2; shift 2 ;;
    --output) [[ $# -ge 2 ]] || die '--output に値が必要です'; output_path=$2; shift 2 ;;
    -h|--help) usage; exit "$EXIT_OK" ;;
    *) die "不明な引数です: $1" ;;
  esac
done
[[ -n $config_path ]] || die '--config は必須です'
load_config "$config_path"
: "${CPU_WARN_PERCENT:=80}"
: "${MEMORY_WARN_PERCENT:=80}"
: "${DISK_WARN_PERCENT:=80}"
: "${CHECK_SERVICES:=}"
: "${LOG_DIR:=/var/log}"
require_integer_range CPU_WARN_PERCENT "$CPU_WARN_PERCENT" 1 100
require_integer_range MEMORY_WARN_PERCENT "$MEMORY_WARN_PERCENT" 1 100
require_integer_range DISK_WARN_PERCENT "$DISK_WARN_PERCENT" 1 100
require_absolute_safe_path LOG_DIR "$LOG_DIR"

if [[ -n $output_path ]]; then
  require_absolute_safe_path OUTPUT_PATH "$output_path"
  mkdir -p "$(dirname "$output_path")"
  exec > >(tee -a "$output_path") 2>&1
fi

warnings=0
warn_if_over() {
  local label=$1 value=$2 threshold=$3
  if (( value >= threshold )); then
    log WARN "$label: ${value}% (しきい値: ${threshold}%)"
    ((warnings += 1))
  else
    log OK "$label: ${value}% (しきい値: ${threshold}%)"
  fi
}

require_command awk
require_command df
require_command hostname
log INFO 'サーバー点検を開始します'
log INFO "ホスト名: $(hostname)"
[[ -r /etc/os-release ]] && log INFO "OS: $(awk -F= '/^PRETTY_NAME=/{gsub(/\"/,"",$2); print $2}' /etc/os-release)"
log INFO "カーネル: $(uname -r)"

if [[ -r /proc/loadavg ]] && command -v nproc >/dev/null 2>&1; then
  load_one=$(awk '{print $1}' /proc/loadavg)
  cpu_count=$(nproc)
  cpu_percent=$(awk -v load_value="$load_one" -v cpu_count="$cpu_count" 'BEGIN {printf "%d", (load_value/cpu_count)*100}')
  warn_if_over 'CPU負荷率(1分load average/論理CPU)' "$cpu_percent" "$CPU_WARN_PERCENT"
else
  log WARN 'CPU負荷率を取得できません'; ((warnings += 1))
fi

if [[ -r /proc/meminfo ]]; then
  memory_percent=$(awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{printf "%d", ((t-a)/t)*100}' /proc/meminfo)
  warn_if_over 'メモリ使用率' "$memory_percent" "$MEMORY_WARN_PERCENT"
else
  log WARN 'メモリ使用率を取得できません'; ((warnings += 1))
fi

while IFS= read -r disk_line; do
  mount_point=$(awk '{print $6}' <<<"$disk_line")
  disk_percent=$(awk '{gsub(/%/,"",$5); print $5}' <<<"$disk_line")
  warn_if_over "ディスク使用率 $mount_point" "$disk_percent" "$DISK_WARN_PERCENT"
done < <(df -P -x tmpfs -x devtmpfs 2>/dev/null | awk 'NR>1')

for service in $CHECK_SERVICES; do
  if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet "$service"; then
    log OK "サービス稼働: $service"
  else
    log WARN "サービス停止または確認不能: $service"; ((warnings += 1))
  fi
done

if [[ -d $LOG_DIR && -r $LOG_DIR ]]; then
  log OK "ログディレクトリ読取可能: $LOG_DIR"
else
  log WARN "ログディレクトリ読取不能: $LOG_DIR"; ((warnings += 1))
fi

if (( warnings > 0 )); then
  log WARN "点検完了: 警告 ${warnings} 件"
  exit "$EXIT_WARNING"
fi
log OK '点検完了: 警告なし'
