#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT
pass=0
fail=0
ok() { printf 'ok - %s\n' "$1"; ((pass += 1)); }
not_ok() { printf 'not ok - %s\n' "$1"; ((fail += 1)); }

assert_status() {
  local name=$1 expected=$2
  shift 2
  local actual=0
  "$@" >"$tmp_dir/output" 2>&1 || actual=$?
  if [[ $actual == "$expected" ]]; then ok "$name"; else not_ok "$name (expected=$expected actual=$actual)"; cat "$tmp_dir/output"; fi
}
assert_contains() {
  local name=$1 needle=$2
  if grep -Fq -- "$needle" "$tmp_dir/output"; then ok "$name"; else not_ok "$name"; cat "$tmp_dir/output"; fi
}

mkdir -p "$tmp_dir/source" "$tmp_dir/backups" "$tmp_dir/logs/archive"
printf 'test data\n' >"$tmp_dir/source/data.txt"
cat >"$tmp_dir/backup.conf" <<EOF
SOURCE_DIR=$tmp_dir/source
BACKUP_DIR=$tmp_dir/backups
RETENTION_DAYS=7
ARCHIVE_PREFIX=test
EOF
chmod 600 "$tmp_dir/backup.conf"

assert_status 'backup dry-run succeeds' 0 bash "$ROOT_DIR/scripts/backup.sh" --config "$tmp_dir/backup.conf"
assert_contains 'backup dry-run is visible' '[DRY-RUN]'
if [[ -z $(find "$tmp_dir/backups" -type f -print -quit) ]]; then
  ok 'dry-run creates no archive'
else
  not_ok 'dry-run creates no archive'
fi
assert_status 'backup execute succeeds' 0 bash "$ROOT_DIR/scripts/backup.sh" --config "$tmp_dir/backup.conf" --execute
archive=$(find "$tmp_dir/backups" -type f -name 'test_*.tar.gz' -print -quit)
if [[ -n $archive && -s $archive ]]; then
  ok 'execute creates archive'
else
  not_ok 'execute creates archive'
fi
if tar -tzf "$archive" | grep -Fq 'source/data.txt'; then
  ok 'archive contains source file'
else
  not_ok 'archive contains source file'
fi

cat >"$tmp_dir/unsafe.conf" <<'EOF'
SOURCE_DIR=/
BACKUP_DIR=/tmp/backup-test
RETENTION_DAYS=7
ARCHIVE_PREFIX=test
EOF
chmod 600 "$tmp_dir/unsafe.conf"
assert_status 'dangerous source path is rejected' 2 bash "$ROOT_DIR/scripts/backup.sh" --config "$tmp_dir/unsafe.conf"
assert_contains 'path rejection explains cause' '重要なシステムディレクトリ'

cat >"$tmp_dir/missing.conf" <<'EOF'
BACKUP_DIR=/tmp/backup-test
RETENTION_DAYS=7
ARCHIVE_PREFIX=test
EOF
chmod 600 "$tmp_dir/missing.conf"
assert_status 'missing required setting is rejected' 2 bash "$ROOT_DIR/scripts/backup.sh" --config "$tmp_dir/missing.conf"
assert_contains 'missing setting names the key' 'SOURCE_DIR は必須'

cat >"$tmp_dir/audit.conf" <<EOF
CPU_WARN_PERCENT=101
MEMORY_WARN_PERCENT=100
DISK_WARN_PERCENT=100
CHECK_SERVICES=""
LOG_DIR=$tmp_dir/logs
EOF
chmod 600 "$tmp_dir/audit.conf"
assert_status 'audit rejects invalid threshold' 2 bash "$ROOT_DIR/scripts/server_audit.sh" --config "$tmp_dir/audit.conf"
assert_contains 'audit threshold error explains range' '1 から 100 の範囲'

## 構築(provision_web_server.sh)のテスト -------------------------------------
mkdir -p "$tmp_dir/webroot"
cat >"$tmp_dir/provision.conf" <<EOF
PACKAGE_NAME=nginx
SERVICE_NAME=nginx
WEB_ROOT=$tmp_dir/webroot
SITE_TITLE="Test Site"
ALLOWED_TCP_PORTS="22 80"
HTTP_PORT=80
HEALTHCHECK_PATH=/
EOF
chmod 600 "$tmp_dir/provision.conf"

dryrun_output=$(bash "$ROOT_DIR/scripts/provision_web_server.sh" --config "$tmp_dir/provision.conf" 2>&1) && dryrun_status=0 || dryrun_status=$?
if (( dryrun_status <= 1 )); then ok 'provision dry-run does not error'; else not_ok 'provision dry-run does not error'; printf '%s\n' "$dryrun_output"; fi
if grep -Fq '[DRY-RUN]' <<<"$dryrun_output"; then ok 'provision dry-run shows planned commands'; else not_ok 'provision dry-run shows planned commands'; fi
if [[ ! -e "$tmp_dir/webroot/index.html" ]]; then ok 'provision dry-run creates no file'; else not_ok 'provision dry-run creates no file'; fi

cat >"$tmp_dir/provision_bad_port.conf" <<EOF
PACKAGE_NAME=nginx
SERVICE_NAME=nginx
WEB_ROOT=$tmp_dir/webroot
SITE_TITLE="Test Site"
HTTP_PORT=70000
EOF
chmod 600 "$tmp_dir/provision_bad_port.conf"
assert_status 'provision rejects out-of-range port' 2 bash "$ROOT_DIR/scripts/provision_web_server.sh" --config "$tmp_dir/provision_bad_port.conf"
assert_contains 'port rejection explains range' '1 から 65535 の範囲'

cat >"$tmp_dir/provision_missing.conf" <<EOF
SERVICE_NAME=nginx
WEB_ROOT=$tmp_dir/webroot
SITE_TITLE="Test Site"
EOF
chmod 600 "$tmp_dir/provision_missing.conf"
assert_status 'provision rejects missing package name' 2 bash "$ROOT_DIR/scripts/provision_web_server.sh" --config "$tmp_dir/provision_missing.conf"
assert_contains 'missing package name explains cause' 'PACKAGE_NAME は必須'

cat >"$tmp_dir/provision_danger.conf" <<EOF
PACKAGE_NAME=nginx
SERVICE_NAME=nginx
WEB_ROOT=/etc
SITE_TITLE="Test Site"
EOF
chmod 600 "$tmp_dir/provision_danger.conf"
assert_status 'provision rejects dangerous web root' 2 bash "$ROOT_DIR/scripts/provision_web_server.sh" --config "$tmp_dir/provision_danger.conf"
assert_contains 'dangerous web root explains cause' '重要なシステムディレクトリ'

if [[ $(id -u) -ne 0 ]]; then
  assert_status 'provision --execute without root is rejected' 2 bash "$ROOT_DIR/scripts/provision_web_server.sh" --config "$tmp_dir/provision.conf" --execute
  assert_contains 'root requirement message explains cause' 'root権限が必要です'
else
  ok 'provision root requirement check skipped (running as root)'
fi

## 受け入れ試験(build_verify.sh)のテスト ---------------------------------------
assert_status 'build_verify rejects invalid config' 2 bash "$ROOT_DIR/scripts/build_verify.sh" --config "$tmp_dir/provision_bad_port.conf"

cat >"$tmp_dir/verify_never.conf" <<EOF
PACKAGE_NAME=zzz-does-not-exist-package
SERVICE_NAME=zzz-does-not-exist-service
WEB_ROOT=$tmp_dir/no-such-webroot
HTTP_PORT=1
HEALTHCHECK_PATH=/
EOF
chmod 600 "$tmp_dir/verify_never.conf"
assert_status 'build_verify reports warnings for an unbuilt server' 1 bash "$ROOT_DIR/scripts/build_verify.sh" --config "$tmp_dir/verify_never.conf"
assert_contains 'build_verify explains missing package' 'パッケージ未導入'
assert_contains 'build_verify explains missing file' '配布ファイルが見つかりません'

printf '1..%d\n' "$((pass + fail))"
printf '# pass=%d fail=%d\n' "$pass" "$fail"
(( fail == 0 ))
