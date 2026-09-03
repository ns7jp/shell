#!/usr/bin/env bash

# 演習パックの共通処理です。
# scripts/lib/common.sh を source してよいのはこのファイルだけです。
# ここで定義する変数と関数は、採点スクリプトと labctl.sh から使います。
# 同じファイル内で使い切らない変数があるため、未使用警告(SC2034)は外します。
# shellcheck disable=SC2034
# 既存の common.sh は readonly 変数を持つため、同じシェルで2回読み込むと失敗します。
# 次のガードにより、何度読み込んでも安全になります。
if [[ -n ${LAB_COMMON_LOADED:-} ]]; then
  return 0
fi
LAB_COMMON_LOADED=1

LAB_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
LAB_REPO_DIR=$(cd -- "$LAB_DIR/.." && pwd)
: "${LAB_COMMON:=$LAB_REPO_DIR/scripts/lib/common.sh}"
: "${LAB_FIXTURES:=$LAB_DIR/fixtures}"
: "${LAB_HOME:=$HOME/bash-lab}"
: "${LAB_TIMEOUT:=10}"
LAB_CATALOG="$LAB_DIR/exercises.tsv"
LAB_CARDS="$LAB_DIR/cards/cards.tsv"
LAB_PROGRESS_DIR="$LAB_HOME/progress"
LAB_PROGRESS="$LAB_PROGRESS_DIR/progress.tsv"
export LAB_DIR LAB_REPO_DIR LAB_COMMON LAB_FIXTURES LAB_HOME LAB_TIMEOUT

# shellcheck source=scripts/lib/common.sh
# shellcheck disable=SC1091
source "$LAB_COMMON"

# --- 演習カタログ -----------------------------------------------------------
# exercises.tsv の1行を読み、LAB_ID などの変数へ展開します。
lab_lookup() {
  local wanted=$1 line
  line=$(awk -F'\t' -v id="$wanted" '$1 == id {print; exit}' "$LAB_CATALOG")
  [[ -n $line ]] || return 1
  IFS=$'\t' read -r LAB_ID LAB_LEVEL LAB_SPINE LAB_STAGE LAB_TITLE LAB_MINUTES LAB_WORK LAB_TEMPLATE LAB_CARD <<<"$line"
  LAB_WORKFILE="$LAB_HOME/$LAB_WORK"
  LAB_DOC="$LAB_DIR/levels/$LAB_LEVEL/$LAB_ID.md"
  LAB_HINTS="$LAB_DIR/levels/$LAB_LEVEL/$LAB_ID.hints.md"
  LAB_CHECK="$LAB_DIR/checks/$LAB_ID.check.sh"
}

lab_ids() { awk -F'\t' '$1 ~ /^E[0-9]+$/ {print $1}' "$LAB_CATALOG"; }

# --- 停止と案内 -------------------------------------------------------------
# 採点できない状況は「実行エラー」として終了2で止めます（フェイルクローズ）。
lab_error() {
  log ERROR "$*" >&2
  exit "$EXIT_ERROR"
}

lab_require_lab_home() {
  [[ -d $LAB_HOME ]] || lab_error "作業場がありません。先に実行してください: bash exercises/labctl.sh init （見た場所: $LAB_HOME）"
}

# --- サンドボックス ---------------------------------------------------------
# 採点は毎回この使い捨てディレクトリの中だけで行います。
# 削除は「自分が作った labctl.* だけ」を確認してから行います。
lab_cleanup() {
  local keep=${LAB_KEEP_SANDBOX:-false}
  if [[ $keep == true ]]; then
    printf '# サンドボックスを残しました: %s\n' "${LAB_SANDBOX:-}"
    return 0
  fi
  [[ -n ${LAB_SANDBOX:-} && -d ${LAB_SANDBOX:-} && ${LAB_SANDBOX:-} == */labctl.* ]] || return 0
  rm -rf -- "$LAB_SANDBOX"
}

lab_sandbox() {
  LAB_SANDBOX=$(mktemp -d -t labctl.XXXXXXXX) || lab_error '一時ディレクトリを作成できません'
  trap 'lab_cleanup' EXIT
  LAB_STDOUT="$LAB_SANDBOX/.lab_stdout"
  LAB_STDERR="$LAB_SANDBOX/.lab_stderr"
  LAB_BOTH="$LAB_SANDBOX/.lab_both"
  : >"$LAB_STDOUT"
  : >"$LAB_STDERR"
  : >"$LAB_BOTH"
}

# 採点スクリプトの共通の入口です。
lab_begin() {
  lab_lookup "$1" || lab_error "不明な演習IDです: $1"
  LAB_EXERCISE=$LAB_ID
  lab_require_lab_home
  lab_sandbox
  printf '# %s %s（%s / %s）\n' "$LAB_ID" "$LAB_TITLE" "$LAB_LEVEL" "${LAB_SPINE}"
}

# 答案ファイルが無ければ採点せず終了2で止めます。
# 結果は変数 LAB_PATH に入れます（コマンド置換で呼ぶと exit が効かないためです）。
lab_need() {
  local relative=$1
  LAB_PATH="$LAB_HOME/$relative"
  [[ -e $LAB_PATH ]] || lab_error "答案がありません: $LAB_PATH （先に実行してください: bash exercises/labctl.sh start ${LAB_EXERCISE:-EXX}）"
}

# 答案をサンドボックスへ複製します。元の答案は読み取りだけで変更しません。
# 複製先は変数 LAB_STAGED に入ります。
lab_stage() {
  local relative=$1 name=${2:-}
  [[ -n $name ]] || name=$(basename -- "$relative")
  lab_need "$relative"
  cp -- "$LAB_PATH" "$LAB_SANDBOX/$name"
  LAB_STAGED="$LAB_SANDBOX/$name"
}

# --- 実行 -------------------------------------------------------------------
# 学習者のスクリプトは必ず子プロセスで、次の3つの制限をかけて動かします。
#   1. 時間制限（LAB_TIMEOUT秒）。終了しなければ SIGTERM、さらに5秒後に SIGKILL。
#   2. 出力量の制限（LAB_MAX_OUTPUT_KB）。書き出しすぎる答案でディスクを埋めません。
#   3. 独立したプロセスグループ。答案が裏で起動したプロセスも一緒に止めます。
: "${LAB_MAX_OUTPUT_KB:=20480}"

lab_run() {
  lab_run_env -- "$@"
}

# 追加の環境変数を渡して実行します（例: TARGET_SCRIPT や PATH の差し替え）。
lab_run_env() {
  local -a assignments=()
  while (($#)); do
    [[ $1 == '--' ]] && { shift; break; }
    assignments+=("$1")
    shift
  done
  LAB_STATUS=0
  (
    cd "$LAB_SANDBOX" || exit "$EXIT_ERROR"
    # ulimit -f は1プロセスが書けるファイルサイズの上限です（ブロック単位）。
    ulimit -f "$((LAB_MAX_OUTPUT_KB * 2))" 2>/dev/null || true
    env HOME="$LAB_SANDBOX" LC_ALL=C TZ=UTC \
      LAB_COMMON="$LAB_COMMON" LAB_FIXTURES="$LAB_FIXTURES" LAB_REPO_DIR="$LAB_REPO_DIR" \
      "${assignments[@]}" timeout --kill-after=5 "$LAB_TIMEOUT" "$@"
  ) >"$LAB_STDOUT" 2>"$LAB_STDERR" || LAB_STATUS=$?
  lab_sweep_leftovers
  lab_truncate_output "$LAB_STDOUT"
  lab_truncate_output "$LAB_STDERR"
  cat -- "$LAB_STDOUT" "$LAB_STDERR" >"$LAB_BOTH"
  return 0
}

# 答案が「&」で裏に流したプロセスは、時間制限では止まりません。
# サンドボックスを作業場所にしているプロセスだけを、採点のたびに片付けます。
lab_sweep_leftovers() {
  [[ -n ${LAB_SANDBOX:-} && ${LAB_SANDBOX:-} == */labctl.* ]] || return 0
  [[ -d /proc ]] || return 0
  local entry pid cwd
  for entry in /proc/[0-9]*; do
    pid=${entry#/proc/}
    [[ $pid == "$$" ]] && continue
    cwd=$(readlink -- "$entry/cwd" 2>/dev/null) || continue
    [[ $cwd == "$LAB_SANDBOX" || $cwd == "$LAB_SANDBOX"/* ]] || continue
    kill -TERM "$pid" 2>/dev/null || true
  done
}

# 出力が大きすぎる場合は先頭だけを残します（比較も表示もこれで足ります）。
lab_truncate_output() {
  local file=$1 limit=$((LAB_MAX_OUTPUT_KB * 1024))
  local size
  size=$(stat -c '%s' -- "$file" 2>/dev/null || printf '0')
  ((size > limit)) || return 0
  head -c "$limit" -- "$file" >"$file.trimmed"
  printf '\n[出力が %sKB を超えたため、ここで打ち切りました]\n' "$LAB_MAX_OUTPUT_KB" >>"$file.trimmed"
  mv -- "$file.trimmed" "$file"
}

# --- 正規化 -----------------------------------------------------------------
# 実行時刻・作業ディレクトリ・ホスト名の違いで誤って不合格にしないため、
# 比較の前に必ずこの関数を通します。
lab_normalize() {
  local host
  host=$(hostname 2>/dev/null || printf 'localhost')
  sed -E -e 's/\r$//' \
    -e 's/[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[+-][0-9]{4}/<TS>/g' \
    -e "s#${LAB_SANDBOX//#/\\#}#<LAB>#g" \
    -e "s#${LAB_HOME//#/\\#}#<HOME>#g" \
    -e "s/${host}/<HOST>/g"
}

# 成果物の状態指紋です。冪等性（2回やって同じ）の判定に使います。
lab_state_hash() {
  local target=$1
  {
    find "$target" -type f -printf '%P\n' 2>/dev/null | LC_ALL=C sort
    find "$target" -type f -exec sha256sum {} + 2>/dev/null | awk '{print $1}' | LC_ALL=C sort
  } | sha256sum | awk '{print $1}'
}
