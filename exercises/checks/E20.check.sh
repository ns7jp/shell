#!/usr/bin/env bash
# 不足の説明文に書いた単一引用符の中の $ は、展開せずそのまま見せる文字列です。
# shellcheck disable=SC2016
set -Eeuo pipefail

# E20 の採点です。直した b1.sh / b2.sh / b3.sh を実行し、notes.md の3件分を数えます。
LAB_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=exercises/lib/lab_common.sh
# shellcheck disable=SC1091
source "$LAB_DIR/lib/lab_common.sh"
# shellcheck source=exercises/lib/assert.sh
# shellcheck disable=SC1091
source "$LAB_DIR/lib/assert.sh"

lab_begin E20
lab_need 'L6/notes.md'
notes=$LAB_PATH

# 教材は採点のたびにその場で作ります（問題文の8節で開示しています）。
mkdir -p -- "$LAB_SANDBOX/b1case/my data" "$LAB_SANDBOX/arcsrc"
printf 'test data\n' >"$LAB_SANDBOX/arcsrc/data.txt"
tar -C "$LAB_SANDBOX" -czf "$LAB_SANDBOX/good.tar.gz" -- arcsrc
printf 'this file is not a gzip archive\n' >"$LAB_SANDBOX/broken.tar.gz"

judge() {
  local name=$1 verdict=$2 where=$3 expected=$4 actual=$5 advice=$6
  if [[ $verdict == true ]]; then
    lab_ok "$name"
  else
    lab_not_ok "$name" "$where" "$expected" "$actual" "$advice"
  fi
}

# 3本は start が置きます。無いときは実行エラーにせず、その判定だけを不合格にします。
stage_script() {
  local name=$1
  if [[ -f "$LAB_HOME/L6/$name" ]]; then
    cp -- "$LAB_HOME/L6/$name" "$LAB_SANDBOX/$name"
    return 0
  fi
  return 1
}

missing_script() {
  local name=$1 case_name=$2
  judge "$case_name" false "$LAB_HOME/L6/$name" "$name があること" '存在しません' \
    "bash exercises/labctl.sh start E20 で $name を置き直すこと"
}

# --- b1: 引用符 -------------------------------------------------------------
if stage_script b1.sh; then
  lab_run bash "$LAB_SANDBOX/b1.sh" --dir "$LAB_SANDBOX/b1case/my data"
  b1_status=$LAB_STATUS
  b1_head=$(lab_head "$LAB_BOTH")
  b1_entries=$(find "$LAB_SANDBOX/b1case" -mindepth 1 -maxdepth 1 | wc -l)
  b1_ok=false
  if [[ $b1_status == 0 && $b1_entries == 1 && -f "$LAB_SANDBOX/b1case/my data/out/report.txt" ]]; then
    b1_ok=true
  fi
  judge 'b1 空白を含むディレクトリ名でも成果物がちょうど1つ' "$b1_ok" \
    'b1.sh --dir "<作業場>/my data"' \
    '終了コード 0 かつ 「my data」の1つだけ かつ out/report.txt がある' \
    "終了コード $b1_status / 直下の数 $b1_entries（$b1_head）" \
    '変数展開を "" で囲むこと（mkdir -p -- "$target" と >"$target/report.txt"）'
else
  missing_script b1.sh 'b1 空白を含むディレクトリ名でも成果物がちょうど1つ'
fi

# --- b2: 終了コード ---------------------------------------------------------
if stage_script b2.sh; then
  lab_run bash "$LAB_SANDBOX/b2.sh" --archive "$LAB_SANDBOX/broken.tar.gz"
  b2_bad_status=$LAB_STATUS
  b2_bad_head=$(lab_head "$LAB_BOTH")
  b2_bad_ok=false
  if [[ $b2_bad_status != 0 && $b2_bad_status != 124 ]]; then b2_bad_ok=true; fi
  judge 'b2 壊れたアーカイブでは終了コード1以上' "$b2_bad_ok" \
    'b2.sh --archive broken.tar.gz' '終了コード 1 以上' \
    "終了コード $b2_bad_status（$b2_bad_head）" \
    '$? を対象コマンドの直後で受け取ること（status=0 のあと tar ... || status=$?）'

  lab_run bash "$LAB_SANDBOX/b2.sh" --archive "$LAB_SANDBOX/good.tar.gz"
  b2_good_status=$LAB_STATUS
  b2_good_head=$(lab_head "$LAB_BOTH")
  b2_good_ok=false
  if [[ $b2_good_status == 0 ]]; then b2_good_ok=true; fi
  judge 'b2 正常なアーカイブでは終了コード0' "$b2_good_ok" \
    'b2.sh --archive good.tar.gz' '終了コード 0' \
    "終了コード $b2_good_status（$b2_good_head）" \
    'いつも失敗にしないこと（exit を決め打ちしない）'
else
  missing_script b2.sh 'b2 壊れたアーカイブでは終了コード1以上'
  missing_script b2.sh 'b2 正常なアーカイブでは終了コード0'
fi

# --- b3: パイプ -------------------------------------------------------------
if stage_script b3.sh; then
  lab_run bash "$LAB_SANDBOX/b3.sh" --archive "$LAB_SANDBOX/broken.tar.gz"
  b3_bad_status=$LAB_STATUS
  b3_bad_head=$(lab_head "$LAB_BOTH")
  b3_bad_ok=false
  if [[ $b3_bad_status != 0 && $b3_bad_status != 124 ]]; then b3_bad_ok=true; fi
  judge 'b3 パイプ途中が失敗したら終了コード1以上' "$b3_bad_ok" \
    'b3.sh --archive broken.tar.gz' '終了コード 1 以上' \
    "終了コード $b3_bad_status（$b3_bad_head）" \
    'set の行に pipefail を足すこと（|| true で握りつぶさない）'

  lab_run bash "$LAB_SANDBOX/b3.sh" --archive "$LAB_SANDBOX/good.tar.gz"
  b3_good_status=$LAB_STATUS
  b3_good_head=$(lab_head "$LAB_BOTH")
  b3_good_ok=false
  if [[ $b3_good_status == 0 ]]; then b3_good_ok=true; fi
  judge 'b3 正常なアーカイブでは終了コード0' "$b3_good_ok" \
    'b3.sh --archive good.tar.gz' '終了コード 0' \
    "終了コード $b3_good_status（$b3_good_head）" \
    'いつも失敗にしないこと（exit を決め打ちしない）'
else
  missing_script b3.sh 'b3 パイプ途中が失敗したら終了コード1以上'
  missing_script b3.sh 'b3 正常なアーカイブでは終了コード0'
fi

# --- notes.md: 3件分の「症状」「原因」「対処」 ------------------------------
count_word() {
  local word=$1 found
  found=$(grep -c -- "$word" "$notes" || true)
  printf '%s' "${found:-0}"
}
symptom_count=$(count_word '症状')
cause_count=$(count_word '原因')
action_count=$(count_word '対処')
notes_ok=false
if ((symptom_count >= 3 && cause_count >= 3 && action_count >= 3)); then notes_ok=true; fi
judge 'notes.md に3件分の「症状」「原因」「対処」がある' "$notes_ok" \
  "$notes" '「症状」「原因」「対処」がそれぞれ3行以上' \
  "症状 ${symptom_count}行 / 原因 ${cause_count}行 / 対処 ${action_count}行" \
  'b1・b2・b3 の3件それぞれに症状・原因・対処を書くこと'

lab_finish
