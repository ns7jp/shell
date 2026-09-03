#!/usr/bin/env bash
set -Eeuo pipefail

# 採点ツール labctl.sh 自身のテストです。出力形式は tests/run_tests.sh と同じにします。
ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
LABCTL="$ROOT_DIR/exercises/labctl.sh"
tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT
pass=0
fail=0
ok() { printf 'ok - %s\n' "$1"; ((pass += 1)); }
not_ok() { printf 'not ok - %s\n' "$1"; ((fail += 1)); cat "$tmp_dir/output" 2>/dev/null || true; }

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

export LAB_HOME="$tmp_dir/lab"

## 実行エラー（終了2）で止まるべき場面 -----------------------------------------
assert_status '不明な演習IDは終了2' 2 bash "$LABCTL" grade E99
assert_contains '不明な演習IDの理由を表示' '不明な演習IDです'

assert_status '不明なサブコマンドは終了2' 2 bash "$LABCTL" nosuchcommand
assert_contains '不明なサブコマンドの理由を表示' '不明なサブコマンドです'

assert_status '作業場が無ければ終了2' 2 bash "$LABCTL" grade E01
assert_contains '作業場が無い理由を表示' '作業場がありません'

## 正常系 ---------------------------------------------------------------------
assert_status 'init は終了0' 0 bash "$LABCTL" init
if [[ -f $LAB_HOME/labenv.sh ]]; then ok 'init が labenv.sh を作る'; else not_ok 'init が labenv.sh を作る'; fi

assert_status '答案が無ければ終了2' 2 bash "$LABCTL" grade E01
assert_contains '答案が無い理由を表示' '答案がありません'

assert_status 'start は終了0' 0 bash "$LABCTL" start E01
assert_status '空の答案は不合格(終了1)' 1 bash "$LABCTL" grade E01
assert_contains '不合格の理由に期待と実測を表示' '期待='

printf '0\n1\n2\n' >"$LAB_HOME/L0/answer.txt"
assert_status '正しい答案は合格(終了0)' 0 bash "$LABCTL" grade E01

assert_status 'start は既存の答案を上書きしない' 0 bash "$LABCTL" start E01
assert_contains '上書きしない旨を表示' '上書きしませんでした'
if [[ $(wc -l <"$LAB_HOME/L0/answer.txt") == 3 ]]; then ok '答案が保持される'; else not_ok '答案が保持される'; fi

assert_status 'hint は終了0' 0 bash "$LABCTL" hint E01 --step 1
assert_status 'hint の範囲外は終了2' 2 bash "$LABCTL" hint E01 --step 9
assert_status 'list は終了0' 0 bash "$LABCTL" list
assert_status 'progress --save は終了0' 0 bash "$LABCTL" progress --save
assert_status 'evidence は終了0' 0 bash "$LABCTL" evidence E01
assert_contains 'evidence が判定欄を持つ' '判定(PASS/FAIL/NOT RUN)'

## 教材の置き場所の規約 -------------------------------------------------------
if find "$ROOT_DIR/exercises/templates" -name '*.sh' -print -quit | grep -q .; then
  not_ok '雛形に .sh を置かない（make syntax を壊さないため）'
else
  ok '雛形に .sh を置かない（make syntax を壊さないため）'
fi
if find "$ROOT_DIR/exercises/answers/wrong" -name '*.sh' -print -quit | grep -q .; then
  not_ok '誤答例に .sh を置かない（make lint を壊さないため）'
else
  ok '誤答例に .sh を置かない（make lint を壊さないため）'
fi
if find "$ROOT_DIR/exercises/fixtures/broken" -name '*.sh' -print -quit | grep -q .; then
  not_ok '壊した教材に .sh を置かない'
else
  ok '壊した教材に .sh を置かない'
fi
catalog_rows=$(awk -F'\t' '$1 ~ /^E[0-9]+$/' "$ROOT_DIR/exercises/exercises.tsv" | wc -l)
if [[ $catalog_rows == 21 ]]; then ok '演習は21問'; else not_ok "演習は21問 (実測 $catalog_rows)"; fi

printf '1..%d\n' "$((pass + fail))"
printf '# pass=%d fail=%d\n' "$pass" "$fail"
(( fail == 0 ))
