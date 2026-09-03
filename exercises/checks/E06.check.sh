#!/usr/bin/env bash
set -Eeuo pipefail

# E06 の採点です。差分テストです。同じ6ケースを学習者の答案と模範解答の両方に流し、
# 終了コードの一致だけを見ます。正常ケースでは出力キー3つも見ます。
# メッセージ本文・行順・その他の出力は比較しません（日本語の言い回しでは落ちません）。
LAB_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=exercises/lib/lab_common.sh
# shellcheck disable=SC1091
source "$LAB_DIR/lib/lab_common.sh"
# shellcheck source=exercises/lib/assert.sh
# shellcheck disable=SC1091
source "$LAB_DIR/lib/assert.sh"

lab_begin E06
lab_stage 'L1/argparse2.sh'
script=$LAB_STAGED
reference="$LAB_DIR/answers/E06.ref.sh"
[[ -f $reference ]] || lab_error "模範解答がありません: $reference"

config_value='/opt/app/app.conf'
output_value='/opt/app/report.txt'
cases_passed=0

printf '# 6ケース: NORMAL / CONFIG_NO_VALUE / OUTPUT_NO_VALUE / UNKNOWN_ARG / HELP / NO_ARGS\n'

# (1) NORMAL: 正常な指定。終了コードの一致に加えて、出力キー3つを見ます。
before=$LAB_FAIL
assert_ref_status 'NORMAL: 終了コードが模範解答と一致' "$script" "$reference" -- \
  --config "$config_value" --output "$output_value" --execute
assert_contains "NORMAL: config=$config_value を出す" "$LAB_BOTH" "config=$config_value"
assert_contains "NORMAL: output=$output_value を出す" "$LAB_BOTH" "output=$output_value"
assert_contains 'NORMAL: execute=true を出す' "$LAB_BOTH" 'execute=true'
if ((LAB_FAIL == before)); then cases_passed=$((cases_passed + 1)); fi

# (2) CONFIG_NO_VALUE: --config を値なしで指定。
before=$LAB_FAIL
assert_ref_status 'CONFIG_NO_VALUE: 終了コードが模範解答と一致' "$script" "$reference" -- --config
if ((LAB_FAIL == before)); then cases_passed=$((cases_passed + 1)); fi

# (3) OUTPUT_NO_VALUE: --output を値なしで指定。
before=$LAB_FAIL
assert_ref_status 'OUTPUT_NO_VALUE: 終了コードが模範解答と一致' "$script" "$reference" -- \
  --config "$config_value" --output
if ((LAB_FAIL == before)); then cases_passed=$((cases_passed + 1)); fi

# (4) UNKNOWN_ARG: 知らない引数。
before=$LAB_FAIL
assert_ref_status 'UNKNOWN_ARG: 終了コードが模範解答と一致' "$script" "$reference" -- --zzz
if ((LAB_FAIL == before)); then cases_passed=$((cases_passed + 1)); fi

# (5) HELP: --help。
before=$LAB_FAIL
assert_ref_status 'HELP: 終了コードが模範解答と一致' "$script" "$reference" -- --help
if ((LAB_FAIL == before)); then cases_passed=$((cases_passed + 1)); fi

# (6) NO_ARGS: 引数なし。
before=$LAB_FAIL
assert_ref_status 'NO_ARGS: 終了コードが模範解答と一致' "$script" "$reference" --
if ((LAB_FAIL == before)); then cases_passed=$((cases_passed + 1)); fi

printf '# 6ケース中 %d 件通過\n' "$cases_passed"

lab_finish
