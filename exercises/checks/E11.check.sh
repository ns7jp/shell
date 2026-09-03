#!/usr/bin/env bash
set -Eeuo pipefail

# E11 の採点です。2回続けて実行しても結果が変わらないか（冪等）を確かめます。
LAB_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=exercises/lib/lab_common.sh
# shellcheck disable=SC1091
source "$LAB_DIR/lib/lab_common.sh"
# shellcheck source=exercises/lib/assert.sh
# shellcheck disable=SC1091
source "$LAB_DIR/lib/assert.sh"

lab_begin E11
lab_stage 'L3/idem.sh'
script=$LAB_STAGED

# 採点はサンドボックスの中だけで行います（問題文の8節で開示しています）。
work="$LAB_SANDBOX/work"
first_list="$LAB_SANDBOX/first.list"
second_list="$LAB_SANDBOX/second.list"

lab_file_list() {
  local target=$1 output=$2
  : >"$output"
  [[ -d $target ]] || return 0
  find "$target" -type f -printf '%P\n' 2>/dev/null | LC_ALL=C sort >"$output" || true
}

assert_static '構文が通り mkdir と install を使っている' "$script" \
  --must 'mkdir' --must 'install'

# --- 1回目 -----------------------------------------------------------------
assert_status '1回目 終了コード0' 0 -- bash "$script" --dest "$work"
first_hash=$(lab_state_hash "$work")
lab_file_list "$work" "$first_list"
first_count=$(wc -l <"$first_list")

assert_file '1回目に成果物ができている' "$work/conf/app.conf" --nonempty
assert_file '成果物の権限が 644 で固定されている' "$work/conf/app.conf" --mode 644

# --- 2回目 -----------------------------------------------------------------
assert_status '2回目 終了コード0' 0 -- bash "$script" --dest "$work"
lab_file_list "$work" "$second_list"
second_count=$(wc -l <"$second_list")

added=$(comm -13 "$first_list" "$second_list" | head -n 3 | tr '\n' ' ')
if [[ -z $added ]]; then
  lab_ok "NOT_IDEMPOTENT 2回目にファイルが増えない（${first_count} 個のまま）"
else
  lab_not_ok "NOT_IDEMPOTENT 2回目にファイルが増えない（${first_count} 個のまま）" "$work" \
    "ファイル数 $first_count" "ファイル数 $second_count（増えた: $added）" \
    '成果物の名前に日時や乱数を入れない書き方（mkdir -p / install -D）'
fi

assert_file '2回目も状態ハッシュが1回目と同じ' "$work" --hash "$first_hash"

lab_finish
