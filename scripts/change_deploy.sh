#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

usage() {
  printf '%s\n' 'Usage: change_deploy.sh --config FILE --source DIR [--execute]' \
    '既定はドライランです。実処理には --execute とroot権限が必要です。' \
    '1) 変更前スナップショット 2) 変更の適用 3) 検証ゲート(VERIFY_CMD)の実行' \
    '4) 検証が失敗した場合は自動的にスナップショットへ切戻します。'
}

config_path=''
source_path=''
execute=false
while (($#)); do
  case "$1" in
    --config) [[ $# -ge 2 ]] || die '--config に値が必要です'; config_path=$2; shift 2 ;;
    --source) [[ $# -ge 2 ]] || die '--source に値が必要です'; source_path=$2; shift 2 ;;
    --execute) execute=true; shift ;;
    -h|--help) usage; exit "$EXIT_OK" ;;
    *) die "不明な引数です: $1" ;;
  esac
done
[[ -n $config_path ]] || die '--config は必須です'
[[ -n $source_path ]] || die '--source は必須です'
load_config "$config_path"

[[ -n ${SNAPSHOT_DIR:-} ]] || die 'SNAPSHOT_DIR は必須です'
[[ -n ${SNAPSHOT_TARGETS:-} ]] || die 'SNAPSHOT_TARGETS は必須です'
[[ -n ${CHANGE_TARGET:-} ]] || die 'CHANGE_TARGET は必須です'
[[ -n ${VERIFY_CMD:-} ]] || die 'VERIFY_CMD は必須です'
require_absolute_safe_path SNAPSHOT_DIR "$SNAPSHOT_DIR"
require_absolute_safe_path CHANGE_TARGET "$CHANGE_TARGET"
[[ -d $source_path ]] || die "--source はディレクトリで指定してください: $source_path"
match=false
for target in $SNAPSHOT_TARGETS; do
  [[ $target == "$CHANGE_TARGET" ]] && match=true
done
[[ $match == true ]] || die 'SNAPSHOT_TARGETS に CHANGE_TARGET を含めてください（変更対象を切戻せなくなります）'

if [[ $execute == true && $(id -u) -ne 0 ]]; then
  die '--execute にはroot権限が必要です（sudoで実行してください）'
fi

require_command cp

log INFO '変更適用フローを開始します（1: スナップショット / 2: 適用 / 3: 検証ゲート / 4: 失敗時は自動切戻し）'
log INFO "変更対象: $CHANGE_TARGET / 変更元: $source_path"

## 1. 変更前スナップショット -------------------------------------------------
snapshot_args=(--config "$config_path" --label pre-change)
[[ $execute == true ]] && snapshot_args+=(--execute)
snapshot_output=$(bash "$SCRIPT_DIR/snapshot_config.sh" "${snapshot_args[@]}") || die 'スナップショットの作成に失敗しました'
printf '%s\n' "$snapshot_output"
snapshot_path=$(grep -o 'SNAPSHOT_PATH=.*' <<<"$snapshot_output" | head -n1 | cut -d= -f2-) || true

if [[ $execute == true ]]; then
  [[ -n $snapshot_path ]] || die 'スナップショットの保存先を確認できませんでした'
  log OK "変更前スナップショット: $snapshot_path"
fi

## 2. 変更の適用（追加・上書きのみ。削除の反映は行いません） -----------------------
run_or_show "$execute" mkdir -p -- "$CHANGE_TARGET"
run_or_show "$execute" cp -a -- "$source_path/." "$CHANGE_TARGET/"

if [[ $execute != true ]]; then
  log INFO "[DRY-RUN] 検証ゲート: $VERIFY_CMD"
  log INFO 'ドライラン完了。内容を確認後、検証環境で --execute を指定してください'
  exit "$EXIT_OK"
fi

## 3. 検証ゲート（go/no-go） -------------------------------------------------
log INFO "検証ゲートを実行します: $VERIFY_CMD"
verify_output=$(bash -c -- "$VERIFY_CMD" 2>&1) && verify_status=0 || verify_status=$?
printf '%s\n' "$verify_output"

case $verify_status in
  0)
    log OK '検証ゲートに合格しました。変更を確定します'
    log INFO "切戻しが必要な場合は次を実行してください: restore_config.sh --config $config_path --snapshot $snapshot_path --execute"
    exit "$EXIT_OK"
    ;;
  1)
    log WARN '検証ゲートが警告を報告しました。自動切戻しは行いません（人による go/no-go 判断が必要です）'
    log WARN "切戻すには次を実行してください: restore_config.sh --config $config_path --snapshot $snapshot_path --execute"
    exit "$EXIT_WARNING"
    ;;
  *)
    log ERROR "検証ゲートが失敗しました（終了コード${verify_status}）。自動的にスナップショットへ切戻します"
    if bash "$SCRIPT_DIR/restore_config.sh" --config "$config_path" --snapshot "$snapshot_path" --execute; then
      log OK "自動切戻しが完了しました: $snapshot_path"
    else
      log ERROR "自動切戻しに失敗しました。手動で復旧してください: $snapshot_path"
    fi
    exit "$EXIT_ERROR"
    ;;
esac
