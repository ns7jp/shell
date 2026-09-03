#!/usr/bin/env bash
# E08 模範解答: 判定は自作せず require_integer_range に任せます。
set -Eeuo pipefail

source "${LAB_COMMON:?LAB_COMMON が未設定です。source \"$HOME/bash-lab/labenv.sh\" を実行してください}"

# --- 受ける ----------------------------------------------------------------
PORT=${PORT:-}
[[ -n $PORT ]] || die 'PORT は必須です'

# --- 疑う（形と範囲をまとめて1行） -----------------------------------------
require_integer_range PORT "$PORT" 1 65535

# --- 伝える ----------------------------------------------------------------
log OK "PORT=$PORT は使えます"
