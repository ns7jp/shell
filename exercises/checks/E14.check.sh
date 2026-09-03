#!/usr/bin/env bash
set -Eeuo pipefail

# E14 の採点です。壊れた実装のときに落ちるテストになっているかを確かめます。
LAB_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=exercises/lib/lab_common.sh
# shellcheck disable=SC1091
source "$LAB_DIR/lib/lab_common.sh"
# shellcheck source=exercises/lib/assert.sh
# shellcheck disable=SC1091
source "$LAB_DIR/lib/assert.sh"

lab_begin E14
lab_stage 'L4/my_tests.sh'
script=$LAB_STAGED

# 仕掛け: 被テストスクリプトを2本用意し、TARGET_SCRIPT で差し替えます
# （問題文の8節で開示しています）。
# リポジトリ内の実ファイルを直接渡すと、学習者のテストがリポジトリへ書き込めてしまいます。
# 必ずサンドボックスへ複製してから渡します。
good="$LAB_SANDBOX/target_good.sh"
bad="$LAB_SANDBOX/target_bad.sh"
cp -- "$LAB_DIR/answers/E12.ref.sh" "$good"
cp -- "$LAB_DIR/answers/wrong/E12.wrong" "$bad"

assert_static 'パスを直書きせず TARGET_SCRIPT から受けている' "$script" \
  --must 'TARGET_SCRIPT' --must-not '^[^#]*__[0-9]__'

# --- (a) 正しい実装に当てる ------------------------------------------------
lab_run_env "TARGET_SCRIPT=$good" -- bash "$script"
good_status=$LAB_STATUS
good_ok=$(grep -c '^ok - ' "$LAB_STDOUT" || true)
good_not_ok=$(grep -c '^not ok' "$LAB_STDOUT" || true)

assert_equal 'GOOD 終了コード0' '0' "$good_status" "$script"
assert_equal 'GOOD not ok が0件' '0' "$good_not_ok" "$LAB_STDOUT"
if ((good_ok >= 3)); then
  lab_ok 'GOOD ok 行が3件以上（3ケースを検査している）'
else
  lab_not_ok 'GOOD ok 行が3件以上（3ケースを検査している）' "$LAB_STDOUT" \
    'ok - で始まる行が3件以上' "${good_ok} 件" \
    'ドライラン・--execute・不明引数の3ケース分の判定'
fi

# --- (b) わざと壊した実装に当てる（仕掛け: CANNOT_FAIL） --------------------
lab_run_env "TARGET_SCRIPT=$bad" -- bash "$script"
bad_status=$LAB_STATUS
bad_not_ok=$(grep -c '^not ok' "$LAB_STDOUT" || true)

if ((bad_not_ok >= 1)); then
  lab_ok 'CANNOT_FAIL 壊れた実装で not ok を出す'
else
  lab_not_ok 'CANNOT_FAIL 壊れた実装で not ok を出す' \
    "$LAB_STDOUT（この失敗は採点器の仕掛け（CANNOT_FAIL）のケースです）" \
    'not ok で始まる行が1件以上' "${bad_not_ok} 件" \
    'ドライランのあとに --dst ができていないことを確かめるケース'
fi
if ((bad_status >= 1 && bad_status != 124)); then
  lab_ok 'CANNOT_FAIL 壊れた実装で終了コード1以上'
else
  lab_not_ok 'CANNOT_FAIL 壊れた実装で終了コード1以上' \
    "$script（この失敗は採点器の仕掛け（CANNOT_FAIL）のケースです）" \
    '終了コード1以上' "終了コード $bad_status" \
    '不合格が1件でもあれば0以外で終わる最後の行'
fi

lab_finish
