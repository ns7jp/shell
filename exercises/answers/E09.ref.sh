#!/usr/bin/env bash
# E09 模範解答: 疑う順は「ある→形→範囲→場所」です。順番を変えません。
set -Eeuo pipefail

source "${LAB_COMMON:?LAB_COMMON が未設定です。source \"$HOME/bash-lab/labenv.sh\" を実行してください}"

usage() {
  printf '%s\n' 'Usage: validate.sh --config FILE'
}

# --- 受ける ----------------------------------------------------------------
config_path=''
while (($#)); do
  case "$1" in
    --config) [[ $# -ge 2 ]] || die '--config に値が必要です'; config_path=$2; shift 2 ;;
    -h|--help) usage; exit "$EXIT_OK" ;;
    *) die "不明な引数です: $1" ;;
  esac
done
[[ -n $config_path ]] || die '--config は必須です'
load_config "$config_path"

# --- 疑う 1/4 ある ---------------------------------------------------------
[[ -n ${SOURCE_DIR:-} ]] || die 'SOURCE_DIR は必須です'
[[ -n ${BACKUP_DIR:-} ]] || die 'BACKUP_DIR は必須です'
[[ -n ${ARCHIVE_PREFIX:-} ]] || die 'ARCHIVE_PREFIX は必須です'
: "${RETENTION_DAYS:=7}"

# --- 疑う 2/4 形 -----------------------------------------------------------
[[ $ARCHIVE_PREFIX =~ ^[A-Za-z0-9._-]+$ ]] || die 'ARCHIVE_PREFIX に使用できない文字があります'

# --- 疑う 3/4 範囲 ---------------------------------------------------------
require_integer_range RETENTION_DAYS "$RETENTION_DAYS" 1 3650

# --- 疑う 4/4 場所 ---------------------------------------------------------
require_absolute_safe_path SOURCE_DIR "$SOURCE_DIR"
require_absolute_safe_path BACKUP_DIR "$BACKUP_DIR"
[[ $BACKUP_DIR != "$SOURCE_DIR" && $BACKUP_DIR != "$SOURCE_DIR"/* ]] || die '保存先をバックアップ元の配下に置くことはできません'

# --- 伝える ----------------------------------------------------------------
log OK '設定はすべての検証を通りました'
exit "$EXIT_OK"
