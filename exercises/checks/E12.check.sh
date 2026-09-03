#!/usr/bin/env bash
set -Eeuo pipefail

# E12 の採点です。既定はドライラン、--execute のときだけコピーするかを確かめます。
LAB_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=exercises/lib/lab_common.sh
# shellcheck disable=SC1091
source "$LAB_DIR/lib/lab_common.sh"
# shellcheck source=exercises/lib/assert.sh
# shellcheck disable=SC1091
source "$LAB_DIR/lib/assert.sh"

lab_begin E12
lab_stage 'L3/copyjob.sh'
script=$LAB_STAGED
reference="$LAB_DIR/answers/E12.ref.sh"

# 採点のたびに、コピー元をサンドボックスに作ります（問題文の8節で開示しています）。
src="$LAB_SANDBOX/src"
mkdir -p -- "$src/sub"
printf 'alpha\n' >"$src/a.txt"
printf 'beta\n' >"$src/sub/b.txt"

assert_static '危ない書き方が無い（eval と rm -rf を書かない）' "$script" \
  --must-not 'eval' --must-not 'rm -rf'

# --- 差分テスト5ケース（終了コードだけを模範解答と比べます） ----------------
assert_ref_status 'DRYRUN 模範解答と同じ終了コード' "$script" "$reference" \
  -- --src "$src" --dst "$LAB_SANDBOX/dst_dry"
assert_ref_status 'EXECUTE 模範解答と同じ終了コード' "$script" "$reference" \
  -- --src "$src" --dst "$LAB_SANDBOX/dst_exec" --execute
assert_ref_status 'MISSING_SRC 模範解答と同じ終了コード' "$script" "$reference" \
  -- --dst "$LAB_SANDBOX/dst_missing"
assert_ref_status 'SYSTEM_DST 模範解答と同じ終了コード' "$script" "$reference" \
  -- --src "$src" --dst /proc
assert_ref_status 'UNKNOWN_ARG 模範解答と同じ終了コード' "$script" "$reference" \
  -- --src "$src" --dst "$LAB_SANDBOX/dst_unknown" --bogus

# --- 直接確認1: ドライランでは --dst を作らない ------------------------------
dry_only="$LAB_SANDBOX/dst_dry_only"
lab_run bash "$script" --src "$src" --dst "$dry_only"
assert_file 'DRYRUN_SIDE_EFFECT ドライランでは --dst を作らない' "$dry_only" --absent

# --- 直接確認2: --execute の後は中身が一致する ------------------------------
copy_dst="$LAB_SANDBOX/dst_copy"
lab_run bash "$script" --src "$src" --dst "$copy_dst" --execute
assert_status 'EXECUTE 後に diff -r で中身が一致' 0 -- diff -r "$src" "$copy_dst"

lab_finish
