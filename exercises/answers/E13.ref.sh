#!/usr/bin/env bash
# E13 模範解答: tar のあとに「ある・中身」を必ず読み直します。
set -Eeuo pipefail

source "${LAB_COMMON:?LAB_COMMON が未設定です。source \"$HOME/bash-lab/labenv.sh\" を実行してください}"

usage() {
  printf '%s\n' 'Usage: mkarc.sh --src DIR --dst DIR' 'DIR を tar.gz にまとめ、作った後に読み直します。'
}

# --- 受ける ----------------------------------------------------------------
src=''
dst=''
while (($#)); do
  case "$1" in
    --src) [[ $# -ge 2 ]] || die '--src に値が必要です'; src=$2; shift 2 ;;
    --dst) [[ $# -ge 2 ]] || die '--dst に値が必要です'; dst=$2; shift 2 ;;
    -h|--help) usage; exit "$EXIT_OK" ;;
    *) die "不明な引数です: $1" ;;
  esac
done

# --- 疑う ------------------------------------------------------------------
[[ -n $src ]] || die '--src は必須です'
[[ -n $dst ]] || die '--dst は必須です'
require_absolute_safe_path SRC "$src"
require_absolute_safe_path DST "$dst"
[[ -d $src && -r $src ]] || die "アーカイブ元を読み取れません: $src"
require_command tar

# --- 動かす ----------------------------------------------------------------
archive="$dst/$(basename -- "$src").tar.gz"
log INFO "アーカイブ元: $src"
log INFO "保存先: $archive"
mkdir -p -- "$dst"
tar -C "$(dirname -- "$src")" -czf "$archive" -- "$(basename -- "$src")"

# --- 確かめる（scripts/backup.sh の46〜47行と同じ2行） ----------------------
[[ -s $archive ]] || die "アーカイブを確認できません: $archive"
tar -tzf "$archive" >/dev/null || die 'アーカイブの整合性確認に失敗しました'

# --- 伝える ----------------------------------------------------------------
log OK "アーカイブを作成し、読み直しました: $archive"
