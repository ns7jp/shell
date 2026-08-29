#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

usage() { printf '%s\n' 'Usage: build_verify.sh --config FILE [--output FILE]' '終了コード: 0=正常、1=警告あり、2=実行エラー'; }
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
[[ -n ${PACKAGE_NAME:-} ]] || die 'PACKAGE_NAME は必須です'
[[ -n ${SERVICE_NAME:-} ]] || die 'SERVICE_NAME は必須です'
[[ -n ${WEB_ROOT:-} ]] || die 'WEB_ROOT は必須です'
: "${HTTP_PORT:=80}"
: "${HEALTHCHECK_PATH:=/}"
require_absolute_safe_path WEB_ROOT "$WEB_ROOT"
require_integer_range HTTP_PORT "$HTTP_PORT" 1 65535
[[ $HEALTHCHECK_PATH == /* ]] || die 'HEALTHCHECK_PATH は / から始めてください'

if [[ -n $output_path ]]; then
  require_absolute_safe_path OUTPUT_PATH "$output_path"
  mkdir -p "$(dirname "$output_path")"
  exec > >(tee -a "$output_path") 2>&1
fi

require_command curl
require_command dpkg
warnings=0
log INFO '構築後の受け入れ試験を開始します'
log INFO "対象パッケージ: $PACKAGE_NAME / サービス名: $SERVICE_NAME / ポート: $HTTP_PORT"

if dpkg -s -- "$PACKAGE_NAME" >/dev/null 2>&1; then
  log OK "パッケージ導入済み: $PACKAGE_NAME"
else
  log WARN "パッケージ未導入: $PACKAGE_NAME"
  ((warnings += 1))
fi

service_active=false
if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet -- "$SERVICE_NAME" 2>/dev/null; then
  service_active=true
elif pgrep -x -- "$SERVICE_NAME" >/dev/null 2>&1; then
  service_active=true
fi
if [[ $service_active == true ]]; then
  log OK "サービス稼働中: $SERVICE_NAME"
else
  log WARN "サービス停止または確認不能: $SERVICE_NAME"
  ((warnings += 1))
fi

if [[ -s "$WEB_ROOT/index.html" ]]; then
  log OK "配布ファイルを確認しました: $WEB_ROOT/index.html"
else
  log WARN "配布ファイルが見つかりません: $WEB_ROOT/index.html"
  ((warnings += 1))
fi

http_code=$(curl -fsS -o /dev/null -w '%{http_code}' --max-time 5 "http://127.0.0.1:${HTTP_PORT}${HEALTHCHECK_PATH}" 2>/dev/null) || true
[[ -n $http_code ]] || http_code='000'
if [[ $http_code == 200 ]]; then
  log OK "HTTP応答を確認しました: ${HTTP_PORT}${HEALTHCHECK_PATH} -> $http_code"
else
  log WARN "HTTP応答を確認できません: ${HTTP_PORT}${HEALTHCHECK_PATH} -> $http_code"
  ((warnings += 1))
fi

if command -v ufw >/dev/null 2>&1; then
  if ufw status 2>/dev/null | grep -Fq "${HTTP_PORT}/tcp"; then
    log OK "ファイアウォール許可を確認しました: ${HTTP_PORT}/tcp"
  else
    log WARN "ファイアウォール許可を確認できません: ${HTTP_PORT}/tcp"
    ((warnings += 1))
  fi
else
  log WARN 'ufw が見つからないためファイアウォール設定を確認できません'
  ((warnings += 1))
fi

if (( warnings > 0 )); then
  log WARN "受け入れ試験完了: 警告 ${warnings} 件"
  exit "$EXIT_WARNING"
fi
log OK '受け入れ試験完了: 警告なし'
