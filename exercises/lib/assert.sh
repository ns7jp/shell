#!/usr/bin/env bash

# 採点の判定プリミティブです。採点スクリプトはこの6種類だけを使います。
#   1. assert_status      終了コードが期待どおりか
#   2. assert_contains    出力に必要な文字列が含まれるか
#   3. assert_file        成果物の有無・中身・権限・状態が期待どおりか
#   4. assert_static      構文と、書いてよい書き方・禁止した書き方
#   5. assert_lines       正規化した出力を期待値と1行ずつ比べる
#   6. assert_ref_status  同じ入力で模範解答と終了コードが一致するか
# 補助として assert_equal / lab_skip / lab_finish を用意します。
# 学習者はこの内訳を覚える必要はありません。覚えるのは
# 「落ちたら 期待= と 実測= の2行を読む」だけです。
# shellcheck disable=SC2034
: "${LAB_COMMON_LOADED:?exercises/lib/lab_common.sh を先に読み込んでください}"

LAB_PASS=0
LAB_FAIL=0
LAB_SKIP=0
LAB_TOTAL=0

# --- 合否の表示 -------------------------------------------------------------
# 形式は既存の tests/run_tests.sh と同じ「ok - 名前」「not ok - 名前」です。
lab_ok() {
  LAB_TOTAL=$((LAB_TOTAL + 1))
  LAB_PASS=$((LAB_PASS + 1))
  printf 'ok - %s\n' "$1"
}

# 不合格の表示には必ず5項目を出します。
# 見た場所 / 期待 / 実測 / 不足 / 次に打つ1コマンド。
lab_not_ok() {
  local name=$1 where=$2 expected=$3 actual=$4 missing=$5
  LAB_TOTAL=$((LAB_TOTAL + 1))
  LAB_FAIL=$((LAB_FAIL + 1))
  printf 'not ok - %s\n' "$name"
  printf '#   見た場所: %s\n' "$where"
  printf '#   期待= %s\n' "$expected"
  printf '#   実測= %s\n' "$actual"
  printf '#   不足= %s\n' "$missing"
  printf '#   次の一手: bash exercises/labctl.sh hint %s\n' "${LAB_EXERCISE:-EXX}"
}

# 環境が足りず判定できない検査は、合格にせず「未実施」として残します。
lab_skip() {
  LAB_TOTAL=$((LAB_TOTAL + 1))
  LAB_SKIP=$((LAB_SKIP + 1))
  printf 'not run - %s # %s\n' "$1" "$2"
}

# 採点スクリプトの最後に必ず呼びます。0=合格、1=不合格。
lab_finish() {
  printf '1..%d\n' "$LAB_TOTAL"
  printf '# pass=%d fail=%d not_run=%d\n' "$LAB_PASS" "$LAB_FAIL" "$LAB_SKIP"
  if ((LAB_FAIL > 0)); then
    log WARN "$LAB_EXERCISE 不合格: ${LAB_TOTAL} 件中 ${LAB_PASS} 件通過"
    exit "$EXIT_WARNING"
  fi
  log OK "$LAB_EXERCISE 合格: ${LAB_TOTAL} 件中 ${LAB_PASS} 件通過（未実施 ${LAB_SKIP} 件）"
  exit "$EXIT_OK"
}

# --- 1. 終了コード ----------------------------------------------------------
# 使い方: assert_status ケース名 期待コード -- コマンド...
assert_status() {
  local name=$1 expected=$2
  shift 2
  [[ ${1:-} == '--' ]] && shift
  lab_run "$@"
  if [[ $LAB_STATUS == 124 && $expected != 124 ]]; then
    lab_not_ok "$name" "$(printf '%q ' "$@")" "終了コード $expected" \
      "${LAB_TIMEOUT}秒で終わらず打ち切り(TIMEOUT)" '処理が止まらない原因（無限ループや入力待ち）'
    return 0
  fi
  if [[ $LAB_STATUS == "$expected" ]]; then
    lab_ok "$name"
  else
    lab_not_ok "$name" "$(printf '%q ' "$@")" "終了コード $expected" "終了コード $LAB_STATUS" \
      "$(lab_status_advice "$expected" "$LAB_STATUS")"
  fi
}

lab_status_advice() {
  local expected=$1 actual=$2
  # 単一引用符の中の $EXIT_WARNING は説明用の文字列です（展開しません）。
  # shellcheck disable=SC2016
  case "$expected" in
    0) printf '正常に最後まで進んで0を返す処理（途中の die や exit を見直します）' ;;
    1) printf '警告を数えて exit "$EXIT_WARNING" を返す処理' ;;
    2) printf '不正な入力を die で拒否する処理' ;;
    *) printf '期待した終了コード %s を返す処理（実測 %s）' "$expected" "$actual" ;;
  esac
}

# --- 2. 出力の部分一致 ------------------------------------------------------
assert_contains() {
  local name=$1 file=$2 needle=$3
  if [[ -f $file ]] && grep -Fq -- "$needle" "$file"; then
    lab_ok "$name"
  else
    lab_not_ok "$name" "$file" "「$needle」を含む出力" "$(lab_head "$file")" \
      "「$needle」を出力する処理"
  fi
}

assert_not_contains() {
  local name=$1 file=$2 needle=$3
  if [[ -f $file ]] && grep -Fq -- "$needle" "$file"; then
    lab_not_ok "$name" "$file" "「$needle」を含まない出力" "$(lab_head "$file")" \
      "「$needle」を出さない書き方への修正"
  else
    lab_ok "$name"
  fi
}

lab_head() {
  local file=$1
  if [[ ! -f $file ]]; then
    printf '（ファイルがありません）'
    return 0
  fi
  if [[ ! -s $file ]]; then
    printf '（出力は空でした）'
    return 0
  fi
  head -n 3 -- "$file" | lab_normalize | tr '\n' '/' | cut -c1-200
}

# --- 3. 成果物 --------------------------------------------------------------
# 使い方: assert_file ケース名 パス --exists|--absent|--nonempty|--mode NNN|--hash 値
assert_file() {
  local name=$1 path=$2 mode=${3:---exists} want=${4:-}
  case "$mode" in
    --exists)
      if [[ -e $path ]]; then lab_ok "$name"; else
        lab_not_ok "$name" "$path" 'このパスが存在すること' '存在しません' '成果物を作る処理'
      fi ;;
    --absent)
      if [[ -e $path ]]; then
        lab_not_ok "$name" "$path" 'このパスが存在しないこと' '存在します' \
          'ドライランでは作らない（--execute のときだけ作る）分岐'
      else lab_ok "$name"; fi ;;
    --nonempty)
      if [[ -s $path ]]; then lab_ok "$name"; else
        lab_not_ok "$name" "$path" '中身のあるファイル' "$([[ -e $path ]] && printf '0バイト' || printf '存在しません')" \
          '中身を書き込む処理と、書けたことの確認'
      fi ;;
    --mode)
      local actual='取得できません'
      [[ -e $path ]] && actual=$(stat -c '%a' -- "$path" 2>/dev/null || printf '取得できません')
      if [[ $actual == "$want" ]]; then lab_ok "$name"; else
        lab_not_ok "$name" "$path" "権限 $want" "権限 $actual" "chmod $want または install -m $want"
      fi ;;
    --hash)
      local actual
      actual=$(lab_state_hash "$path")
      if [[ $actual == "$want" ]]; then lab_ok "$name"; else
        lab_not_ok "$name" "$path" "1回目と同じ状態（$want）" "変化しました（$actual）" \
          '2回目に増減や書き換えが起きない書き方（mkdir -p / install -D / 日時を名前に入れない）'
      fi ;;
    *) lab_error "assert_file の使い方が違います: $mode" ;;
  esac
}

# --- 4. 静的検査 ------------------------------------------------------------
# 使い方: assert_static ケース名 スクリプト [--must 正規表現]... [--must-not 正規表現]...
assert_static() {
  local name=$1 script=$2
  shift 2
  if [[ ! -f $script ]]; then
    lab_not_ok "$name" "$script" 'スクリプトがあること' '存在しません' '答案ファイルの作成'
    return 0
  fi
  local syntax_error
  if ! syntax_error=$(bash -n -- "$script" 2>&1); then
    lab_not_ok "$name" "$script" 'bash -n が通ること' "$(printf '%s' "$syntax_error" | head -n 2 | tr '\n' '/')" \
      '構文の修正（引用符やdo/done、fiの閉じ忘れ）'
    return 0
  fi
  local -a missing=() forbidden=()
  while (($#)); do
    case "$1" in
      --must)
        grep -Eq -- "$2" "$script" || missing+=("$2")
        shift 2 ;;
      --must-not)
        grep -Eq -- "$2" "$script" && forbidden+=("$2")
        shift 2 ;;
      *) lab_error "assert_static の使い方が違います: $1" ;;
    esac
  done
  if ((${#missing[@]} == 0 && ${#forbidden[@]} == 0)); then
    lab_ok "$name"
  else
    local detail=''
    ((${#missing[@]} > 0)) && detail="不足: ${missing[*]}"
    ((${#forbidden[@]} > 0)) && detail="$detail 禁止: ${forbidden[*]}"
    lab_not_ok "$name" "$script" '必要な書き方があり、禁止した書き方が無いこと' "$detail" "$detail"
  fi
}

# ShellCheck は任意です。未導入の環境では合格にせず「未実施」と記録します。
assert_shellcheck() {
  local name=$1 script=$2
  if ! command -v shellcheck >/dev/null 2>&1; then
    lab_skip "$name" 'NOT RUN（shellcheck が未導入です）'
    return 0
  fi
  # SC1090/SC1091 は「source 先を追えない」という道具側の制限で、
  # 学習者の誤りではないため除外します。
  local output
  if output=$(shellcheck -S warning -e SC1090,SC1091 -- "$script" 2>&1); then
    lab_ok "$name"
  else
    lab_not_ok "$name" "$script" 'ShellCheck の警告が無いこと' \
      "$(printf '%s' "$output" | grep -E '^In |SC[0-9]+' | head -n 2 | tr '\n' '/')" \
      'ShellCheck が指摘した箇所の修正'
  fi
}

# --- 5. 行の比較 ------------------------------------------------------------
# 正規化したうえで期待ファイルと比べます。文言まで決まっている出力にだけ使います。
assert_lines() {
  local name=$1 expected_file=$2 actual_file=$3
  local expected_norm="$LAB_SANDBOX/.expected_norm" actual_norm="$LAB_SANDBOX/.actual_norm"
  lab_normalize <"$expected_file" >"$expected_norm"
  lab_normalize <"$actual_file" >"$actual_norm"
  if diff -u "$expected_norm" "$actual_norm" >"$LAB_SANDBOX/.diff" 2>&1; then
    lab_ok "$name"
  else
    lab_not_ok "$name" "$actual_file" \
      "$(tr '\n' '/' <"$expected_norm" | cut -c1-160)" \
      "$(tr '\n' '/' <"$actual_norm" | cut -c1-160)" \
      "$(grep -E '^[-+]' "$LAB_SANDBOX/.diff" | grep -vE '^(\+\+\+|---)' | head -n 4 | tr '\n' '/')"
  fi
}

assert_equal() {
  local name=$1 expected=$2 actual=$3 where=${4:-$LAB_EXERCISE}
  if [[ $expected == "$actual" ]]; then
    lab_ok "$name"
  else
    lab_not_ok "$name" "$where" "$expected" "$actual" "$expected と一致する結果"
  fi
}

# --- 6. 模範解答との突き合わせ ----------------------------------------------
# 同じ引数を学習者の答案と模範解答の両方に流し、終了コードだけを比べます。
# 日本語の言い回しの違いでは落ちません。
assert_ref_status() {
  local name=$1 learner=$2 reference=$3
  shift 3
  [[ ${1:-} == '--' ]] && shift
  lab_run bash "$learner" "$@"
  local learner_status=$LAB_STATUS
  local learner_out="$LAB_SANDBOX/.learner_out"
  cp -- "$LAB_BOTH" "$learner_out"
  lab_run bash "$reference" "$@"
  local reference_status=$LAB_STATUS
  if [[ $learner_status == "$reference_status" ]]; then
    lab_ok "$name"
  else
    lab_not_ok "$name" "$(printf '%q ' "$@")" "終了コード $reference_status（模範解答と同じ）" \
      "終了コード $learner_status" "$(lab_status_advice "$reference_status" "$learner_status")"
  fi
  cp -- "$learner_out" "$LAB_BOTH"
  LAB_STATUS=$learner_status
}
