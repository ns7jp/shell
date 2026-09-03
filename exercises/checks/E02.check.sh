#!/usr/bin/env bash
set -Eeuo pipefail

# E02 の採点です。5語と scripts/backup.sh の行番号の対応を確かめます。
LAB_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=exercises/lib/lab_common.sh
# shellcheck disable=SC1091
source "$LAB_DIR/lib/lab_common.sh"
# shellcheck source=exercises/lib/assert.sh
# shellcheck disable=SC1091
source "$LAB_DIR/lib/assert.sh"

lab_begin E02
lab_need 'L0/spine_map.tsv'
map_file=$LAB_PATH
target="$LAB_REPO_DIR/scripts/backup.sh"
total_lines=$(wc -l <"$target")

words=(受ける 疑う 動かす 確かめる 伝える)
# 語ごとに「その行の前後2行に必ずあるはずの手がかり」を決めます。
patterns=(
  '\-\-config'
  'require_absolute_safe_path|require_integer_range|die'
  'run_or_show'
  'tar -tzf'
  'log OK|exit'
)

# 空行とコメントを除き、1列目の語と2列目の行番号を取り出します。
parsed="$LAB_SANDBOX/parsed"
awk 'NF && $1 !~ /^#/ {print $1 "\t" $2}' "$map_file" >"$parsed"

row_count=$(wc -l <"$parsed")
assert_equal '5行あること' '5' "$row_count" "$map_file"

previous=0
index=0
for word in "${words[@]}"; do
  index=$((index + 1))
  actual_word=$(awk -F'\t' -v n="$index" 'NR == n {print $1}' "$parsed")
  actual_line=$(awk -F'\t' -v n="$index" 'NR == n {print $2}' "$parsed")
  assert_equal "${index}行目の語が $word" "$word" "${actual_word:-（空）}" "$map_file"
  if [[ ! $actual_line =~ ^[0-9]+$ ]] || ((actual_line < 1 || actual_line > total_lines)); then
    lab_not_ok "$word の行番号が 1〜$total_lines" "$map_file" "1 から $total_lines の整数" \
      "${actual_line:-（空）}" 'scripts/backup.sh の実在する行番号'
    continue
  fi
  if ((actual_line <= previous)); then
    lab_not_ok "$word の行番号が前の語より後ろ" "$map_file" "${previous} より大きい行番号" \
      "$actual_line" '5語は上から順に現れます。並び順を見直します'
    continue
  fi
  previous=$actual_line
  window="$LAB_SANDBOX/window"
  start=$((actual_line - 2))
  ((start < 1)) && start=1
  sed -n "${start},$((actual_line + 2))p" "$target" >"$window"
  if grep -Eq -- "${patterns[$((index - 1))]}" "$window"; then
    lab_ok "$word が指す行に手がかりがある（${actual_line}行目）"
  else
    lab_not_ok "$word が指す行に手がかりがある（${actual_line}行目）" \
      "$target の ${start}〜$((actual_line + 2))行目" \
      "「${patterns[$((index - 1))]}」を含む行" \
      "$(head -n 1 "$window" | cut -c1-80)" \
      "$word にあたる処理の行番号"
  fi
done

lab_finish
