#!/usr/bin/env bash
set -Eeuo pipefail

# E09 の採点です。「ある→形→範囲→場所」の順で検証できているかを確かめます。
LAB_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=exercises/lib/lab_common.sh
# shellcheck disable=SC1091
source "$LAB_DIR/lib/lab_common.sh"
# shellcheck source=exercises/lib/assert.sh
# shellcheck disable=SC1091
source "$LAB_DIR/lib/assert.sh"

lab_begin E09
lab_stage 'L2/validate.sh'
script=$LAB_STAGED
reference="$LAB_DIR/answers/E09.ref.sh"

# 採点のたびに、設定ファイル10個をここで作ります（問題文の8節で開示しています）。
cat >"$LAB_SANDBOX/normal.conf" <<'CONF'
SOURCE_DIR=/srv/app
BACKUP_DIR=/var/backups/app
ARCHIVE_PREFIX=app
RETENTION_DAYS=7
CONF
cat >"$LAB_SANDBOX/missing_source.conf" <<'CONF'
BACKUP_DIR=/var/backups/app
ARCHIVE_PREFIX=app
RETENTION_DAYS=7
CONF
cat >"$LAB_SANDBOX/missing_backup.conf" <<'CONF'
SOURCE_DIR=/srv/app
ARCHIVE_PREFIX=app
RETENTION_DAYS=7
CONF
cat >"$LAB_SANDBOX/missing_prefix.conf" <<'CONF'
SOURCE_DIR=/srv/app
BACKUP_DIR=/var/backups/app
RETENTION_DAYS=7
CONF
cat >"$LAB_SANDBOX/bad_format.conf" <<'CONF'
SOURCE_DIR=/srv/app
BACKUP_DIR=/var/backups/app
ARCHIVE_PREFIX='app backup'
RETENTION_DAYS=7
CONF
cat >"$LAB_SANDBOX/out_of_range.conf" <<'CONF'
SOURCE_DIR=/srv/app
BACKUP_DIR=/var/backups/app
ARCHIVE_PREFIX=app
RETENTION_DAYS=5000
CONF
cat >"$LAB_SANDBOX/system_dir.conf" <<'CONF'
SOURCE_DIR=/etc
BACKUP_DIR=/var/backups/app
ARCHIVE_PREFIX=app
RETENTION_DAYS=7
CONF
cat >"$LAB_SANDBOX/nested.conf" <<'CONF'
SOURCE_DIR=/srv/app
BACKUP_DIR=/srv/app/backups
ARCHIVE_PREFIX=app
RETENTION_DAYS=7
CONF
cat >"$LAB_SANDBOX/relative.conf" <<'CONF'
SOURCE_DIR=srv/app
BACKUP_DIR=/var/backups/app
ARCHIVE_PREFIX=app
RETENTION_DAYS=7
CONF
cat >"$LAB_SANDBOX/dotdot.conf" <<'CONF'
SOURCE_DIR=/srv/../etc/app
BACKUP_DIR=/var/backups/app
ARCHIVE_PREFIX=app
RETENTION_DAYS=7
CONF
# load_config は他ユーザーから書き込める設定ファイルを拒否します（カード M5）。
chmod 600 -- "$LAB_SANDBOX"/normal.conf "$LAB_SANDBOX"/missing_source.conf \
  "$LAB_SANDBOX"/missing_backup.conf "$LAB_SANDBOX"/missing_prefix.conf \
  "$LAB_SANDBOX"/bad_format.conf "$LAB_SANDBOX"/out_of_range.conf \
  "$LAB_SANDBOX"/system_dir.conf "$LAB_SANDBOX"/nested.conf \
  "$LAB_SANDBOX"/relative.conf "$LAB_SANDBOX"/dotdot.conf

assert_static '危ない書き方が無い（eval と rm -rf を書かない）' "$script" \
  --must-not 'eval' --must-not 'rm -rf'

# 終了コードは10ケースとも模範解答と突き合わせます。日本語の言い回しでは落ちません。
assert_ref_status 'NORMAL 模範解答と同じ終了コード' "$script" "$reference" -- --config "$LAB_SANDBOX/normal.conf"
assert_ref_status 'MISSING_SOURCE 模範解答と同じ終了コード' "$script" "$reference" -- --config "$LAB_SANDBOX/missing_source.conf"
assert_ref_status 'MISSING_BACKUP 模範解答と同じ終了コード' "$script" "$reference" -- --config "$LAB_SANDBOX/missing_backup.conf"
assert_ref_status 'MISSING_PREFIX 模範解答と同じ終了コード' "$script" "$reference" -- --config "$LAB_SANDBOX/missing_prefix.conf"
assert_ref_status 'BAD_FORMAT 模範解答と同じ終了コード' "$script" "$reference" -- --config "$LAB_SANDBOX/bad_format.conf"
assert_ref_status 'OUT_OF_RANGE 模範解答と同じ終了コード' "$script" "$reference" -- --config "$LAB_SANDBOX/out_of_range.conf"
assert_ref_status 'NESTED 模範解答と同じ終了コード' "$script" "$reference" -- --config "$LAB_SANDBOX/nested.conf"

# 次の3ケースだけ、実測済みの拒否理由も見ます（カード M1 / M2 / M3）。
assert_ref_status 'SYSTEM_DIR 模範解答と同じ終了コード' "$script" "$reference" -- --config "$LAB_SANDBOX/system_dir.conf"
assert_contains 'SYSTEM_DIR の理由が「重要なシステムディレクトリ」' "$LAB_BOTH" '重要なシステムディレクトリ'

assert_ref_status 'RELATIVE 模範解答と同じ終了コード' "$script" "$reference" -- --config "$LAB_SANDBOX/relative.conf"
assert_contains 'RELATIVE の理由が「空でない絶対パス」' "$LAB_BOTH" '空でない絶対パス'

assert_ref_status 'DOTDOT 模範解答と同じ終了コード' "$script" "$reference" -- --config "$LAB_SANDBOX/dotdot.conf"
assert_contains 'DOTDOT の理由が「.. は使用できません」' "$LAB_BOTH" '.. は使用できません'

lab_finish
