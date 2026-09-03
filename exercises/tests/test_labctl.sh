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
# 壊した教材は exercises/fixtures/start/EXX/ に .sh.broken で置きます。
# ここに .sh を置くと make syntax が拾って CI が落ちます。
if find "$ROOT_DIR/exercises/fixtures/start" -name '*.sh' -print -quit 2>/dev/null | grep -q .; then
  not_ok '配布する壊した教材に .sh を置かない'
else
  ok '配布する壊した教材に .sh を置かない'
fi
catalog_rows=$(awk -F'\t' '$1 ~ /^E[0-9]+$/' "$ROOT_DIR/exercises/exercises.tsv" | wc -l)
if [[ $catalog_rows == 21 ]]; then ok '演習は21問'; else not_ok "演習は21問 (実測 $catalog_rows)"; fi

## 全21問が5点セットをそろえているか -------------------------------------------
missing=''
while IFS=$'\t' read -r id level _ _ _ _ _ _ _; do
  [[ $id == E* ]] || continue
  [[ -f "$ROOT_DIR/exercises/levels/$level/$id.md" ]] || missing="$missing $id:問題文"
  [[ -f "$ROOT_DIR/exercises/levels/$level/$id.hints.md" ]] || missing="$missing $id:ヒント"
  [[ -f "$ROOT_DIR/exercises/checks/$id.check.sh" ]] || missing="$missing $id:採点"
  if [[ ! -d "$ROOT_DIR/exercises/answers/$id.ref" ]] && ! compgen -G "$ROOT_DIR/exercises/answers/$id.ref.*" >/dev/null; then
    missing="$missing $id:模範解答"
  fi
  if [[ ! -d "$ROOT_DIR/exercises/answers/wrong/$id.wrong.d" ]] && [[ ! -f "$ROOT_DIR/exercises/answers/wrong/$id.wrong" ]]; then
    missing="$missing $id:誤答例"
  fi
done < <(awk -F'\t' '$1 ~ /^E[0-9]+$/' "$ROOT_DIR/exercises/exercises.tsv")
if [[ -z $missing ]]; then
  ok '全21問に問題文・ヒント・採点・模範解答・誤答例がある'
else
  printf '%s\n' "$missing" >"$tmp_dir/output"
  not_ok '全21問に問題文・ヒント・採点・模範解答・誤答例がある'
fi

## ヒントの見出しが3段階そろっているか -----------------------------------------
hint_problem=''
while IFS=$'\t' read -r id level _; do
  [[ $id == E* ]] || continue
  hints="$ROOT_DIR/exercises/levels/$level/$id.hints.md"
  [[ -f $hints ]] || continue
  for step in H1 H2 H3; do
    grep -q "^## $step " "$hints" || hint_problem="$hint_problem $id:$step"
  done
done < <(awk -F'\t' '$1 ~ /^E[0-9]+$/' "$ROOT_DIR/exercises/exercises.tsv")
if [[ -z $hint_problem ]]; then
  ok 'ヒントはすべて H1 / H2 / H3 の3段階'
else
  printf '%s\n' "$hint_problem" >"$tmp_dir/output"
  not_ok 'ヒントはすべて H1 / H2 / H3 の3段階'
fi

## 案内ドキュメントの一覧表が実物と一致するか ----------------------------------
doc_missing=''
while IFS= read -r id; do
  grep -Fq "| $id |" "$ROOT_DIR/docs/15-exercise-pack-guide.md" || doc_missing="$doc_missing $id"
done < <(awk -F'\t' '$1 ~ /^E[0-9]+$/ {print $1}' "$ROOT_DIR/exercises/exercises.tsv")
if [[ -z $doc_missing ]]; then
  ok 'docs/15 の一覧表に21問すべてが載っている'
else
  printf '%s\n' "$doc_missing" >"$tmp_dir/output"
  not_ok 'docs/15 の一覧表に21問すべてが載っている'
fi

## 一覧表・問題文・暗記カードの内容が食い違っていないか --------------------------
drift=''
while IFS=$'\t' read -r id level _ _ title minutes work _ _; do
  [[ $id == E* ]] || continue
  doc="$ROOT_DIR/exercises/levels/$level/$id.md"
  [[ -f $doc ]] || continue
  heading=$(head -n 1 "$doc")
  [[ $heading == "# $id $title" ]] || drift="$drift $id:題名"
  grep -Fq "| $minutes分 |" "$doc" || drift="$drift $id:目安分"
  grep -Fq "$work" "$doc" || drift="$drift $id:作業ファイル"
done < <(awk -F'\t' '$1 ~ /^E[0-9]+$/' "$ROOT_DIR/exercises/exercises.tsv")
if [[ -z $drift ]]; then
  ok '一覧表の題名・目安分・作業ファイルが問題文と一致する'
else
  printf '%s\n' "$drift" >"$tmp_dir/output"
  not_ok '一覧表の題名・目安分・作業ファイルが問題文と一致する'
fi

# 暗記カードは docs/17 の印刷用ページと同一に保ちます（Markdownのコード表記は無視します）。
sed 's/`//g' "$ROOT_DIR/docs/17-memory-cheatsheet.md" >"$tmp_dir/cheatsheet.plain"
card_drift=''
while IFS=$'\t' read -r card_id _ _ back _; do
  [[ $card_id == \#* || -z $card_id ]] && continue
  grep -Fq "$back" "$tmp_dir/cheatsheet.plain" || card_drift="$card_drift $card_id"
done <"$ROOT_DIR/exercises/cards/cards.tsv"
if [[ -z $card_drift ]]; then
  ok '暗記カード17枚の内容が docs/17 と一致する'
else
  printf '%s\n' "$card_drift" >"$tmp_dir/output"
  not_ok '暗記カード17枚の内容が docs/17 と一致する'
fi

## start 直後の未着手状態が合格してしまわないか ---------------------------------
# 雛形が答えそのものになっていると、学習者が何もしなくても合格してしまいます。
trivial=''
export LAB_HOME="$tmp_dir/trivial"
bash "$LABCTL" init >/dev/null 2>&1
while IFS=$'\t' read -r id _; do
  [[ $id == E* ]] || continue
  bash "$LABCTL" start "$id" >/dev/null 2>&1
  status=0
  bash "$LABCTL" grade "$id" >/dev/null 2>&1 || status=$?
  [[ $status == 0 ]] && trivial="$trivial $id"
done < <(awk -F'\t' '$1 ~ /^E[0-9]+$/' "$ROOT_DIR/exercises/exercises.tsv")
export LAB_HOME="$tmp_dir/lab"
if [[ -z $trivial ]]; then
  ok '未着手の答案はどの問題も合格しない'
else
  printf '手を動かさずに合格する演習:%s\n' "$trivial" >"$tmp_dir/output"
  not_ok '未着手の答案はどの問題も合格しない'
fi

## 暗記カードの関連演習IDが実在するか ------------------------------------------
card_problem=''
while IFS=$'\t' read -r card_id _ _ _ related; do
  [[ $card_id == \#* || -z $card_id ]] && continue
  awk -F'\t' -v want="$related" '$1 == want {found = 1} END {exit !found}' "$ROOT_DIR/exercises/exercises.tsv" \
    || card_problem="$card_problem $card_id->$related"
done <"$ROOT_DIR/exercises/cards/cards.tsv"
if [[ -z $card_problem ]]; then
  ok '暗記カードの関連演習IDが実在する'
else
  printf '%s\n' "$card_problem" >"$tmp_dir/output"
  not_ok '暗記カードの関連演習IDが実在する'
fi

## 復習間隔が D1 / D3 / D7 / D21 に進むか -----------------------------------
export LAB_HOME="$tmp_dir/spaced"
bash "$LABCTL" init >/dev/null 2>&1
printf '0\n1\n2\n' >"$LAB_HOME/L0/answer.txt"
today=$(date '+%Y-%m-%d')
expected_due=''
for interval in 1 3 7 21; do
  expected_due="$expected_due $(date -d "$today +$interval day" '+%Y-%m-%d')"
done
actual_due=''
for _ in 1 2 3 4; do
  bash "$LABCTL" grade E01 >/dev/null 2>&1
  actual_due="$actual_due $(awk -F'\t' '$1 == "E01" {print $5}' "$LAB_HOME/progress/progress.tsv")"
  # 次の合格を別の日として扱わせます（最終合格日を過去に戻します）。
  awk -F'\t' -v OFS='\t' '$1 == "E01" {$4 = "2000-01-01"} {print}' "$LAB_HOME/progress/progress.tsv" >"$tmp_dir/p"
  cp "$tmp_dir/p" "$LAB_HOME/progress/progress.tsv"
done
if [[ $actual_due == "$expected_due" ]]; then
  ok '復習期日が D1 / D3 / D7 / D21 と進む'
else
  printf '期待=%s\n実測=%s\n' "$expected_due" "$actual_due" >"$tmp_dir/output"
  not_ok '復習期日が D1 / D3 / D7 / D21 と進む'
fi

## 模範解答をディレクトリで持つ問題でも answer が使えるか ----------------------
export LAB_HOME="$tmp_dir/lab"
answer_problem=''
while IFS=$'\t' read -r id _; do
  [[ $id == E* ]] || continue
  bash "$LABCTL" answer "$id" >/dev/null 2>&1 || answer_problem="$answer_problem $id"
done < <(awk -F'\t' '$1 ~ /^E[0-9]+$/' "$ROOT_DIR/exercises/exercises.tsv")
if [[ -z $answer_problem ]]; then
  ok '全21問で answer が模範解答を表示できる'
else
  printf '%s\n' "$answer_problem" >"$tmp_dir/output"
  not_ok '全21問で answer が模範解答を表示できる'
fi

## 採点がリポジトリを汚さないか ------------------------------------------------
if command -v git >/dev/null 2>&1 && git -C "$ROOT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  git -C "$ROOT_DIR" status --porcelain >"$tmp_dir/repo.before"
  export LAB_HOME="$tmp_dir/dirty"
  bash "$LABCTL" init >/dev/null 2>&1
  # 検証を書いていない、危険な答案で採点しても外へ漏れないことを確かめます。
  cat >"$LAB_HOME/L3/copyjob.sh" <<'ANSWER'
#!/usr/bin/env bash
set -Eeuo pipefail
source "${LAB_COMMON:?}"
src=''; dst=''
while (($#)); do
  case "$1" in
    --src) src=${2:-}; shift 2 ;;
    --dst) dst=${2:-}; shift 2 ;;
    --execute) shift ;;
    *) die "不明な引数です: $1" ;;
  esac
done
mkdir -p -- "$dst" 2>/dev/null || true
cp -a -- "$src/." "$dst/" 2>/dev/null || true
log OK "コピーしました: $dst"
ANSWER
  bash "$LABCTL" grade E12 >/dev/null 2>&1 || true
  git -C "$ROOT_DIR" status --porcelain >"$tmp_dir/repo.after"
  if diff -q "$tmp_dir/repo.before" "$tmp_dir/repo.after" >/dev/null; then
    ok '検証を書いていない答案を採点してもリポジトリは汚れない'
  else
    diff -u "$tmp_dir/repo.before" "$tmp_dir/repo.after" >"$tmp_dir/output"
    not_ok '検証を書いていない答案を採点してもリポジトリは汚れない'
  fi
  export LAB_HOME="$tmp_dir/lab"
else
  ok '採点がリポジトリを汚さない検査（git が無いため省略）'
fi

printf '1..%d\n' "$((pass + fail))"
printf '# pass=%d fail=%d\n' "$pass" "$fail"
(( fail == 0 ))
