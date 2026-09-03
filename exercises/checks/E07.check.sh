#!/usr/bin/env bash
set -Eeuo pipefail

# E07 の採点です。必須3項目の「ある」検証が書けているかを確かめます。
LAB_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=exercises/lib/lab_common.sh
# shellcheck disable=SC1091
source "$LAB_DIR/lib/lab_common.sh"
# shellcheck source=exercises/lib/assert.sh
# shellcheck disable=SC1091
source "$LAB_DIR/lib/assert.sh"

lab_begin E07
lab_stage 'L2/require3.sh'
script=$LAB_STAGED

# 採点のたびに、設定ファイル4つをここで作ります（問題文の8節で開示しています）。
cat >"$LAB_SANDBOX/all_present.conf" <<'CONF'
SOURCE_DIR=/srv/app
BACKUP_DIR=/var/backups/app
ARCHIVE_PREFIX=app
CONF
cat >"$LAB_SANDBOX/missing_source.conf" <<'CONF'
BACKUP_DIR=/var/backups/app
ARCHIVE_PREFIX=app
CONF
cat >"$LAB_SANDBOX/missing_backup.conf" <<'CONF'
SOURCE_DIR=/srv/app
ARCHIVE_PREFIX=app
CONF
cat >"$LAB_SANDBOX/missing_prefix.conf" <<'CONF'
SOURCE_DIR=/srv/app
BACKUP_DIR=/var/backups/app
CONF
# load_config は他ユーザーから書き込める設定ファイルを拒否します（カード M5）。
chmod 600 -- "$LAB_SANDBOX"/all_present.conf "$LAB_SANDBOX"/missing_source.conf \
  "$LAB_SANDBOX"/missing_backup.conf "$LAB_SANDBOX"/missing_prefix.conf

assert_static '3つの変数名が本文にある' "$script" \
  --must 'SOURCE_DIR' --must 'BACKUP_DIR' --must 'ARCHIVE_PREFIX'

assert_status 'MISSING_SOURCE 終了コード2' 2 -- bash "$script" --config "$LAB_SANDBOX/missing_source.conf"
assert_contains 'MISSING_SOURCE 欠けた変数名 SOURCE_DIR を表示' "$LAB_BOTH" 'SOURCE_DIR'

assert_status 'MISSING_BACKUP 終了コード2' 2 -- bash "$script" --config "$LAB_SANDBOX/missing_backup.conf"
assert_contains 'MISSING_BACKUP 欠けた変数名 BACKUP_DIR を表示' "$LAB_BOTH" 'BACKUP_DIR'

assert_status 'MISSING_PREFIX 終了コード2' 2 -- bash "$script" --config "$LAB_SANDBOX/missing_prefix.conf"
assert_contains 'MISSING_PREFIX 欠けた変数名 ARCHIVE_PREFIX を表示' "$LAB_BOTH" 'ARCHIVE_PREFIX'

assert_status 'ALL_PRESENT 終了コード0' 0 -- bash "$script" --config "$LAB_SANDBOX/all_present.conf"

lab_finish
