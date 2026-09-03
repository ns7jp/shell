#!/usr/bin/env bash
set -Eeuo pipefail

# Bash演習案件パックの操作コマンドです。
# まず覚えるのは3つだけです: init / show / grade

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=exercises/lib/lab_common.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/lab_common.sh"

usage() {
  # 使い方の説明文なので $HOME は展開しません。
  # shellcheck disable=SC2016
  printf '%s\n' \
    'Usage: bash exercises/labctl.sh <サブコマンド> [引数]' \
    '' \
    'まず覚える3つ' \
    '  init            $HOME/bash-lab に作業場を作り、続けて環境点検をします' \
    '  show EXX        問題文を表示します' \
    '  grade EXX       1問を採点します（0=合格 1=不合格 2=実行エラー）' \
    '' \
    'そのほか' \
    '  doctor          環境点検だけを実行します' \
    '  list [--level L2]        演習一覧と現在の合否' \
    '  start EXX       作業ファイルと雛形を置きます（既存の答案は上書きしません）' \
    '  hint EXX [--step N]      ヒントを1段階だけ開きます' \
    '  answer EXX [--diff]      模範解答を表示します（--diff は差分だけ）' \
    '  grade --all     全問採点します' \
    '  card [--deck spine|exitcodes|messages|order]  暗記カードを出題します' \
    '  recall          何も見ずに入力して照合する自由再生テスト' \
    '  review          今日やる復習を表示します' \
    '  progress [--save]        進捗表を表示・保存します' \
    '  evidence EXX    証跡テンプレート形式で出力します' \
    '  selfcheck       採点器自身の自動テスト（CI用）'
}

# --- 進捗の記録 -------------------------------------------------------------
# 列: 演習ID 状態 初回合格日 最終合格日 次回期日 試行回数 ヒント段数 解答閲覧
lab_progress_init() {
  mkdir -p -- "$LAB_PROGRESS_DIR"
  [[ -f $LAB_PROGRESS ]] || printf '%s\n' '# 演習ID	状態	初回合格日	最終合格日	次回期日	試行回数	ヒント段数	解答閲覧	復習回数' >"$LAB_PROGRESS"
}

# 復習は D1 / D3 / D7 / D21 の4回だけです。合格するたびに次の節目へ進めます。
lab_next_due() {
  local reviews=$1 today=$2 interval
  case "$reviews" in
    0) interval=1 ;;
    1) interval=3 ;;
    2) interval=7 ;;
    3) interval=21 ;;
    *) printf '定着済み'; return 0 ;;
  esac
  date -d "$today +$interval day" '+%Y-%m-%d' 2>/dev/null || printf '%s' "$today"
}

lab_progress_get() {
  local id=$1 column=$2
  [[ -f $LAB_PROGRESS ]] || { printf ''; return 0; }
  awk -F'\t' -v id="$id" -v c="$column" '$1 == id {print $c; exit}' "$LAB_PROGRESS"
}

# 途中状態のファイルを残さないよう、同じディレクトリで作ってから置き換えます。
lab_progress_set() {
  local id=$1 status=$2 hint=$3 view=$4
  lab_progress_init
  local today first last due attempts previous_hint previous_view reviews temporary
  today=$(date '+%Y-%m-%d')
  first=$(lab_progress_get "$id" 3)
  last=$(lab_progress_get "$id" 4)
  due=$(lab_progress_get "$id" 5)
  attempts=$(lab_progress_get "$id" 6)
  previous_hint=$(lab_progress_get "$id" 7)
  previous_view=$(lab_progress_get "$id" 8)
  reviews=$(lab_progress_get "$id" 9)
  [[ -n $attempts ]] || attempts=0
  [[ $reviews =~ ^[0-9]+$ ]] || reviews=0
  attempts=$((attempts + 1))
  [[ $hint == '-' ]] && hint=${previous_hint:-0}
  [[ $view == '-' ]] && view=${previous_view:-no}
  if [[ $status == PASS ]]; then
    # 同じ日に何度合格しても、復習の節目は1つしか進めません。
    if [[ $last != "$today" ]]; then
      due=$(lab_next_due "$reviews" "$today")
      reviews=$((reviews + 1))
    fi
    [[ -n $first ]] || first=$today
    last=$today
  fi
  temporary=$(mktemp "$LAB_PROGRESS_DIR/.progress.XXXXXX")
  awk -F'\t' -v id="$id" '$1 != id' "$LAB_PROGRESS" >"$temporary"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$id" "$status" "${first:--}" "${last:--}" "${due:--}" "$attempts" "${hint:-0}" "${view:-no}" "$reviews" >>"$temporary"
  LC_ALL=C sort -o "$temporary" "$temporary"
  mv -- "$temporary" "$LAB_PROGRESS"
}

lab_status_of() {
  local value
  value=$(lab_progress_get "$1" 2)
  printf '%s' "${value:-未着手}"
}

# --- init / doctor ----------------------------------------------------------
cmd_init() {
  local refresh=false
  while (($#)); do
    case "$1" in
      --refresh) refresh=true; shift ;;
      -h|--help) usage; exit "$EXIT_OK" ;;
      *) lab_error "不明な引数です: $1" ;;
    esac
  done
  mkdir -p -- "$LAB_HOME" "$LAB_PROGRESS_DIR"
  local level
  for level in L0 L1 L2 L3 L4 L5 L6; do
    mkdir -p -- "$LAB_HOME/$level"
  done
  local env_file="$LAB_HOME/labenv.sh"
  if [[ -f $env_file && $refresh == false ]]; then
    log INFO "既存の設定を残しました: $env_file （作り直すには --refresh）"
  else
    cat >"$env_file" <<ENV
# labctl.sh init が作りました。各演習の最初に読み込みます。
export LAB_REPO_DIR='$LAB_REPO_DIR'
export LAB_COMMON='$LAB_REPO_DIR/scripts/lib/common.sh'
export LAB_FIXTURES='$LAB_REPO_DIR/exercises/fixtures'
ENV
    log OK "作業場の設定を作りました: $env_file"
  fi
  lab_progress_init
  log OK "作業場を用意しました: $LAB_HOME"
  log INFO '次は: bash exercises/labctl.sh show E01'
  cmd_doctor
}

lab_report() {
  local level=$1 label=$2 detail=$3
  log "$level" "$label: $detail"
}

cmd_doctor() {
  local warnings=0
  log INFO '環境点検を始めます'
  if ((BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 4))); then
    lab_report OK 'Bash 4.4以上' "${BASH_VERSION}"
  else
    lab_error "Bash 4.4以上が必要です: 現在 ${BASH_VERSION}"
  fi
  command -v python3 >/dev/null 2>&1 || lab_error 'python3 が必要です（E17 の証跡変換で使います）'
  lab_report OK 'python3' "$(python3 --version 2>&1)"
  local required
  for required in find tar gzip timeout sha256sum diff awk sed grep; do
    if command -v "$required" >/dev/null 2>&1; then
      lab_report OK "必須コマンド $required" 'あり'
    else
      lab_report WARN "必須コマンド $required" 'ありません。一部の採点ができません'
      warnings=$((warnings + 1))
    fi
  done
  if command -v shellcheck >/dev/null 2>&1; then
    lab_report OK 'shellcheck' "$(shellcheck --version 2>/dev/null | awk '/version:/{print $2}')"
  else
    lab_report WARN 'shellcheck' 'ありません。静的検査は NOT RUN になります（不合格にはなりません）'
    warnings=$((warnings + 1))
  fi
  if [[ -w $LAB_HOME ]]; then
    lab_report OK '作業場の書き込み' "$LAB_HOME"
  else
    lab_report WARN '作業場の書き込み' "$LAB_HOME に書けません。init を実行してください"
    warnings=$((warnings + 1))
  fi
  if [[ -f "$LAB_HOME/labenv.sh" ]]; then
    if grep -Fq "$LAB_REPO_DIR" "$LAB_HOME/labenv.sh"; then
      lab_report OK 'labenv.sh のパス' "$LAB_REPO_DIR"
    else
      lab_report WARN 'labenv.sh のパス' 'リポジトリの場所と違います。bash exercises/labctl.sh init --refresh を実行してください'
      warnings=$((warnings + 1))
    fi
  else
    lab_report WARN 'labenv.sh' 'ありません。bash exercises/labctl.sh init を実行してください'
    warnings=$((warnings + 1))
  fi
  if [[ $(id -u) -eq 0 ]]; then
    lab_report WARN '実行ユーザー' 'root で実行しています。学習は一般ユーザーを推奨します'
    warnings=$((warnings + 1))
  else
    lab_report OK '実行ユーザー' "$(id -un)"
  fi
  if ((warnings > 0)); then
    log WARN "環境点検: 注意 ${warnings} 件（採点は続行できます）"
  else
    log OK '環境点検: 問題ありません'
  fi
  return 0
}

# --- list / show ------------------------------------------------------------
cmd_list() {
  local filter=''
  while (($#)); do
    case "$1" in
      --level) [[ $# -ge 2 ]] || lab_error '--level に値が必要です'; filter=$2; shift 2 ;;
      -h|--help) usage; exit "$EXIT_OK" ;;
      *) lab_error "不明な引数です: $1" ;;
    esac
  done
  printf '%-5s %-4s %-6s %-3s %-38s %5s %s\n' 'ID' 'Lv' '5語' '段階' '題名' '目安分' '判定'
  local id
  for id in $(lab_ids); do
    lab_lookup "$id"
    [[ -z $filter || $LAB_LEVEL == "$filter" ]] || continue
    printf '%-5s %-4s %-6s %-3s %-38s %5s %s\n' \
      "$LAB_ID" "$LAB_LEVEL" "$LAB_SPINE" "$LAB_STAGE" "$LAB_TITLE" "$LAB_MINUTES" "$(lab_status_of "$id")"
  done
}

cmd_show() {
  [[ $# -ge 1 ]] || lab_error '演習IDを指定してください（例: show E01）'
  lab_lookup "$1" || lab_error "不明な演習IDです: $1"
  [[ -f $LAB_DOC ]] || lab_error "問題文がまだありません: $LAB_DOC"
  cat -- "$LAB_DOC"
}

# --- start ------------------------------------------------------------------
cmd_start() {
  [[ $# -ge 1 ]] || lab_error '演習IDを指定してください（例: start E01）'
  lab_lookup "$1" || lab_error "不明な演習IDです: $1"
  lab_require_lab_home
  mkdir -p -- "$(dirname -- "$LAB_WORKFILE")"
  local seed_dir="$LAB_FIXTURES/start/$LAB_ID"
  if [[ -d $seed_dir ]]; then
    local seed target
    while IFS= read -r seed; do
      target="$LAB_HOME/$LAB_LEVEL/$(basename -- "${seed%.broken}")"
      if [[ -e $target ]]; then
        log WARN "既にあるので残しました: $target"
      else
        cp -- "$seed" "$target"
        log OK "置きました: $target"
      fi
    done < <(find "$seed_dir" -maxdepth 1 -type f | LC_ALL=C sort)
  fi
  if [[ -e $LAB_WORKFILE ]]; then
    log WARN "既に答案があるので上書きしませんでした: $LAB_WORKFILE"
  elif [[ $LAB_TEMPLATE != '-' && -f "$LAB_DIR/templates/$LAB_TEMPLATE" ]]; then
    sed -e "s#@LAB_ID@#$LAB_ID#g" -e "s#@LAB_TITLE@#$LAB_TITLE#g" \
      -- "$LAB_DIR/templates/$LAB_TEMPLATE" >"$LAB_WORKFILE"
    log OK "雛形を置きました: $LAB_WORKFILE"
  else
    printf '' >"$LAB_WORKFILE"
    log OK "空のファイルを置きました: $LAB_WORKFILE"
  fi
  log INFO "編集するファイル: $LAB_WORKFILE"
  log INFO "採点コマンド: bash exercises/labctl.sh grade $LAB_ID"
}

# --- hint / answer ----------------------------------------------------------
cmd_hint() {
  [[ $# -ge 1 ]] || lab_error '演習IDを指定してください（例: hint E01）'
  lab_lookup "$1" || lab_error "不明な演習IDです: $1"
  shift
  local step=''
  while (($#)); do
    case "$1" in
      --step) [[ $# -ge 2 ]] || lab_error '--step に値が必要です'; step=$2; shift 2 ;;
      -h|--help) usage; exit "$EXIT_OK" ;;
      *) lab_error "不明な引数です: $1" ;;
    esac
  done
  [[ -f $LAB_HINTS ]] || lab_error "ヒントがまだありません: $LAB_HINTS"
  if [[ -z $step ]]; then
    local opened
    opened=$(lab_progress_get "$LAB_ID" 7)
    [[ -n $opened ]] || opened=0
    step=$((opened + 1))
    ((step <= 3)) || step=3
  fi
  [[ $step =~ ^[1-3]$ ]] || lab_error '--step は 1 から 3 で指定してください'
  awk -v want="H$step" '
    $0 ~ "^## " want { printing = 1; print; next }
    printing && /^## / { exit }
    printing { print }
  ' "$LAB_HINTS"
  lab_progress_set "$LAB_ID" "$(lab_status_of "$LAB_ID")" "$step" '-'
  log INFO "ヒント${step}段目を開きました（記録します）。次は: bash exercises/labctl.sh grade $LAB_ID"
}

cmd_answer() {
  [[ $# -ge 1 ]] || lab_error '演習IDを指定してください（例: answer E01）'
  lab_lookup "$1" || lab_error "不明な演習IDです: $1"
  shift
  local diff_only=false
  while (($#)); do
    case "$1" in
      --diff) diff_only=true; shift ;;
      -h|--help) usage; exit "$EXIT_OK" ;;
      *) lab_error "不明な引数です: $1" ;;
    esac
  done
  local reference reference_dir="$LAB_DIR/answers/$LAB_ID.ref"
  if [[ -d $reference_dir ]]; then
    # 複数ファイルの模範解答は、作業ファイルと同じ相対パスのものを見せます。
    reference="$reference_dir/$LAB_WORK"
    [[ -f $reference ]] || lab_error "模範解答が見つかりません: $reference"
  else
    reference=$(lab_reference_file "$LAB_ID") || lab_error "模範解答がありません: $LAB_ID"
  fi
  if [[ $diff_only == true ]]; then
    [[ -f $LAB_WORKFILE ]] || lab_error "自分の答案がありません: $LAB_WORKFILE"
    log INFO '左が自分の答案、右が模範解答です'
    diff -u "$LAB_WORKFILE" "$reference" || true
    lab_progress_set "$LAB_ID" "$(lab_status_of "$LAB_ID")" '-' 'diff'
  else
    cat -- "$reference"
    lab_progress_set "$LAB_ID" "$(lab_status_of "$LAB_ID")" '-' 'full'
    log WARN '全文を開いたことを記録しました。3日後の復習で必ず白紙から書き直してください'
  fi
}

# 模範解答は1ファイル形式（EXX.ref.拡張子）とディレクトリ形式（EXX.ref/）の2種類です。
lab_reference_file() {
  local id=$1 candidate
  for candidate in "$LAB_DIR/answers/$id".ref.*; do
    [[ -f $candidate ]] && { printf '%s' "$candidate"; return 0; }
  done
  return 1
}

# --- grade ------------------------------------------------------------------
cmd_grade() {
  [[ $# -ge 1 ]] || lab_error '演習IDまたは --all を指定してください'
  if [[ $1 == '--all' ]]; then
    cmd_grade_all
    return
  fi
  lab_lookup "$1" || lab_error "不明な演習IDです: $1"
  lab_require_lab_home
  [[ -f $LAB_CHECK ]] || lab_error "採点スクリプトがまだありません: $LAB_CHECK"
  local status=0
  bash "$LAB_CHECK" || status=$?
  case "$status" in
    0) lab_progress_set "$LAB_ID" PASS '-' '-' ;;
    1) lab_progress_set "$LAB_ID" FAIL '-' '-' ;;
    *) ;;
  esac
  return "$status"
}

cmd_grade_all() {
  local id status worst=0 passed=0 failed=0 errored=0
  for id in $(lab_ids); do
    lab_lookup "$id"
    [[ -f $LAB_CHECK ]] || continue
    status=0
    bash "$LAB_CHECK" >/dev/null 2>&1 || status=$?
    case "$status" in
      0) lab_progress_set "$id" PASS '-' '-'; passed=$((passed + 1)); printf 'ok - %s %s\n' "$id" "$LAB_TITLE" ;;
      1) lab_progress_set "$id" FAIL '-' '-'; failed=$((failed + 1)); printf 'not ok - %s %s\n' "$id" "$LAB_TITLE"
         ((worst < 1)) && worst=1 ;;
      *) errored=$((errored + 1)); printf 'not run - %s %s # 実行エラー(終了%s)\n' "$id" "$LAB_TITLE" "$status"; worst=2 ;;
    esac
  done
  printf '# pass=%d fail=%d error=%d\n' "$passed" "$failed" "$errored"
  return "$worst"
}

# --- card / recall / review -------------------------------------------------
cmd_card() {
  local deck=''
  while (($#)); do
    case "$1" in
      --deck) [[ $# -ge 2 ]] || lab_error '--deck に値が必要です'; deck=$2; shift 2 ;;
      -h|--help) usage; exit "$EXIT_OK" ;;
      *) lab_error "不明な引数です: $1" ;;
    esac
  done
  local id_column deck_column front back related
  while IFS=$'\t' read -r id_column deck_column front back related; do
    [[ $id_column == \#* || -z $id_column ]] && continue
    [[ -z $deck || $deck_column == "$deck" ]] || continue
    printf '\n[%s/%s] %s\n' "$id_column" "$deck_column" "$front"
    printf '    → %s（関連: %s）\n' "$back" "$related"
  done <"$LAB_CARDS"
  printf '\n'
  log INFO '表を見て、裏を声に出してから答え合わせをしてください'
}

cmd_recall() {
  lab_require_lab_home
  lab_progress_init
  local answer_spine answer_codes answer_bones failures=0
  printf '何も見ずに答えてください。3問すべて正解で合格です。\n\n'
  printf '問1: 5語スパインを、順番に読点区切りで入力してください\n> '
  read -r answer_spine || true
  printf '問2: 終了コード 0 / 1 / 2 の意味を、半角スペース区切りで3語（無事 注意 無理）\n> '
  read -r answer_codes || true
  printf '問3: 骨9要素の3番目は何ですか（日本語で）\n> '
  read -r answer_bones || true
  local normalized_spine
  normalized_spine=$(printf '%s' "$answer_spine" | tr -d '[:space:]、,・')
  [[ $normalized_spine == '受ける疑う動かす確かめる伝える' ]] || { printf 'x 問1が違います。正解: 受ける、疑う、動かす、確かめる、伝える\n'; failures=$((failures + 1)); }
  local normalized_codes
  normalized_codes=$(printf '%s' "$answer_codes" | tr -d '[:space:]、,・')
  [[ $normalized_codes == '無事注意無理' ]] || { printf 'x 問2が違います。正解: 無事 注意 無理\n'; failures=$((failures + 1)); }
  printf '%s' "$answer_bones" | grep -Fq '共通ライブラリ' || { printf 'x 問3が違います。正解: 共通ライブラリ読込\n'; failures=$((failures + 1)); }
  if ((failures == 0)); then
    log OK '自由再生テスト: 3問正解' | tee -a "$LAB_PROGRESS_DIR/recall.log"
    return 0
  fi
  log WARN "自由再生テスト: ${failures} 問不正解" | tee -a "$LAB_PROGRESS_DIR/recall.log"
  return "$EXIT_WARNING"
}

cmd_review() {
  lab_require_lab_home
  lab_progress_init
  local today id status due blank_targets='E06 E09 E12 E15 E18 E19'
  today=$(date '+%Y-%m-%d')
  log INFO "今日 $today の復習です（上限20分）"
  printf '\n1) 暗記カード（5分）: bash exercises/labctl.sh card --deck spine\n'
  printf '\n2) 白紙から書き直す問題（今日が期日のもの）\n'
  local found=0
  for id in $blank_targets; do
    status=$(lab_status_of "$id")
    due=$(lab_progress_get "$id" 5)
    [[ $status == PASS ]] || continue
    if [[ -n $due && $due != '-' && $due < "$today" ]] || [[ $due == "$today" ]]; then
      lab_lookup "$id"
      printf '   - %s %s\n' "$id" "$LAB_TITLE"
      printf '     答案を history へ移して白紙から書き直します:\n'
      printf '     mkdir -p "%s/%s/history/%s" && mv "%s" "%s/%s/history/%s/"\n' \
        "$LAB_HOME" "$LAB_LEVEL" "$today" "$LAB_WORKFILE" "$LAB_HOME" "$LAB_LEVEL" "$today"
      printf '     bash exercises/labctl.sh start %s\n' "$id"
      found=$((found + 1))
    fi
  done
  ((found > 0)) || printf '   （今日が期日の問題はありません）\n'
  printf '\n3) 週1回: bash exercises/labctl.sh recall\n'
}

# --- progress / evidence ----------------------------------------------------
cmd_progress() {
  local save=false
  while (($#)); do
    case "$1" in
      --save) save=true; shift ;;
      -h|--help) usage; exit "$EXIT_OK" ;;
      *) lab_error "不明な引数です: $1" ;;
    esac
  done
  lab_progress_init
  local output="$LAB_PROGRESS_DIR/progress.md"
  {
    printf '# 演習パック進捗表\n\n'
    printf '| 演習ID | レベル | 5語 | 題名 | 判定 | 初回合格日 | 試行回数 | ヒント段数 | 解答閲覧 |\n'
    printf '|---|---|---|---|---|---|---:|---:|---|\n'
    local id
    for id in $(lab_ids); do
      lab_lookup "$id"
      printf '| %s | %s | %s | %s | %s | %s | %s | %s | %s |\n' \
        "$LAB_ID" "$LAB_LEVEL" "$LAB_SPINE" "$LAB_TITLE" "$(lab_status_of "$id")" \
        "$(lab_progress_get "$id" 3)" "$(lab_progress_get "$id" 6)" \
        "$(lab_progress_get "$id" 7)" "$(lab_progress_get "$id" 8)"
    done
  } >"$LAB_PROGRESS_DIR/.progress.md.tmp"
  if [[ $save == true ]]; then
    mv -- "$LAB_PROGRESS_DIR/.progress.md.tmp" "$output"
    log OK "進捗表を保存しました: $output"
    log INFO 'この表を docs/08-evidence.md の演習パック節へ貼ってください'
  else
    cat -- "$LAB_PROGRESS_DIR/.progress.md.tmp"
    rm -f -- "$LAB_PROGRESS_DIR/.progress.md.tmp"
  fi
}

cmd_evidence() {
  [[ $# -ge 1 ]] || lab_error '演習IDを指定してください（例: evidence E01）'
  lab_lookup "$1" || lab_error "不明な演習IDです: $1"
  local status
  status=$(lab_status_of "$LAB_ID")
  printf '%s\n' \
    "テストID: $LAB_ID（$LAB_LEVEL $LAB_TITLE）" \
    "日時・タイムゾーン: $(timestamp)" \
    "実行者: $(id -un)" \
    "環境(OS/Bash/commit): $(uname -sr) / Bash $BASH_VERSION / $(git -C "$LAB_REPO_DIR" rev-parse --short HEAD 2>/dev/null || printf '不明')" \
    "実行コマンド: bash exercises/labctl.sh grade $LAB_ID" \
    "期待結果: 終了コード0（全判定を満たす）" \
    "実結果: $status" \
    "終了コード: $([[ $status == PASS ]] && printf '0' || printf '未取得')" \
    "判定(PASS/FAIL/NOT RUN): $([[ $status == 未着手 ]] && printf 'NOT RUN' || printf '%s' "$status")" \
    "ログまたはスクリーンショット: " \
    "備考・課題ID: "
}

# --- selfcheck --------------------------------------------------------------
# 採点器そのものを検査します。「模範解答で合格」と「誤答で不合格」の両方を確かめます。
cmd_selfcheck() {
  local temporary_home pass=0 fail=0 total=0
  temporary_home=$(mktemp -d -t labselfcheck.XXXXXX)
  # shellcheck disable=SC2064
  trap "rm -rf -- '$temporary_home'" EXIT
  local id status reference_dir reference_file
  for id in $(lab_ids); do
    lab_lookup "$id"
    if [[ ! -f $LAB_CHECK ]]; then
      total=$((total + 1))
      printf 'not run - %s 採点スクリプト未作成\n' "$id"
      continue
    fi
    reference_dir="$LAB_DIR/answers/$id.ref"
    reference_file=$(lab_reference_file "$id" || true)
    if [[ ! -d $reference_dir && -z $reference_file ]]; then
      total=$((total + 1))
      printf 'not run - %s 模範解答未作成\n' "$id"
      continue
    fi
    # (1) 模範解答は合格すること
    rm -rf -- "$temporary_home/lab"
    LAB_HOME="$temporary_home/lab" bash "$SCRIPT_DIR/labctl.sh" init >/dev/null 2>&1
    lab_place_reference "$id" "$temporary_home/lab" "$reference_dir" "$reference_file"
    status=0
    LAB_HOME="$temporary_home/lab" bash "$LAB_CHECK" >"$temporary_home/out" 2>&1 || status=$?
    total=$((total + 1))
    if [[ $status == 0 ]]; then
      pass=$((pass + 1)); printf 'ok - %s 模範解答で合格\n' "$id"
    else
      fail=$((fail + 1)); printf 'not ok - %s 模範解答で合格（終了%s）\n' "$id" "$status"
      sed -n '1,20p' "$temporary_home/out" | sed 's/^/#   /'
    fi
    # (2) 誤答は不合格になること（採点器が常に合格を返す欠陥を防ぎます）
    # 誤答例は1問につき何本あっても構いません（EXX.wrong / EXX.wrong2 / EXX.wrong.d）。
    local wrong_dir="$LAB_DIR/answers/wrong/$id.wrong.d" wrong_case label
    for wrong_case in "$LAB_DIR/answers/wrong/$id".wrong*; do
      [[ -f $wrong_case ]] || continue
      label=$(basename -- "$wrong_case")
      rm -rf -- "$temporary_home/lab"
      LAB_HOME="$temporary_home/lab" bash "$SCRIPT_DIR/labctl.sh" init >/dev/null 2>&1
      lab_place_reference "$id" "$temporary_home/lab" '' "$wrong_case"
      status=0
      LAB_HOME="$temporary_home/lab" bash "$LAB_CHECK" >"$temporary_home/out" 2>&1 || status=$?
      total=$((total + 1))
      if [[ $status == 1 ]]; then
        pass=$((pass + 1)); printf 'ok - %s 誤答で不合格（%s）\n' "$id" "$label"
      else
        fail=$((fail + 1)); printf 'not ok - %s 誤答で不合格（%s / 終了%s）\n' "$id" "$label" "$status"
        sed -n '1,20p' "$temporary_home/out" | sed 's/^/#   /'
      fi
    done
    if [[ -d $wrong_dir ]]; then
      rm -rf -- "$temporary_home/lab"
      LAB_HOME="$temporary_home/lab" bash "$SCRIPT_DIR/labctl.sh" init >/dev/null 2>&1
      lab_place_reference "$id" "$temporary_home/lab" "$wrong_dir" ''
      status=0
      LAB_HOME="$temporary_home/lab" bash "$LAB_CHECK" >"$temporary_home/out" 2>&1 || status=$?
      total=$((total + 1))
      if [[ $status == 1 ]]; then
        pass=$((pass + 1)); printf 'ok - %s 誤答で不合格（%s.wrong.d）\n' "$id" "$id"
      else
        fail=$((fail + 1)); printf 'not ok - %s 誤答で不合格（%s.wrong.d / 終了%s）\n' "$id" "$id" "$status"
        sed -n '1,20p' "$temporary_home/out" | sed 's/^/#   /'
      fi
    fi
  done
  total=$((total + 1))
  if cmd_selfcheck_cards; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
  fi
  printf '1..%d\n' "$total"
  printf '# pass=%d fail=%d\n' "$pass" "$fail"
  ((fail == 0))
}

# 模範解答または誤答を作業場へ配置します。
# ディレクトリ形式は $LAB_HOME へそのまま展開し、1ファイル形式は作業ファイルへ複製します。
lab_place_reference() {
  local id=$1 home=$2 directory=$3 file=$4
  lab_lookup "$id"
  mkdir -p -- "$home/$(dirname -- "$LAB_WORK")"
  if [[ -n $directory && -d $directory ]]; then
    cp -a -- "$directory/." "$home/"
  elif [[ -n $file && -f $file ]]; then
    cp -- "$file" "$home/$LAB_WORK"
  fi
}

cmd_selfcheck_cards() {
  local count
  count=$(awk -F'\t' '!/^#/ && NF > 1' "$LAB_CARDS" | wc -l)
  if [[ $count != 17 ]]; then
    printf 'not ok - 暗記カードが17枚（実測 %s 枚）\n' "$count"
    return 1
  fi
  if awk -F'\t' '!/^#/ && ($3 ~ /何個|すべて挙げ/)' "$LAB_CARDS" | grep -q .; then
    printf 'not ok - 列挙型の丸暗記カードが混入しています\n'
    return 1
  fi
  printf 'ok - 暗記カード17枚・列挙型なし\n'
  return 0
}

# --- 入口 -------------------------------------------------------------------
main() {
  (($#)) || { usage; exit "$EXIT_OK"; }
  local subcommand=$1
  shift
  case "$subcommand" in
    init) cmd_init "$@" ;;
    doctor) cmd_doctor "$@" ;;
    list) cmd_list "$@" ;;
    show) cmd_show "$@" ;;
    start) cmd_start "$@" ;;
    hint) cmd_hint "$@" ;;
    answer) cmd_answer "$@" ;;
    grade) cmd_grade "$@" ;;
    card) cmd_card "$@" ;;
    recall) cmd_recall "$@" ;;
    review) cmd_review "$@" ;;
    progress) cmd_progress "$@" ;;
    evidence) cmd_evidence "$@" ;;
    selfcheck) cmd_selfcheck "$@" ;;
    -h|--help|help) usage ;;
    *) lab_error "不明なサブコマンドです: $subcommand （bash exercises/labctl.sh --help）" ;;
  esac
}

main "$@"
