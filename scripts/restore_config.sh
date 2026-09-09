#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

usage() {
  printf '%s\n' 'Usage: restore_config.sh --config FILE --snapshot DIR [--execute]' \
    '既定はドライランです。実処理には --execute とroot権限が必要です。' \
    'snapshot_config.sh が作ったスナップショットを元の絶対パスへ復元し、' \
    '復元後にチェックサムを再計算してスナップショットと一致するか確認します。'
}

config_path=''
snapshot_path=''
execute=false
while (($#)); do
  case "$1" in
    --config) [[ $# -ge 2 ]] || die '--config に値が必要です'; config_path=$2; shift 2 ;;
    --snapshot) [[ $# -ge 2 ]] || die '--snapshot に値が必要です'; snapshot_path=$2; shift 2 ;;
    --execute) execute=true; shift ;;
    -h|--help) usage; exit "$EXIT_OK" ;;
    *) die "不明な引数です: $1" ;;
  esac
done
[[ -n $config_path ]] || die '--config は必須です'
[[ -n $snapshot_path ]] || die '--snapshot は必須です'
load_config "$config_path"

[[ -n ${SNAPSHOT_DIR:-} ]] || die 'SNAPSHOT_DIR は必須です'
require_absolute_safe_path SNAPSHOT_DIR "$SNAPSHOT_DIR"
require_absolute_safe_path SNAPSHOT_PATH "$snapshot_path"
[[ $snapshot_path == "$SNAPSHOT_DIR"/* ]] || die "--snapshot は SNAPSHOT_DIR 配下を指定してください: $snapshot_path"

payload_dir="$snapshot_path/payload"
manifest="$snapshot_path/manifest.txt"
[[ -d $payload_dir ]] || die "スナップショットのpayloadが見つかりません: $payload_dir"
[[ -f $manifest ]] || die "スナップショットのmanifest.txtが見つかりません: $manifest"

require_command find
require_command sha256sum

if [[ $execute == true && $(id -u) -ne 0 ]]; then
  die '--execute にはroot権限が必要です（sudoで実行してください）'
fi

log INFO '設定の復元を開始します（スナップショットから元の絶対パスへ書き戻します）'
log INFO "復元元: $snapshot_path"

warnings=0
restored_files=0
mapfile -t files < <(cd -- "$payload_dir" && find . -type f | sed 's#^\./##')
for rel in "${files[@]}"; do
  src="$payload_dir/$rel"
  dest="/$rel"
  run_or_show "$execute" mkdir -p -- "$(dirname -- "$dest")"
  run_or_show "$execute" cp -a -- "$src" "$dest"
  ((restored_files += 1))
done

if [[ $execute == true ]]; then
  log INFO "復元したファイル数: $restored_files"
  log INFO 'スナップショット時点との差分を確認します（チェックサム比較）'
  mismatch=0
  while IFS='  ' read -r expected_hash rel_path; do
    [[ -n $expected_hash && -n $rel_path ]] || continue
    rel_path=${rel_path#./}
    dest="/$rel_path"
    if [[ ! -f $dest ]]; then
      log WARN "復元後のファイルが見つかりません: $dest"
      ((mismatch += 1))
      continue
    fi
    actual_hash=$(sha256sum -- "$dest" | awk '{print $1}')
    if [[ $actual_hash == "$expected_hash" ]]; then
      log OK "スナップショット時点と一致しました: $dest"
    else
      log WARN "スナップショット時点と一致しません: $dest"
      ((mismatch += 1))
    fi
  done <"$manifest"

  if (( mismatch > 0 )); then
    log WARN "復元後の差分確認: 不一致 ${mismatch} 件"
    ((warnings += mismatch))
  else
    log OK '復元後の差分確認: スナップショット時点とすべて一致しました'
  fi
else
  log INFO 'ドライラン完了。内容を確認後、検証環境で --execute を指定してください'
fi

if (( warnings > 0 )); then
  log WARN "復元完了: 警告 ${warnings} 件"
  exit "$EXIT_WARNING"
fi
log OK '復元完了: 警告なし'
