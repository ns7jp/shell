#!/usr/bin/env bash
set -Eeuo pipefail

# E08 の採点です。範囲チェックを共通関数に任せているかを確かめます。
LAB_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=exercises/lib/lab_common.sh
# shellcheck disable=SC1091
source "$LAB_DIR/lib/lab_common.sh"
# shellcheck source=exercises/lib/assert.sh
# shellcheck disable=SC1091
source "$LAB_DIR/lib/assert.sh"

lab_begin E08
lab_stage 'L2/port.sh'
script=$LAB_STAGED

# 車輪の再発明の検査です。判定を自作すると、この1件だけが落ちます。
assert_static 'REINVENTED 判定を自作していない' "$script" \
  --must 'require_integer_range' --must-not '=~' --must-not '\^\[0-9'

assert_status 'PORT=80 は終了コード0' 0 -- env PORT=80 bash "$script"

assert_status 'PORT=0 は終了コード2' 2 -- env PORT=0 bash "$script"
assert_contains 'PORT=0 の理由が「1 から 65535 の範囲」' "$LAB_BOTH" '1 から 65535 の範囲'

assert_status 'PORT=70000 は終了コード2' 2 -- env PORT=70000 bash "$script"
assert_contains 'PORT=70000 の理由が「1 から 65535 の範囲」' "$LAB_BOTH" '1 から 65535 の範囲'

assert_status 'PORT=abc は終了コード2' 2 -- env PORT=abc bash "$script"
assert_contains 'PORT=abc の理由が「整数で指定してください」' "$LAB_BOTH" '整数で指定してください'

lab_finish
