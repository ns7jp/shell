#!/usr/bin/env bash
set -Eeuo pipefail

# E10 の採点です。ドライラン既定（先に言う、後でやる）ができているかを確かめます。
LAB_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=exercises/lib/lab_common.sh
# shellcheck disable=SC1091
source "$LAB_DIR/lib/lab_common.sh"
# shellcheck source=exercises/lib/assert.sh
# shellcheck disable=SC1091
source "$LAB_DIR/lib/assert.sh"

lab_begin E10
lab_stage 'L3/dry.sh'
script=$LAB_STAGED

# 採点はサンドボックスの中だけで行います（問題文の8節で開示しています）。
dry_dest="$LAB_SANDBOX/out/dry"
run_dest="$LAB_SANDBOX/out/run"

assert_static '変更するコマンドを run_or_show に渡している' "$script" --must 'run_or_show'

# (a) --execute なし: 予定を見せるだけで、何も作りません。
assert_status 'DRYRUN --execute なしで終了コード0' 0 -- bash "$script" --dest "$dry_dest"
assert_contains 'DRYRUN 標準出力に [DRY-RUN] が出る' "$LAB_STDOUT" '[DRY-RUN]'
assert_file 'DRYRUN_SIDE_EFFECT ドライランでは作られない' "$dry_dest" --absent

# (b) --execute あり: このときだけ実際に作ります。
assert_status 'EXECUTE --execute ありで終了コード0' 0 -- bash "$script" --dest "$run_dest" --execute
if [[ -d $run_dest ]]; then
  lab_ok 'EXECUTE 指定した場所がディレクトリとして作られている'
else
  # 単一引用符の中は学習者へ見せる説明文です（展開しません）。
  # shellcheck disable=SC2016
  lab_not_ok 'EXECUTE 指定した場所がディレクトリとして作られている' "$run_dest" \
    'ディレクトリとして存在すること' \
    "$([[ -e $run_dest ]] && printf 'ディレクトリではありません' || printf '存在しません')" \
    'run_or_show "$execute" mkdir -p -- "$DEST" の1行'
fi

lab_finish
