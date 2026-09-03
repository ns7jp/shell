#!/usr/bin/env bash
set -Eeuo pipefail

# E01 の採点です。答案 L0/answer.txt の3行が 0 / 1 / 2 かを確かめます。
LAB_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=exercises/lib/lab_common.sh
# shellcheck disable=SC1091
source "$LAB_DIR/lib/lab_common.sh"
# shellcheck source=exercises/lib/assert.sh
# shellcheck disable=SC1091
source "$LAB_DIR/lib/assert.sh"

lab_begin E01
lab_need 'L0/answer.txt'
answer_file=$LAB_PATH

# 全角数字と空白を取り除いてから比べます（見た目が正しければ通します）。
normalized="$LAB_SANDBOX/answer.normalized"
sed -e 's/\r$//' -e 's/０/0/g' -e 's/１/1/g' -e 's/２/2/g' -e 's/[[:space:]]//g' \
  -- "$answer_file" | grep -v '^$' >"$normalized" || true

expected="$LAB_SANDBOX/answer.expected"
printf '%s\n' 0 1 2 >"$expected"

actual_lines=$(wc -l <"$normalized")
assert_equal '行数がちょうど3行' '3' "$actual_lines" "$answer_file"
assert_lines '終了コードが 0 / 1 / 2 の順' "$expected" "$normalized"

lab_finish
