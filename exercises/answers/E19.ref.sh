#!/usr/bin/env bash
# E19 模範解答: 骨9要素を1番から9番へ順に並べた、小さな backup.sh です。
# 受ける → 疑う → 動かす → 確かめる → 伝える の順に読めるようにします。

# --- 2/9 安全設定 -----------------------------------------------------------
set -Eeuo pipefail

# --- 3/9 共通ライブラリ読込 -------------------------------------------------
source "${LAB_COMMON:?LAB_COMMON が未設定です。source \"$HOME/bash-lab/labenv.sh\" を実行してください}"

# --- 4/9 usage ------------------------------------------------ ここまで「受ける」
usage() {
  printf '%s\n' 'Usage: mini_backup.sh --config FILE [--execute]' \
    '既定はドライランです。実処理には --execute が必要です。'
}

# --- 5/9 引数解析 -------------------------------------------------- 「受ける」
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

# --- 6/9 入力検証（ある→形→範囲→場所） ---------------------------- 「疑う」
[[ -n $config_path ]] || die '--config は必須です'
load_config "$config_path"
[[ -n ${SOURCE_DIR:-} ]] || die 'SOURCE_DIR は必須です'
[[ -n ${BACKUP_DIR:-} ]] || die 'BACKUP_DIR は必須です'
: "${RETENTION_DAYS:=7}"
: "${ARCHIVE_PREFIX:=backup}"
[[ $ARCHIVE_PREFIX =~ ^[A-Za-z0-9._-]+$ ]] || die 'ARCHIVE_PREFIX に使用できない文字があります'
require_integer_range RETENTION_DAYS "$RETENTION_DAYS" 1 3650
require_absolute_safe_path SOURCE_DIR "$SOURCE_DIR"
require_absolute_safe_path BACKUP_DIR "$BACKUP_DIR"
[[ $SOURCE_DIR != "$BACKUP_DIR" && $BACKUP_DIR != "$SOURCE_DIR"/* ]] \
  || die '保存先をバックアップ元の配下に置くことはできません'
[[ -d $SOURCE_DIR && -r $SOURCE_DIR ]] || die "バックアップ元を読み取れません: $SOURCE_DIR"
require_command tar

# --- 7/9 ドライラン既定の処理 ------------------------------------- 「動かす」
# 世代を残すので、アーカイブ名には日時を付けます。
archive_name="${ARCHIVE_PREFIX}_$(date '+%Y%m%d_%H%M%S').tar.gz"
archive_path="$BACKUP_DIR/$archive_name"
log INFO "バックアップ元: $SOURCE_DIR"
log INFO "保存先: $archive_path"
run_or_show "$execute" mkdir -p -- "$BACKUP_DIR"
run_or_show "$execute" tar -C "$(dirname "$SOURCE_DIR")" -czf "$archive_path" -- "$(basename "$SOURCE_DIR")"

# --- 8/9 成果物の確認 ------------------------------------------- 「確かめる」
if [[ $execute != true ]]; then
  # --- 9/9 ログと終了コード --------------------------------------- 「伝える」
  log INFO 'ドライラン完了。内容を確認後、検証環境で --execute を指定してください'
  exit "$EXIT_OK"
fi
[[ -s $archive_path ]] || die "アーカイブを確認できません: $archive_path"
tar -tzf "$archive_path" >/dev/null || die 'アーカイブの整合性確認に失敗しました'

# --- 9/9 ログと終了コード ----------------------------------------- 「伝える」
log OK "バックアップと整合性確認が完了しました: $archive_path"
exit "$EXIT_OK"
