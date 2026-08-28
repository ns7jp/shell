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
[[ -z $(find "$tmp_dir/backups" -type f -print -quit) ]] && ok 'dry-run creates no archive' || not_ok 'dry-run creates no archive'
assert_status 'backup execute succeeds' 0 bash "$ROOT_DIR/scripts/backup.sh" --config "$tmp_dir/backup.conf" --execute
archive=$(find "$tmp_dir/backups" -type f -name 'test_*.tar.gz' -print -quit)
[[ -n $archive && -s $archive ]] && ok 'execute creates archive' || not_ok 'execute creates archive'
tar -tzf "$archive" | grep -Fq 'source/data.txt' && ok 'archive contains source file' || not_ok 'archive contains source file'

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

printf '1..%d\n' "$((pass + fail))"
printf '# pass=%d fail=%d\n' "$pass" "$fail"
(( fail == 0 ))
