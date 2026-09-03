#!/usr/bin/env bash
# E14 模範解答: 通るだけでなく、壊れた実装のときに落ちるテストです。
# 出力の形は tests/run_tests.sh と同じ ok - / not ok - です。
set -Eeuo pipefail

# 被テストスクリプトは環境変数から受けます。パスを直書きしません。
target=${TARGET_SCRIPT:-$HOME/bash-lab/L3/copyjob.sh}

tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT
pass=0
fail=0
ok() { printf 'ok - %s\n' "$1"; pass=$((pass + 1)); }
not_ok() { printf 'not ok - %s\n' "$1"; fail=$((fail + 1)); }

assert_status() {
  local name=$1 expected=$2
  shift 2
  local actual=0
  "$@" >"$tmp_dir/output" 2>&1 || actual=$?
  if [[ $actual == "$expected" ]]; then ok "$name"; else not_ok "$name (expected=$expected actual=$actual)"; fi
}

assert_contains() {
  local name=$1 needle=$2
  if grep -Fq -- "$needle" "$tmp_dir/output"; then ok "$name"; else not_ok "$name"; fi
}

mkdir -p "$tmp_dir/src"
printf 'data\n' >"$tmp_dir/src/data.txt"

# 1) ドライラン（--execute なし）
assert_status 'dry-run succeeds' 0 bash "$target" --src "$tmp_dir/src" --dst "$tmp_dir/dst"
# ここが「落ちるテスト」です。ドライランで成果物ができていないことを確かめます。
if [[ ! -e "$tmp_dir/dst" ]]; then ok 'dry-run creates no file'; else not_ok 'dry-run creates no file'; fi

# 2) --execute つき
assert_status 'execute succeeds' 0 bash "$target" --src "$tmp_dir/src" --dst "$tmp_dir/dst" --execute
if [[ -s "$tmp_dir/dst/data.txt" ]]; then ok 'execute copies the file'; else not_ok 'execute copies the file'; fi

# 3) 不明な引数
assert_status 'unknown option is rejected' 2 bash "$target" --src "$tmp_dir/src" --dst "$tmp_dir/dst" --nosuch
assert_contains 'unknown option explains cause' '不明な引数です'

printf '1..%d\n' "$((pass + fail))"
printf '# pass=%d fail=%d\n' "$pass" "$fail"
(( fail == 0 ))
