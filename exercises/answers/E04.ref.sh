#!/usr/bin/env bash
# E04 模範解答: 骨9要素を spine.tmpl から手で写した状態です。
# 「9要素」であって「9行」ではありません。実物はこの通り40行前後になります。

# --- 1/9 shebang（このファイルをBashで動かす宣言） ---------------------------
# ↑ 1行目の #!/usr/bin/env bash が1つ目の要素です。

# --- 2/9 安全設定 -----------------------------------------------------------
set -Eeuo pipefail

# --- 3/9 共通ライブラリ読込（log / die / require_* / run_or_show を借ります） -
source "${LAB_COMMON:?LAB_COMMON が未設定です。source \"$HOME/bash-lab/labenv.sh\" を実行してください}"

# --- 4/9 usage（使い方の表示） ---------------------------- ここまでが「受ける」
usage() {
  printf '%s\n' 'Usage: spine.sh --config FILE [--execute]' '既定はドライランです。'
}

# --- 5/9 引数解析 -------------------------------------------------- 「受ける」
config_path=''
execute=false
while (($#)); do
  case "$1" in
    --config) [[ $# -ge 2 ]] || die '--config に値が必要です'; config_path=$2; shift 2 ;;
    --execute) execute=true; shift ;;
    -h|--help) usage; exit "$EXIT_OK" ;;
    *) die "不明な引数です: $1" ;;
  esac
done

# --- 6/9 入力検証（ある→形→範囲→場所） ---------------------------- 「疑う」
[[ -n $config_path ]] || die '--config は必須です'
load_config "$config_path"
[[ -n ${DEST_DIR:-} ]] || die 'DEST_DIR は必須です'
require_absolute_safe_path DEST_DIR "$DEST_DIR"

# --- 7/9 ドライラン既定の処理 ------------------------------------- 「動かす」
run_or_show "$execute" mkdir -p -- "$DEST_DIR"

# --- 8/9 成果物の確認 ------------------------------------------- 「確かめる」
if [[ $execute == true ]]; then
  [[ -s "$DEST_DIR/marker.txt" ]] || printf 'ok\n' >"$DEST_DIR/marker.txt"
  [[ -s "$DEST_DIR/marker.txt" ]] || die "成果物を確認できません: $DEST_DIR/marker.txt"
fi

# --- 9/9 ログと終了コード ----------------------------------------- 「伝える」
log OK '完了しました'
exit "$EXIT_OK"
