#!/usr/bin/env bash
set -Eeuo pipefail

# E03 の採点です。共通ライブラリの log を使って1行だけ出せているかを確かめます。
LAB_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=exercises/lib/lab_common.sh
# shellcheck disable=SC1091
source "$LAB_DIR/lib/lab_common.sh"
# shellcheck source=exercises/lib/assert.sh
# shellcheck disable=SC1091
source "$LAB_DIR/lib/assert.sh"

lab_begin E03
lab_stage 'L0/hello.sh'
script=$LAB_STAGED

assert_static '書式を自作していない（printf と echo を使わない）' "$script" \
  --must 'log[[:space:]]+INFO' --must-not 'printf' --must-not 'echo'
assert_status '実行して終了コード0' 0 -- bash "$script"

line_count=$(wc -l <"$LAB_STDOUT")
assert_equal '標準出力がちょうど1行' '1' "$line_count" "$script"

if grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[+-][0-9]{4} \[INFO\] こんにちは$' "$LAB_STDOUT"; then
  lab_ok '「日時 [INFO] こんにちは」の書式'
else
  lab_not_ok '「日時 [INFO] こんにちは」の書式' "$script" \
    '2026-01-01T00:00:00+0900 [INFO] こんにちは の形' "$(lab_head "$LAB_STDOUT")" \
    'log INFO こんにちは の1行（日時や角括弧は log が付けます）'
fi

lab_finish
