#!/usr/bin/env bash
set -Eeuo pipefail

# E18 の採点です。証跡テンプレートの9項目の順と、判定の切り替わりを確かめます。
LAB_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=exercises/lib/lab_common.sh
# shellcheck disable=SC1091
source "$LAB_DIR/lib/lab_common.sh"
# shellcheck source=exercises/lib/assert.sh
# shellcheck disable=SC1091
source "$LAB_DIR/lib/assert.sh"

lab_begin E18
lab_stage 'L5/evidence.sh'
script=$LAB_STAGED

# docs/05-test-plan.md の証跡テンプレートの9項目です。
# 見るのは行頭のラベルだけで、コロンから右の本文は一切比べません。
labels=('^テストID' '^日時' '^実行者' '^環境' '^実行コマンド' '^期待結果' '^実結果' '^終了コード' '^判定')
names=('テストID' '日時・タイムゾーン' '実行者' '環境' '実行コマンド' '期待結果' '実結果' '終了コード' '判定')

# --- (1) --status 0 で実行し、9項目の順を見ます ----------------------------
assert_status '--status 0 で終了コード0' 0 -- bash "$script" --status 0
pass_output="$LAB_SANDBOX/.out_status0"
cp -- "$LAB_STDOUT" "$pass_output"

previous=0
index=0
for pattern in "${labels[@]}"; do
  index=$((index + 1))
  case_name="${index}/9 ラベル「${names[$((index - 1))]}」がテンプレートの順にある"
  line_number=$(grep -n -m1 -E -- "$pattern" "$pass_output" | cut -d: -f1) || line_number=''
  if [[ -z $line_number ]]; then
    lab_not_ok "$case_name" "$pass_output" "「${names[$((index - 1))]}」で始まる行" \
      '見つかりません' 'docs/05-test-plan.md の証跡テンプレートの9項目'
    continue
  fi
  if ((line_number > previous)); then
    previous=$line_number
    lab_ok "$case_name"
  else
    lab_not_ok "$case_name" "$pass_output" "${previous} 行目より後ろに出ること" \
      "${line_number} 行目に出ました" 'テンプレートと同じ並び順'
  fi
done

# --- (2) 判定は終了コードから導きます（固定文字列は落ちます） ---------------
# 判定行のうち、最初のコロンから右だけを取り出します。
# ラベル「判定(PASS/FAIL/NOT RUN):」自体に PASS と FAIL が含まれるためです。
verdict_value() {
  local source_file=$1 destination=$2 line='' value=''
  line=$(grep -m1 -E '^判定' -- "$source_file") || line=''
  value=${line#*:}
  value=${value#*：}
  printf '%s\n' "$value" >"$destination"
}

verdict_value "$pass_output" "$LAB_SANDBOX/.verdict0"
assert_contains 'HARDCODED_VERDICT --status 0 の判定が PASS' "$LAB_SANDBOX/.verdict0" 'PASS'
assert_not_contains 'HARDCODED_VERDICT --status 0 の判定に FAIL が無い' "$LAB_SANDBOX/.verdict0" 'FAIL'

lab_run bash "$script" --status 1
fail_output="$LAB_SANDBOX/.out_status1"
cp -- "$LAB_STDOUT" "$fail_output"
verdict_value "$fail_output" "$LAB_SANDBOX/.verdict1"
assert_contains 'HARDCODED_VERDICT --status 1 の判定が FAIL' "$LAB_SANDBOX/.verdict1" 'FAIL'
assert_not_contains 'HARDCODED_VERDICT --status 1 の判定に PASS が無い' "$LAB_SANDBOX/.verdict1" 'PASS'

lab_finish
