#!/usr/bin/env bash
set -Eeuo pipefail

# E21 の採点です。recall.log の記録、talk.md の7語の順、progress.md の20行を見ます。
LAB_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=exercises/lib/lab_common.sh
# shellcheck disable=SC1091
source "$LAB_DIR/lib/lab_common.sh"
# shellcheck source=exercises/lib/assert.sh
# shellcheck disable=SC1091
source "$LAB_DIR/lib/assert.sh"

lab_begin E21
lab_need 'L6/talk.md'
talk=$LAB_PATH
recall_log="$LAB_HOME/progress/recall.log"
progress_md="$LAB_HOME/progress/progress.md"

judge() {
  local name=$1 verdict=$2 where=$3 expected=$4 actual=$5 advice=$6
  if [[ $verdict == true ]]; then
    lab_ok "$name"
  else
    lab_not_ok "$name" "$where" "$expected" "$actual" "$advice"
  fi
}

# --- (1)(2) 自由再生テストの記録 --------------------------------------------
ok_lines="$LAB_SANDBOX/.recall_ok"
: >"$ok_lines"
if [[ -f $recall_log ]]; then
  grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}.*\[OK\]' -- "$recall_log" >"$ok_lines" || true
fi
ok_count=$(wc -l <"$ok_lines")
day_list="$LAB_SANDBOX/.recall_days"
cut -c1-10 -- "$ok_lines" | LC_ALL=C sort -u >"$day_list"
day_count=$(grep -c . "$day_list" || true)

recall_count_ok=false
if ((ok_count >= 3)); then recall_count_ok=true; fi
judge '(1) recall の合格記録が3件以上' "$recall_count_ok" \
  "$recall_log" '[OK] の行が3件以上' "${ok_count}件" \
  'bash exercises/labctl.sh recall に合格すること'

recall_day_ok=false
if ((day_count >= 2)); then recall_day_ok=true; fi
judge '(2) recall の合格日が2種類以上' "$recall_day_ok" \
  "$recall_log" '合格した日付が2種類以上' \
  "${day_count}種類（$(tr '\n' ' ' <"$day_list" | cut -c1-60)）" \
  '日を変えて実施すること。間隔をあけることが定着の条件です'

# --- (3) talk.md の7語の順 --------------------------------------------------
# 各語が最初に出てくる「行番号と行内の位置」を取り、その並びが昇順かを見ます。
first_position() {
  local file=$1 needle=$2
  awk -v needle="$needle" '
    { position = index($0, needle); if (position > 0) { printf "%06d%06d\n", NR, position; exit } }
  ' "$file"
}

words=('5語' '0' '1' '2' 'ドライラン' '冪等' '証跡')
order_ok=true
previous=''
found_description=''
for word in "${words[@]}"; do
  position=$(first_position "$talk" "$word")
  if [[ -z $position ]]; then
    order_ok=false
    found_description="$found_description ${word}=なし"
    continue
  fi
  found_description="$found_description ${word}=$((10#${position:0:6}))行目"
  if [[ -n $previous ]] && ! [[ $position > $previous ]]; then
    order_ok=false
  fi
  previous=$position
done
judge '(3) talk.md に7語が順に現れる' "$order_ok" \
  "$talk" '5語 → 0 → 1 → 2 → ドライラン → 冪等 → 証跡 の順に最初の出現があること' \
  "${found_description# }" \
  '7語をこの順に使って台本を組み立てること'

# --- (4)(5) 進捗表 ----------------------------------------------------------
assert_file '(4) progress.md がある' "$progress_md" --nonempty

id_found=0
missing_ids=''
for number in $(seq -w 1 20); do
  if [[ -f $progress_md ]] && grep -Fq -- "| E$number |" "$progress_md"; then
    id_found=$((id_found + 1))
  else
    missing_ids="$missing_ids E$number"
  fi
done
progress_rows_ok=false
if ((id_found == 20)); then progress_rows_ok=true; fi
judge '(5) progress.md に E01〜E20 の20行がある' "$progress_rows_ok" \
  "$progress_md" 'E01 から E20 までの20行' "${id_found}行（不足:${missing_ids:- なし}）" \
  'bash exercises/labctl.sh progress --save を実行すること'

lab_finish
