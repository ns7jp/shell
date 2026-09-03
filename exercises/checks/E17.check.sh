#!/usr/bin/env bash
set -Eeuo pipefail

# E17 の採点です。--output で残したログを audit_report.py に通し、JSON証跡を確かめます。
LAB_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=exercises/lib/lab_common.sh
# shellcheck disable=SC1091
source "$LAB_DIR/lib/lab_common.sh"
# shellcheck source=exercises/lib/assert.sh
# shellcheck disable=SC1091
source "$LAB_DIR/lib/assert.sh"

lab_begin E17
lab_stage 'L5/audit_run.sh'
script=$LAB_STAGED

# 採点のたびに状況をここで作ります（問題文の8節で開示しています）。
# a.txt だけがあり、残り2つがありません。つまり [WARN] はちょうど2行です。
mkdir -p -- "$LAB_SANDBOX/site"
printf 'a\n' >"$LAB_SANDBOX/site/a.txt"
config_path="$LAB_SANDBOX/audit.conf"
printf '%s\n' "TARGET_DIR='$LAB_SANDBOX/site'" \
  "CHECK_FILES='a.txt missing1.txt missing2.txt'" >"$config_path"
chmod 600 -- "$config_path"

log_path="$LAB_SANDBOX/evidence/audit.log"
json_path="$LAB_SANDBOX/evidence/audit.json"

assert_static '穴が埋まっている（tee があり __1__ が残っていない）' "$script" \
  --must 'tee' --must-not '^[^#]*__[0-9]__'

# tee は別プロセスです。ログを書き終えるまで最大5秒だけ待ちます（8節で開示しています）。
wait_for_log() {
  local path=$1 previous='' current='' attempt=0
  while ((attempt < 50)); do
    if [[ -s $path ]]; then
      current=$(wc -c <"$path")
      [[ $current == "$previous" ]] && return 0
      previous=$current
    fi
    sleep 0.1
    attempt=$((attempt + 1))
  done
  return 0
}

# 過去のログが混ざらないよう、実行前に必ず消します。
rm -f -- "$log_path" "$json_path"
lab_run bash "$script" --config "$config_path" --output "$log_path"
wait_for_log "$log_path"

assert_equal 'audit_run.sh の終了コード0' '0' "$LAB_STATUS" "$script"
assert_file '--output で指定した場所にログが残る' "$log_path" --nonempty

# --- ログをJSON証跡へ変換します --------------------------------------------
lab_run python3 "$LAB_REPO_DIR/scripts/audit_report.py" --input "$log_path" --output "$json_path"
report_status=$LAB_STATUS
if [[ $report_status == 1 ]]; then
  lab_ok 'audit_report.py の終了コードが1（WARN由来）'
else
  lab_not_ok 'audit_report.py の終了コードが1（WARN由来）' "$log_path" \
    '終了コード 1' "終了コード ${report_status}（audit_report.py の標準エラー: $(lab_head "$LAB_STDERR")）" \
    'log 関数だけで書かれたログ（日時と [LEVEL] を持たない行が1つでもあると終了2になります）'
fi
assert_file 'JSON証跡ができている' "$json_path" --nonempty

# --- JSON の中身を見ます ----------------------------------------------------
summary="$LAB_SANDBOX/.json_summary"
: >"$summary"
if [[ -s $json_path ]]; then
  python3 - "$json_path" >"$summary" 2>/dev/null <<'PYTHON' || :
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    report = json.load(handle)
print(report.get("result", ""))
print(report.get("counts", {}).get("WARN", ""))
print(len(report.get("entries", [])))
PYTHON
fi
json_result=$(sed -n 1p -- "$summary")
json_warn=$(sed -n 2p -- "$summary")
json_entries=$(sed -n 3p -- "$summary")
log_lines=$(grep -c '[^[:space:]]' -- "$log_path" 2>/dev/null || printf '0')

assert_equal 'JSON の result が WARN' 'WARN' "${json_result:-（JSONを読めません）}" "$json_path"
assert_equal 'JSON の counts.WARN が 2' '2' "${json_warn:-（JSONを読めません）}" "$json_path"
assert_equal 'JSON の entries の数がログの非空行数と一致' \
  "$log_lines" "${json_entries:-（JSONを読めません）}" "$json_path"

lab_finish
