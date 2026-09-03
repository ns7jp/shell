#!/usr/bin/env bash
set -Eeuo pipefail

# E16 の採点です。警告の数から 0 / 1 / 2 を出し分けているかを確かめます。
LAB_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=exercises/lib/lab_common.sh
# shellcheck disable=SC1091
source "$LAB_DIR/lib/lab_common.sh"
# shellcheck source=exercises/lib/assert.sh
# shellcheck disable=SC1091
source "$LAB_DIR/lib/assert.sh"

lab_begin E16
lab_stage 'L5/report.sh'
script=$LAB_STAGED

# 採点のたびに3つの状況をここで作ります（問題文の8節で開示しています）。
mkdir -p -- "$LAB_SANDBOX/site"
printf 'a\n' >"$LAB_SANDBOX/site/a.txt"
printf 'b\n' >"$LAB_SANDBOX/site/b.txt"

printf '%s\n' "TARGET_DIR='$LAB_SANDBOX/site'" "CHECK_FILES='a.txt b.txt'" >"$LAB_SANDBOX/ok.conf"
printf '%s\n' "TARGET_DIR='$LAB_SANDBOX/site'" "CHECK_FILES='a.txt missing1.txt missing2.txt'" >"$LAB_SANDBOX/warn.conf"
printf '%s\n' "TARGET_DIR='site'" "CHECK_FILES='a.txt'" >"$LAB_SANDBOX/bad.conf"
chmod 600 -- "$LAB_SANDBOX/ok.conf" "$LAB_SANDBOX/warn.conf" "$LAB_SANDBOX/bad.conf"

# 1 の直書きを禁じます。この検査だけは本文を静的に見ます（8節で開示しています）。
# ケース名の中の $EXIT_WARNING は説明用の文字列です（展開しません）。
# shellcheck disable=SC2016
assert_static 'HARDCODED_EXIT 定数 $EXIT_WARNING を使い exit 1 と直書きしない' "$script" \
  --must 'EXIT_WARNING' --must-not 'exit[[:space:]]+1'

# 最終行だけを取り出します。日時は <TS> に伏せるので、比べるのはレベル語と件数だけです。
last_line_of() {
  local destination=$1
  grep -v '^[[:space:]]*$' "$LAB_STDOUT" | tail -n 1 | lab_normalize >"$destination" || true
}

# --- (1) 警告0 -------------------------------------------------------------
lab_run bash "$script" --config "$LAB_SANDBOX/ok.conf"
assert_equal 'OK_CASE 終了コード0' '0' "$LAB_STATUS" "$script --config ok.conf"
last_line_of "$LAB_SANDBOX/.last_ok"
assert_contains 'OK_CASE 最終行が [OK]' "$LAB_SANDBOX/.last_ok" '[OK]'

# --- (2) 警告2件 -----------------------------------------------------------
lab_run bash "$script" --config "$LAB_SANDBOX/warn.conf"
assert_equal 'WARN_CASE 終了コード1' '1' "$LAB_STATUS" "$script --config warn.conf"
last_line_of "$LAB_SANDBOX/.last_warn"
assert_contains 'WARN_CASE 最終行が [WARN]' "$LAB_SANDBOX/.last_warn" '[WARN]'
assert_contains 'WARN_CASE 最終行に件数 2 が入る' "$LAB_SANDBOX/.last_warn" '2'

# --- (3) 設定不正 ----------------------------------------------------------
assert_status 'BAD_CONFIG 終了コード2' 2 -- bash "$script" --config "$LAB_SANDBOX/bad.conf"

lab_finish
