#!/usr/bin/env bash
set -Eeuo pipefail

# E13 の採点です。tar のあとに成果物を読み直しているかを確かめます。
LAB_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=exercises/lib/lab_common.sh
# shellcheck disable=SC1091
source "$LAB_DIR/lib/lab_common.sh"
# shellcheck source=exercises/lib/assert.sh
# shellcheck disable=SC1091
source "$LAB_DIR/lib/assert.sh"

lab_begin E13
lab_stage 'L4/mkarc.sh'
script=$LAB_STAGED

# 採点のたびに、まとめる材料をここで作ります（問題文の8節で開示しています）。
mkdir -p -- "$LAB_SANDBOX/site"
printf 'hello\n' >"$LAB_SANDBOX/site/index.html"

# 仕掛け: 0バイトのアーカイブを作る偽の tar を、サンドボックス内だけに置きます。
# 通常のPATHの先頭に足すだけで、あなたの環境の tar は変更しません。
mkdir -p -- "$LAB_SANDBOX/fakebin"
cp -- "$LAB_FIXTURES/E13/fakebin/tar" "$LAB_SANDBOX/fakebin/tar"
chmod 755 -- "$LAB_SANDBOX/fakebin/tar"

assert_static '構文が通る（bash -n）' "$script"

# --- (a) 通常のPATH --------------------------------------------------------
assert_status 'NORMAL 終了コード0' 0 -- bash "$script" --src "$LAB_SANDBOX/site" --dst "$LAB_SANDBOX/arc1"
assert_contains 'NORMAL 標準出力に [OK] の行がある' "$LAB_STDOUT" '[OK]'

archive=$(find "$LAB_SANDBOX/arc1" -type f -print -quit 2>/dev/null) || archive=''
if [[ -n $archive && -s $archive ]]; then
  lab_ok 'NORMAL アーカイブが0バイトでない'
else
  lab_not_ok 'NORMAL アーカイブが0バイトでない' "$LAB_SANDBOX/arc1" \
    '中身のある tar.gz が1つできていること' \
    "$([[ -n $archive ]] && printf '0バイトです: %s' "$archive" || printf 'ファイルがありません')" \
    'tar でアーカイブを作る処理'
fi

# --- (b) 偽の tar を掴まされた環境（仕掛け: FAKE_TAR） ----------------------
lab_run_env "PATH=$LAB_SANDBOX/fakebin:$PATH" -- \
  bash "$script" --src "$LAB_SANDBOX/site" --dst "$LAB_SANDBOX/arc2"
if [[ $LAB_STATUS == 2 ]]; then
  lab_ok 'FAKE_TAR 終了コード2'
else
  lab_not_ok 'FAKE_TAR 終了コード2' "$script（この失敗は採点器の仕掛け（FAKE_TAR）のケースです）" \
    '終了コード2（0バイトのアーカイブを die で拒否する）' \
    "終了コード $LAB_STATUS" \
    'tar の直後の2つの確認（ある・中身）と、それぞれの || die'
fi
assert_contains 'FAKE_TAR 標準エラーに「アーカイブ」を含む理由が出る' "$LAB_STDERR" 'アーカイブ'

lab_finish
