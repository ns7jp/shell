#!/usr/bin/env bash
# E07 模範解答: 無いものは「無い」と言って終了2で止めます。
set -Eeuo pipefail

source "${LAB_COMMON:?LAB_COMMON が未設定です。source \"$HOME/bash-lab/labenv.sh\" を実行してください}"

usage() {
  printf '%s\n' 'Usage: require3.sh --config FILE'
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

# --- 疑う（ある） ----------------------------------------------------------
# ${VAR:-} の :- は「未定義なら空文字として扱う」という意味です。
# これが無いと set -u が先に落ち、終了コードが2ではなく1になります。
[[ -n ${SOURCE_DIR:-} ]] || die 'SOURCE_DIR は必須です'
[[ -n ${BACKUP_DIR:-} ]] || die 'BACKUP_DIR は必須です'
[[ -n ${ARCHIVE_PREFIX:-} ]] || die 'ARCHIVE_PREFIX は必須です'

# --- 伝える ----------------------------------------------------------------
log OK '必須3項目がそろっています'
