#!/usr/bin/env bash
set -Eeuo pipefail

# E04 の採点です。骨9要素が spine.sh に写せているかを、実行せずに確かめます。
LAB_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=exercises/lib/lab_common.sh
# shellcheck disable=SC1091
source "$LAB_DIR/lib/lab_common.sh"
# shellcheck source=exercises/lib/assert.sh
# shellcheck disable=SC1091
source "$LAB_DIR/lib/assert.sh"

lab_begin E04
lab_stage 'L1/spine.sh'
script=$LAB_STAGED

# まず構文だけを見ます。ここが通らないと以降の指摘が読みにくくなるためです。
assert_static '構文が通る（bash -n）' "$script"

# 9要素の名前と、その要素を探すための正規表現です。空白の入れ方では落ちません。
names=(
  '1/9 shebang（#!/usr/bin/env bash）'
  '2/9 安全設定（set -Eeuo pipefail）'
  '3/9 共通ライブラリ読込（LAB_COMMON）'
  '4/9 usage（使い方の表示）'
  '5/9 引数解析（while (($#))）'
  '6/9 入力検証（die）'
  '7/9 ドライラン既定の処理（run_or_show）'
  '8/9 成果物の確認（[[ -s ）'
  '9/9 ログと終了コード（exit）'
)
patterns=(
  '^#!/usr/bin/env bash'
  'set[[:space:]]+-Eeuo[[:space:]]+pipefail'
  'LAB_COMMON'
  'usage[[:space:]]*\(\)'
  'while[[:space:]]*\(\([[:space:]]*\$#[[:space:]]*\)\)'
  'die'
  'run_or_show'
  '\[\[[[:space:]]+-s[[:space:]]'
  'exit'
)

missing_names=''
index=0
while ((index < ${#names[@]})); do
  if grep -Eq -- "${patterns[$index]}" "$script"; then
    lab_ok "要素があります: ${names[$index]}"
  else
    missing_names="$missing_names ${names[$index]}"
    lab_not_ok "要素があります: ${names[$index]}" "$script" \
      "「${patterns[$index]}」に当たる行" '見つかりません' \
      "spine.tmpl の ${names[$index]} の行"
  fi
  index=$((index + 1))
done

if [[ -n $missing_names ]]; then
  printf '# 欠けた要素:%s\n' "$missing_names"
fi

# ShellCheck は任意です。未導入なら「未実施」として残し、合格扱いにはしません。
assert_shellcheck 'ShellCheck の警告が無い' "$script"

lab_finish
