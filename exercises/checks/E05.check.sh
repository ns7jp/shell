#!/usr/bin/env bash
set -Eeuo pipefail

# E05 の採点です。引数の4分岐が仕様どおりかを、サンドボックスで実行して確かめます。
# メッセージの文言は比較しません。見るのは終了コードと、指定した出力キーだけです。
LAB_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=exercises/lib/lab_common.sh
# shellcheck disable=SC1091
source "$LAB_DIR/lib/lab_common.sh"
# shellcheck source=exercises/lib/assert.sh
# shellcheck disable=SC1091
source "$LAB_DIR/lib/assert.sh"

lab_begin E05
lab_stage 'L1/argparse.sh'
script=$LAB_STAGED
sample='/opt/app/app.conf'
cases_passed=0

printf '# 4ケース: VALUE_OK / NO_VALUE / UNKNOWN_ARG / HELP\n'

# (a) VALUE_OK: --config に値を付けたら終了0で、config=値 を出します。
before=$LAB_FAIL
assert_status 'VALUE_OK: --config に値ありで終了0' 0 -- bash "$script" --config "$sample"
assert_contains "VALUE_OK: 標準出力に config=$sample" "$LAB_STDOUT" "config=$sample"
if ((LAB_FAIL == before)); then cases_passed=$((cases_passed + 1)); fi

# (b) NO_VALUE: --config を値なしで指定したら終了2です。
before=$LAB_FAIL
assert_status 'NO_VALUE: --config を値なしで指定すると終了2' 2 -- bash "$script" --config
if ((LAB_FAIL == before)); then cases_passed=$((cases_passed + 1)); fi

# (c) UNKNOWN_ARG: 知らない引数は終了2です。
before=$LAB_FAIL
assert_status 'UNKNOWN_ARG: --zzz は終了2' 2 -- bash "$script" --zzz
if ((LAB_FAIL == before)); then cases_passed=$((cases_passed + 1)); fi

# (d) HELP: --help は Usage: を出して終了0です。
before=$LAB_FAIL
assert_status 'HELP: --help は終了0' 0 -- bash "$script" --help
assert_contains 'HELP: 標準出力に Usage: を含む' "$LAB_STDOUT" 'Usage:'
if ((LAB_FAIL == before)); then cases_passed=$((cases_passed + 1)); fi

printf '# 4ケース中 %d 件通過\n' "$cases_passed"

lab_finish
