#!/usr/bin/env bash
# E18 模範解答: 証跡テンプレートの9項目を、テンプレートと同じ順で出します。
# 判定は --status で受けた終了コードから導きます。固定文字列にはしません。
set -Eeuo pipefail

source "${LAB_COMMON:?LAB_COMMON が未設定です。source \"$HOME/bash-lab/labenv.sh\" を実行してください}"

usage() {
  printf '%s\n' 'Usage: evidence.sh --status N [--id EXX]' '証跡テンプレートの9項目を標準出力へ出します。'
}

# --- 受ける ----------------------------------------------------------------
status=''
test_id='E18'
while (($#)); do
  case "$1" in
    --status) [[ $# -ge 2 ]] || die '--status に値が必要です'; status=$2; shift 2 ;;
    --id) [[ $# -ge 2 ]] || die '--id に値が必要です'; test_id=$2; shift 2 ;;
    -h|--help) usage; exit "$EXIT_OK" ;;
    *) die "不明な引数です: $1" ;;
  esac
done

# --- 疑う ------------------------------------------------------------------
[[ -n $status ]] || die '--status は必須です'
require_integer_range STATUS "$status" 0 255

# --- 動かす（終了コードから判定を導きます） --------------------------------
if ((status == 0)); then
  verdict=PASS
else
  verdict=FAIL
fi

# --- 伝える（docs/05-test-plan.md の証跡テンプレートと同じ順です） ----------
printf '%s\n' \
  "テストID: $test_id" \
  "日時・タイムゾーン: $(timestamp)" \
  "実行者: $(id -un)" \
  "環境(OS/Bash/commit): $(uname -sr) / Bash $BASH_VERSION / $(git rev-parse --short HEAD 2>/dev/null || printf '不明')" \
  "実行コマンド: bash exercises/labctl.sh grade $test_id" \
  "期待結果: 終了コード0（全判定を満たす）" \
  "実結果: 終了コード $status" \
  "終了コード: $status" \
  "判定(PASS/FAIL/NOT RUN): $verdict"
