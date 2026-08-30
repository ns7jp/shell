#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

usage() {
  printf '%s\n' 'Usage: provision_web_server.sh --config FILE [--execute]' \
    '既定はドライランです。実処理には --execute とroot権限が必要です。'
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
load_config "$config_path"

[[ -n ${PACKAGE_NAME:-} ]] || die 'PACKAGE_NAME は必須です'
[[ -n ${SERVICE_NAME:-} ]] || die 'SERVICE_NAME は必須です'
[[ -n ${WEB_ROOT:-} ]] || die 'WEB_ROOT は必須です'
[[ -n ${SITE_TITLE:-} ]] || die 'SITE_TITLE は必須です'
: "${ALLOWED_TCP_PORTS:=22 80}"
: "${HTTP_PORT:=80}"

[[ $PACKAGE_NAME =~ ^[A-Za-z0-9_.+-]+$ ]] || die "PACKAGE_NAME に使用できない文字があります: $PACKAGE_NAME"
[[ $SERVICE_NAME =~ ^[A-Za-z0-9_.-]+$ ]] || die "SERVICE_NAME に使用できない文字があります: $SERVICE_NAME"
require_absolute_safe_path WEB_ROOT "$WEB_ROOT"
require_integer_range HTTP_PORT "$HTTP_PORT" 1 65535
for port in $ALLOWED_TCP_PORTS; do
  require_integer_range ALLOWED_TCP_PORTS "$port" 1 65535
done

if [[ $execute == true && $(id -u) -ne 0 ]]; then
  die '--execute にはroot権限が必要です（sudoで実行してください）'
fi

require_command apt-get
require_command install
require_command dpkg

warnings=0
log INFO 'Webサーバー構築を開始します'
log INFO "対象パッケージ: $PACKAGE_NAME / サービス名: $SERVICE_NAME / 許可ポート: $ALLOWED_TCP_PORTS"

if dpkg -s -- "$PACKAGE_NAME" >/dev/null 2>&1; then
  log OK "パッケージは導入済みです: $PACKAGE_NAME"
else
  log INFO "パッケージは未導入です。導入します: $PACKAGE_NAME"
fi

run_or_show "$execute" env DEBIAN_FRONTEND=noninteractive apt-get update
run_or_show "$execute" env DEBIAN_FRONTEND=noninteractive apt-get install -y -- "$PACKAGE_NAME"

html_file=$(mktemp)
trap 'rm -f -- "$html_file"' EXIT
cat >"$html_file" <<HTML
<!doctype html>
<html lang="ja">
<head><meta charset="utf-8"><title>${SITE_TITLE}</title></head>
<body>
<h1>${SITE_TITLE}</h1>
<p>このページは provision_web_server.sh が構築しました。</p>
</body>
</html>
HTML
log INFO "配布用サンプルページを準備しました: $WEB_ROOT/index.html"
run_or_show "$execute" install -D -m 0644 -- "$html_file" "$WEB_ROOT/index.html"

if command -v ufw >/dev/null 2>&1; then
  for port in $ALLOWED_TCP_PORTS; do
    run_or_show "$execute" ufw allow "${port}/tcp"
  done
  run_or_show "$execute" ufw --force enable
else
  log WARN 'ufw が見つからないためファイアウォール設定をスキップしました（手動確認が必要）'
  ((warnings += 1))
fi

if [[ $execute == true ]]; then
  if command -v systemctl >/dev/null 2>&1 && systemctl enable --now -- "$SERVICE_NAME" >/dev/null 2>&1; then
    log OK "サービスを有効化して起動しました: $SERVICE_NAME"
  else
    log WARN "systemd経由でのサービス起動に失敗、または未対応の環境です: $SERVICE_NAME（手動起動と自動起動設定を確認してください）"
    ((warnings += 1))
  fi
else
  log INFO "[DRY-RUN] systemctl enable --now $SERVICE_NAME"
fi

if [[ $execute == true ]]; then
  dpkg -s -- "$PACKAGE_NAME" >/dev/null 2>&1 || die "導入確認に失敗しました: $PACKAGE_NAME"
  [[ -s "$WEB_ROOT/index.html" ]] || die "サンプルページを確認できません: $WEB_ROOT/index.html"
  log OK '構築直後の自己確認が完了しました'
else
  log INFO 'ドライラン完了。内容を確認後、検証環境で --execute を指定してください'
fi

if (( warnings > 0 )); then
  log WARN "構築完了: 警告 ${warnings} 件"
  exit "$EXIT_WARNING"
fi
log OK '構築完了: 警告なし'
