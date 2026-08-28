#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

usage() {
  printf '%s\n' 'Usage: backup.sh --config FILE [--execute]' '既定はドライランです。実処理には --execute が必要です。'
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
[[ -n ${SOURCE_DIR:-} ]] || die 'SOURCE_DIR は必須です'
[[ -n ${BACKUP_DIR:-} ]] || die 'BACKUP_DIR は必須です'
: "${RETENTION_DAYS:=7}"
: "${ARCHIVE_PREFIX:=backup}"
require_absolute_safe_path SOURCE_DIR "$SOURCE_DIR"
require_absolute_safe_path BACKUP_DIR "$BACKUP_DIR"
[[ $SOURCE_DIR != "$BACKUP_DIR" && $BACKUP_DIR != "$SOURCE_DIR"/* ]] || die '保存先をバックアップ元の配下に置くことはできません'
require_integer_range RETENTION_DAYS "$RETENTION_DAYS" 1 3650
[[ $ARCHIVE_PREFIX =~ ^[A-Za-z0-9._-]+$ ]] || die 'ARCHIVE_PREFIX に使用できない文字があります'
[[ -d $SOURCE_DIR && -r $SOURCE_DIR ]] || die "バックアップ元を読み取れません: $SOURCE_DIR"
require_command tar
require_command find

archive_name="${ARCHIVE_PREFIX}_$(date '+%Y%m%d_%H%M%S').tar.gz"
archive_path="$BACKUP_DIR/$archive_name"
log INFO "バックアップ元: $SOURCE_DIR"
log INFO "保存先: $archive_path"
run_or_show "$execute" mkdir -p -- "$BACKUP_DIR"
run_or_show "$execute" tar -C "$(dirname "$SOURCE_DIR")" -czf "$archive_path" -- "$(basename "$SOURCE_DIR")"
run_or_show "$execute" find "$BACKUP_DIR" -maxdepth 1 -type f -name "${ARCHIVE_PREFIX}_*.tar.gz" -mtime "+$RETENTION_DAYS" -delete

if [[ $execute == true ]]; then
  [[ -s $archive_path ]] || die "アーカイブを確認できません: $archive_path"
  tar -tzf "$archive_path" >/dev/null || die 'アーカイブの整合性確認に失敗しました'
  log OK "バックアップと整合性確認が完了しました: $archive_path"
else
  log INFO 'ドライラン完了。内容を確認後、検証環境で --execute を指定してください'
fi
