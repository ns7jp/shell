#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

usage() {
  printf '%s\n' 'Usage: snapshot_config.sh --config FILE [--label NAME] [--execute]' \
    '既定はドライランです。実処理には --execute が必要です。' \
    'SNAPSHOT_TARGETS に列挙した絶対パスを、SNAPSHOT_DIR配下へタイムスタンプ付きで複製します。'
}

config_path=''
label='change'
execute=false
while (($#)); do
  case "$1" in
    --config) [[ $# -ge 2 ]] || die '--config に値が必要です'; config_path=$2; shift 2 ;;
    --label) [[ $# -ge 2 ]] || die '--label に値が必要です'; label=$2; shift 2 ;;
    --execute) execute=true; shift ;;
    -h|--help) usage; exit "$EXIT_OK" ;;
    *) die "不明な引数です: $1" ;;
  esac
done
[[ -n $config_path ]] || die '--config は必須です'
load_config "$config_path"

[[ -n ${SNAPSHOT_DIR:-} ]] || die 'SNAPSHOT_DIR は必須です'
[[ -n ${SNAPSHOT_TARGETS:-} ]] || die 'SNAPSHOT_TARGETS は必須です'
require_absolute_safe_path SNAPSHOT_DIR "$SNAPSHOT_DIR"
[[ $label =~ ^[A-Za-z0-9_-]{1,64}$ ]] || die "--label に使用できない文字があります: $label"
# 重なりの判定も、'//app' や '/./app' のような別の書き方ですり抜けないよう、正規化してから比べます。
snapshot_dir_normalized=$(normalize_path "$SNAPSHOT_DIR")
for target in $SNAPSHOT_TARGETS; do
  require_absolute_safe_path SNAPSHOT_TARGETS "$target"
  target_normalized=$(normalize_path "$target")
  [[ $snapshot_dir_normalized != "$target_normalized"* && $target_normalized != "$snapshot_dir_normalized"* ]] \
    || die "SNAPSHOT_DIR とSNAPSHOT_TARGETSが重なっています: $target"
done
require_command find
require_command sha256sum

timestamp=$(date '+%Y%m%d_%H%M%S')
snapshot_name="${label}_${timestamp}"
snapshot_path="$SNAPSHOT_DIR/$snapshot_name"
payload_dir="$snapshot_path/payload"

log INFO 'スナップショット作成を開始します（変更前の設定状態を保存します）'
log INFO "保存先: $snapshot_path"

warnings=0
run_or_show "$execute" mkdir -p -- "$payload_dir"

for target in $SNAPSHOT_TARGETS; do
  if [[ -e $target ]]; then
    dest="$payload_dir$target"
    run_or_show "$execute" mkdir -p -- "$(dirname -- "$dest")"
    run_or_show "$execute" cp -a -- "$target" "$dest"
  else
    log WARN "対象が見つかりません（まだ作成されていない可能性）: $target"
    ((warnings += 1))
  fi
done

if [[ $execute == true ]]; then
  {
    for target in $SNAPSHOT_TARGETS; do
      printf '%s\n' "$target"
    done
  } >"$snapshot_path/targets.txt"

  if [[ -n ${PACKAGE_NAME:-} || -n ${SERVICE_NAME:-} ]]; then
    {
      [[ -n ${PACKAGE_NAME:-} ]] && { command -v dpkg >/dev/null 2>&1 && dpkg -s -- "$PACKAGE_NAME" 2>&1 || printf 'PACKAGE_NAME=%s (dpkg未導入または未確認)\n' "$PACKAGE_NAME"; }
      [[ -n ${SERVICE_NAME:-} ]] && { command -v systemctl >/dev/null 2>&1 && systemctl show -p ActiveState,UnitFileState -- "$SERVICE_NAME" 2>&1 || printf 'SERVICE_NAME=%s (systemctl未導入または未確認)\n' "$SERVICE_NAME"; }
    } >"$snapshot_path/meta.txt" || true
  fi

  (cd -- "$payload_dir" && find . -type f -exec sha256sum -- {} \;) >"$snapshot_path/manifest.txt" \
    || die 'マニフェストの作成に失敗しました'

  [[ -s $snapshot_path/manifest.txt || -z $(find "$payload_dir" -type f -print -quit) ]] \
    || die 'マニフェストの内容を確認できません'

  log OK "スナップショットを作成しました: $snapshot_path"
  printf 'SNAPSHOT_PATH=%s\n' "$snapshot_path"
else
  log INFO 'ドライラン完了。内容を確認後、--execute を指定してください'
fi

if (( warnings > 0 )); then
  log WARN "スナップショット完了: 警告 ${warnings} 件"
  exit "$EXIT_WARNING"
fi
log OK 'スナップショット完了: 警告なし'
