#!/usr/bin/env bash
# 不足の説明文に書いた単一引用符の中の $ は、展開せずそのまま見せる文字列です。
# shellcheck disable=SC2016
set -Eeuo pipefail

# E19 の採点です。tests/run_tests.sh の backup 相当5ケースを、対象スクリプトだけ
# 学習者のものに差し替えてサンドボックスで実行します。
LAB_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=exercises/lib/lab_common.sh
# shellcheck disable=SC1091
source "$LAB_DIR/lib/lab_common.sh"
# shellcheck source=exercises/lib/assert.sh
# shellcheck disable=SC1091
source "$LAB_DIR/lib/assert.sh"

lab_begin E19
lab_stage 'L6/mini_backup.sh'
script=$LAB_STAGED

# 教材は採点のたびにその場で作ります（問題文の8節で開示しています）。
source_dir="$LAB_SANDBOX/source"
backup_dir="$LAB_SANDBOX/backups"
mkdir -p -- "$source_dir" "$backup_dir"
printf 'test data\n' >"$source_dir/data.txt"

write_config() {
  local path=$1
  shift
  printf '%s\n' "$@" >"$path"
  chmod 600 -- "$path"
}

write_config "$LAB_SANDBOX/ok.conf" \
  "SOURCE_DIR=$source_dir" "BACKUP_DIR=$backup_dir" 'RETENTION_DAYS=7' 'ARCHIVE_PREFIX=test'
write_config "$LAB_SANDBOX/unsafe.conf" \
  'SOURCE_DIR=/proc' "BACKUP_DIR=$LAB_SANDBOX/backups-unsafe" 'RETENTION_DAYS=7' 'ARCHIVE_PREFIX=test'
write_config "$LAB_SANDBOX/missing.conf" \
  "BACKUP_DIR=$backup_dir" 'RETENTION_DAYS=7' 'ARCHIVE_PREFIX=test'
write_config "$LAB_SANDBOX/nested.conf" \
  "SOURCE_DIR=$source_dir" "BACKUP_DIR=$source_dir/backups" 'RETENTION_DAYS=7' 'ARCHIVE_PREFIX=test'

# 1ケース1判定にして、「5件中n件通過」が読めるようにします。
judge() {
  local name=$1 verdict=$2 where=$3 expected=$4 actual=$5 advice=$6
  if [[ $verdict == true ]]; then
    lab_ok "$name"
  else
    lab_not_ok "$name" "$where" "$expected" "$actual" "$advice"
  fi
}

# --- (1) ドライラン ---------------------------------------------------------
lab_run bash "$script" --config "$LAB_SANDBOX/ok.conf"
dry_status=$LAB_STATUS
dry_head=$(lab_head "$LAB_BOTH")
dry_created=$(find "$backup_dir" -type f -print -quit 2>/dev/null || true)
dry_visible=false
if grep -Fq '[DRY-RUN]' "$LAB_BOTH"; then dry_visible=true; fi
dry_ok=false
if [[ $dry_status == 0 && -z $dry_created && $dry_visible == true ]]; then dry_ok=true; fi
judge '(1) ドライランは終了0で予定を見せ、保存先にファイルを作らない' "$dry_ok" \
  "$script --config ok.conf" '終了コード 0 かつ [DRY-RUN] の表示あり かつ 保存先にファイルなし' \
  "終了コード $dry_status / [DRY-RUN] $dry_visible / 保存先 $([[ -z $dry_created ]] && printf 'ファイルなし' || printf 'ファイルあり')（$dry_head）" \
  '変更するコマンドをすべて run_or_show "$execute" 経由にすること'

# --- (2) --execute ----------------------------------------------------------
lab_run bash "$script" --config "$LAB_SANDBOX/ok.conf" --execute
run_status=$LAB_STATUS
run_head=$(lab_head "$LAB_BOTH")
archive=$(find "$backup_dir" -type f -name 'test_*.tar.gz' -print -quit 2>/dev/null || true)
listing="$LAB_SANDBOX/.listing"
: >"$listing"
if [[ -n $archive ]]; then tar -tzf "$archive" >"$listing" 2>/dev/null || true; fi
run_ok=false
if [[ $run_status == 0 ]] && grep -Fq 'source/data.txt' "$listing"; then run_ok=true; fi
judge '(2) --execute は終了0で、アーカイブに source/data.txt が入る' "$run_ok" \
  "$script --config ok.conf --execute" '終了コード 0 かつ tar -tzf の出力に source/data.txt' \
  "終了コード $run_status / 中身 $(tr '\n' ' ' <"$listing" | cut -c1-80)（$run_head）" \
  'tar -C "$(dirname "$SOURCE_DIR")" -czf "$archive_path" -- "$(basename "$SOURCE_DIR")" の形'

# --- (3) 危険なバックアップ元 -----------------------------------------------
lab_run bash "$script" --config "$LAB_SANDBOX/unsafe.conf"
unsafe_status=$LAB_STATUS
unsafe_head=$(lab_head "$LAB_BOTH")
unsafe_ok=false
if [[ $unsafe_status == 2 ]] && grep -Fq '重要なシステムディレクトリ' "$LAB_BOTH"; then unsafe_ok=true; fi
judge '(3) SOURCE_DIR=/ は終了2で拒否し、理由を表示する' "$unsafe_ok" \
  "$script --config unsafe.conf" '終了コード 2 かつ「重要なシステムディレクトリ」を含む出力' \
  "終了コード $unsafe_status（$unsafe_head）" \
  'require_absolute_safe_path SOURCE_DIR "$SOURCE_DIR" の呼び出し'

# --- (4) 必須項目の欠落 -----------------------------------------------------
lab_run bash "$script" --config "$LAB_SANDBOX/missing.conf"
missing_status=$LAB_STATUS
missing_head=$(lab_head "$LAB_BOTH")
missing_ok=false
if [[ $missing_status == 2 ]] && grep -Fq 'SOURCE_DIR' "$LAB_BOTH"; then missing_ok=true; fi
judge '(4) SOURCE_DIR 未定義は終了2で拒否し、項目名を表示する' "$missing_ok" \
  "$script --config missing.conf" '終了コード 2 かつ SOURCE_DIR という文字列を含む出力' \
  "終了コード $missing_status（$missing_head）" \
  '「ある」を最初に確かめる [[ -n ${SOURCE_DIR:-} ]] || die の行'

# --- (5) 保存先がバックアップ元の配下 ---------------------------------------
lab_run bash "$script" --config "$LAB_SANDBOX/nested.conf"
nested_status=$LAB_STATUS
nested_head=$(lab_head "$LAB_BOTH")
nested_ok=false
if [[ $nested_status == 2 ]]; then nested_ok=true; fi
judge '(5) BACKUP_DIR がバックアップ元の配下なら終了2で拒否する' "$nested_ok" \
  "$script --config nested.conf" '終了コード 2' \
  "終了コード $nested_status（$nested_head）" \
  '$BACKUP_DIR が "$SOURCE_DIR"/* でないことを確かめる行'

lab_finish
