#!/usr/bin/env bash
set -Eeuo pipefail

# E15 の採点です。3項目を途中で止めずに確かめ、警告の数で終了コードを分けているかを見ます。
LAB_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=exercises/lib/lab_common.sh
# shellcheck disable=SC1091
source "$LAB_DIR/lib/lab_common.sh"
# shellcheck source=exercises/lib/assert.sh
# shellcheck disable=SC1091
source "$LAB_DIR/lib/assert.sh"

lab_begin E15
lab_stage 'L4/verify_dir.sh'
script=$LAB_STAGED

# 採点のたびに、4つの状況をここで作ります（問題文の8節で開示しています）。
# git は権限を保存しないため、権限は必ずこの場で chmod します。
mkdir -p -- "$LAB_SANDBOX/normal" "$LAB_SANDBOX/missing" "$LAB_SANDBOX/empty" "$LAB_SANDBOX/mode"
printf '<html></html>\n' >"$LAB_SANDBOX/normal/index.html"
chmod 644 -- "$LAB_SANDBOX/normal/index.html"
: >"$LAB_SANDBOX/empty/index.html"
chmod 644 -- "$LAB_SANDBOX/empty/index.html"
printf '<html></html>\n' >"$LAB_SANDBOX/mode/index.html"
chmod 666 -- "$LAB_SANDBOX/mode/index.html"

# 標準出力から [OK] と [WARN] を上から3つだけ抜き出して比べます。
# メッセージ本文は一切比べないため、日本語の言い回しの違いでは落ちません。
verify_case() {
  local name=$1 dir=$2 expected_status=$3
  shift 3
  local expected_file="$LAB_SANDBOX/.expected_$name" actual_file="$LAB_SANDBOX/.actual_$name"
  printf '%s\n' "$@" >"$expected_file"
  lab_run bash "$script" --dir "$dir"
  local actual_status=$LAB_STATUS
  grep -oE '\[(OK|WARN)\]' "$LAB_STDOUT" 2>/dev/null | head -n 3 >"$actual_file" || true
  assert_equal "$name 終了コード" "$expected_status" "$actual_status" "$script --dir $dir"
  assert_lines "$name レベル語の並び（上から3つ）" "$expected_file" "$actual_file"
}

verify_case NORMAL  "$LAB_SANDBOX/normal"  0 '[OK]'   '[OK]'   '[OK]'
verify_case MISSING "$LAB_SANDBOX/missing" 1 '[WARN]' '[WARN]' '[WARN]'
verify_case EMPTY   "$LAB_SANDBOX/empty"   1 '[OK]'   '[WARN]' '[OK]'
verify_case MODE    "$LAB_SANDBOX/mode"    1 '[OK]'   '[OK]'   '[WARN]'

lab_finish
