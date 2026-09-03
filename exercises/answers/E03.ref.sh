#!/usr/bin/env bash
# E03 模範解答: 書式は自作せず、共通ライブラリの log に任せます。
set -Eeuo pipefail

source "${LAB_COMMON:?LAB_COMMON が未設定です。source \"$HOME/bash-lab/labenv.sh\" を実行してください}"

log INFO こんにちは
