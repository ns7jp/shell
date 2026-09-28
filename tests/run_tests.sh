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

# 同じ場所を指す別の書き方でもすり抜けないことを確認します（PowerShell版 PS-03 と同じ組み合わせ）。
# 正規化を忘れると '//etc' や '/./etc' が素通りし、安全機構が無効になります。
for sneaky in '//etc' '/./etc' '///etc' '/etc/' '///tmp' '/usr/'; do
  cat >"$tmp_dir/sneaky.conf" <<EOF
SOURCE_DIR=$sneaky
BACKUP_DIR=$tmp_dir/backups
RETENTION_DAYS=7
ARCHIVE_PREFIX=test
EOF
  chmod 600 "$tmp_dir/sneaky.conf"
  assert_status "dangerous path written differently is rejected: $sneaky" 2 bash "$ROOT_DIR/scripts/backup.sh" --config "$tmp_dir/sneaky.conf"
  assert_contains "rejection of $sneaky explains cause" '重要なシステムディレクトリ'
done

# /./ や // が混ざっていても、保存先が保存元の配下なら拒否されることを確認します。
cat >"$tmp_dir/nested.conf" <<EOF
SOURCE_DIR=$tmp_dir/source
BACKUP_DIR=$tmp_dir/./source//inner
RETENTION_DAYS=7
ARCHIVE_PREFIX=test
EOF
chmod 600 "$tmp_dir/nested.conf"
assert_status 'backup dir under source written differently is rejected' 2 bash "$ROOT_DIR/scripts/backup.sh" --config "$tmp_dir/nested.conf"
assert_contains 'nested backup rejection explains cause' '配下に置くことはできません'

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

## セキュリティ強化(harden_server.sh)のテスト -----------------------------------
mkdir -p "$tmp_dir/hardening_ssh_dir" "$tmp_dir/hardening_sudoers_dir"
cat >"$tmp_dir/hardening.conf" <<EOF
ADMIN_USER=opsadmin
ADMIN_SSH_PUBKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleExampleExampleExampleExampleE opsadmin@example"
SSHD_DROPIN_PATH=$tmp_dir/hardening_ssh_dir/90-hardening.conf
SUDOERS_DROPIN_PATH=$tmp_dir/hardening_sudoers_dir/90-opsadmin
SSH_PORT=22
ALLOWED_TCP_PORTS="80"
UNATTENDED_UPGRADES_PACKAGE=unattended-upgrades
EOF
chmod 600 "$tmp_dir/hardening.conf"

harden_dryrun_output=$(bash "$ROOT_DIR/scripts/harden_server.sh" --config "$tmp_dir/hardening.conf" 2>&1) && harden_dryrun_status=0 || harden_dryrun_status=$?
if (( harden_dryrun_status <= 1 )); then ok 'harden dry-run does not error'; else not_ok 'harden dry-run does not error'; printf '%s\n' "$harden_dryrun_output"; fi
if grep -Fq '[DRY-RUN]' <<<"$harden_dryrun_output"; then ok 'harden dry-run shows planned commands'; else not_ok 'harden dry-run shows planned commands'; fi
if [[ ! -e "$tmp_dir/hardening_sudoers_dir/90-opsadmin" && ! -e "$tmp_dir/hardening_ssh_dir/90-hardening.conf" ]]; then
  ok 'harden dry-run creates no drop-in files'
else
  not_ok 'harden dry-run creates no drop-in files'
fi
if grep -Fq 'visudo' <<<"$harden_dryrun_output" || grep -Fq 'sudoers drop-in の構文を確認しました' <<<"$harden_dryrun_output"; then
  ok 'harden dry-run validates sudoers syntax with visudo -c'
else
  not_ok 'harden dry-run validates sudoers syntax with visudo -c'
  printf '%s\n' "$harden_dryrun_output"
fi

cat >"$tmp_dir/hardening_missing.conf" <<EOF
SSHD_DROPIN_PATH=$tmp_dir/hardening_ssh_dir/90-hardening.conf
SUDOERS_DROPIN_PATH=$tmp_dir/hardening_sudoers_dir/90-opsadmin
EOF
chmod 600 "$tmp_dir/hardening_missing.conf"
assert_status 'harden rejects missing admin user' 2 bash "$ROOT_DIR/scripts/harden_server.sh" --config "$tmp_dir/hardening_missing.conf"
assert_contains 'missing admin user explains cause' 'ADMIN_USER は必須'

cat >"$tmp_dir/hardening_bad_key.conf" <<EOF
ADMIN_USER=opsadmin
ADMIN_SSH_PUBKEY="not-a-valid-key"
SSHD_DROPIN_PATH=$tmp_dir/hardening_ssh_dir/90-hardening.conf
SUDOERS_DROPIN_PATH=$tmp_dir/hardening_sudoers_dir/90-opsadmin
EOF
chmod 600 "$tmp_dir/hardening_bad_key.conf"
assert_status 'harden rejects malformed ssh public key' 2 bash "$ROOT_DIR/scripts/harden_server.sh" --config "$tmp_dir/hardening_bad_key.conf"
assert_contains 'malformed ssh key explains cause' 'ADMIN_SSH_PUBKEY の形式'

cat >"$tmp_dir/hardening_root_user.conf" <<EOF
ADMIN_USER=root
ADMIN_SSH_PUBKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleExampleExampleExampleExampleE opsadmin@example"
SSHD_DROPIN_PATH=$tmp_dir/hardening_ssh_dir/90-hardening.conf
SUDOERS_DROPIN_PATH=$tmp_dir/hardening_sudoers_dir/90-opsadmin
EOF
chmod 600 "$tmp_dir/hardening_root_user.conf"
assert_status 'harden rejects ADMIN_USER=root' 2 bash "$ROOT_DIR/scripts/harden_server.sh" --config "$tmp_dir/hardening_root_user.conf"
assert_contains 'root user rejection explains cause' 'ADMIN_USER に root は指定できません'

cat >"$tmp_dir/hardening_bad_port.conf" <<EOF
ADMIN_USER=opsadmin
ADMIN_SSH_PUBKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleExampleExampleExampleExampleE opsadmin@example"
SSHD_DROPIN_PATH=$tmp_dir/hardening_ssh_dir/90-hardening.conf
SUDOERS_DROPIN_PATH=$tmp_dir/hardening_sudoers_dir/90-opsadmin
SSH_PORT=70000
EOF
chmod 600 "$tmp_dir/hardening_bad_port.conf"
assert_status 'harden rejects out-of-range ssh port' 2 bash "$ROOT_DIR/scripts/harden_server.sh" --config "$tmp_dir/hardening_bad_port.conf"
assert_contains 'ssh port rejection explains range' '1 から 65535 の範囲'

cat >"$tmp_dir/hardening_danger.conf" <<EOF
ADMIN_USER=opsadmin
ADMIN_SSH_PUBKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleExampleExampleExampleExampleE opsadmin@example"
SSHD_DROPIN_PATH=/etc
SUDOERS_DROPIN_PATH=$tmp_dir/hardening_sudoers_dir/90-opsadmin
EOF
chmod 600 "$tmp_dir/hardening_danger.conf"
assert_status 'harden rejects dangerous sshd dropin path' 2 bash "$ROOT_DIR/scripts/harden_server.sh" --config "$tmp_dir/hardening_danger.conf"
assert_contains 'dangerous sshd dropin path explains cause' '重要なシステムディレクトリ'

if [[ $(id -u) -ne 0 ]]; then
  assert_status 'harden --execute without root is rejected' 2 bash "$ROOT_DIR/scripts/harden_server.sh" --config "$tmp_dir/hardening.conf" --execute
  assert_contains 'harden root requirement message explains cause' 'root権限が必要です'
else
  ok 'harden root requirement check skipped (running as root)'
fi

## セキュリティ受け入れ試験(verify_hardening.sh)のテスト ---------------------------
assert_status 'verify_hardening rejects invalid config' 2 bash "$ROOT_DIR/scripts/verify_hardening.sh" --config "$tmp_dir/hardening_bad_port.conf"

cat >"$tmp_dir/hardening_never.conf" <<EOF
ADMIN_USER=zzz-does-not-exist-user
SSHD_DROPIN_PATH=$tmp_dir/hardening_ssh_dir/no-such-dropin.conf
SUDOERS_DROPIN_PATH=$tmp_dir/hardening_sudoers_dir/no-such-sudoers
SSH_PORT=22
EOF
chmod 600 "$tmp_dir/hardening_never.conf"
assert_status 'verify_hardening reports warnings for an unhardened server' 1 bash "$ROOT_DIR/scripts/verify_hardening.sh" --config "$tmp_dir/hardening_never.conf"
assert_contains 'verify_hardening explains missing user' '専用ユーザーが見つかりません'
assert_contains 'verify_hardening explains missing sudoers dropin' 'sudoers drop-in が見つかりません'

# --execute を実際に動かした構築後の確認は、専用ユーザー作成やsudoers/SSH設定の
# 配置がrootと実システムへの変更を要するため、この自動テストでは行いません
# （root権限下でも、テスト用の使い捨てユーザーを実システムに作成することは避けます）。
# 実VMでの --execute と verify_hardening.sh の通し確認は NOT RUN です。

## Ansible構成管理パック(ansible/site.yml)のテスト -------------------------------
# ansibleは任意導入のツールのため、無い環境ではWARNやエラーにせず、
# 既存のufw/systemd未導入時と同じ「見つからなければスキップし理由を記録する」方針にそろえます。
if ! command -v ansible-playbook >/dev/null 2>&1; then
  ok 'ansible syntax-check skipped (ansible-playbook not installed)'
else
  ansible_output=$(ansible-playbook --syntax-check "$ROOT_DIR/ansible/site.yml" 2>&1) && ansible_status=0 || ansible_status=$?
  if (( ansible_status == 0 )); then
    ok 'ansible syntax-check passes'
  elif grep -Fq 'community.general' <<<"$ansible_output"; then
    # community.general コレクション（ufwモジュール用）は既定では同梱されず、
    # この検証環境からは ansible-galaxy 経由での取得もネットワーク制限で行えません。
    # YAML構文そのものの誤りではないため、失敗ではなくスキップとして記録します。
    ok 'ansible syntax-check skipped (community.general collection not available in this sandbox)'
    printf '%s\n' "$ansible_output"
  else
    not_ok 'ansible syntax-check passes'
    printf '%s\n' "$ansible_output"
  fi
fi

## 変更管理・復旧(snapshot_config.sh / restore_config.sh / change_deploy.sh)のテスト --------
mkdir -p "$tmp_dir/change_target" "$tmp_dir/change_snapshots" "$tmp_dir/change_source"
printf 'before-change\n' >"$tmp_dir/change_target/index.html"
printf 'after-change\n' >"$tmp_dir/change_source/index.html"
cat >"$tmp_dir/change.conf" <<EOF
SNAPSHOT_DIR=$tmp_dir/change_snapshots
SNAPSHOT_TARGETS="$tmp_dir/change_target"
CHANGE_TARGET=$tmp_dir/change_target
VERIFY_CMD="true"
EOF
chmod 600 "$tmp_dir/change.conf"

assert_status 'snapshot dry-run succeeds' 0 bash "$ROOT_DIR/scripts/snapshot_config.sh" --config "$tmp_dir/change.conf" --label t
assert_contains 'snapshot dry-run is visible' '[DRY-RUN]'
if [[ -z $(find "$tmp_dir/change_snapshots" -mindepth 1 -print -quit) ]]; then
  ok 'snapshot dry-run creates nothing'
else
  not_ok 'snapshot dry-run creates nothing'
fi

snapshot_output=$(bash "$ROOT_DIR/scripts/snapshot_config.sh" --config "$tmp_dir/change.conf" --label t --execute) && snap_status=0 || snap_status=$?
if (( snap_status == 0 )); then ok 'snapshot execute succeeds'; else not_ok 'snapshot execute succeeds'; printf '%s\n' "$snapshot_output"; fi
snapshot_path=$(grep -o 'SNAPSHOT_PATH=.*' <<<"$snapshot_output" | head -n1 | cut -d= -f2-)
if [[ -n $snapshot_path && -f "$snapshot_path/manifest.txt" && -f "$snapshot_path/payload$tmp_dir/change_target/index.html" ]]; then
  ok 'snapshot captures expected file into payload with manifest'
else
  not_ok 'snapshot captures expected file into payload with manifest'
fi

# restore_config.sh / change_deploy.sh の --execute はroot権限を要求するため、
# 実際に復元・変更が起きることの確認はroot権限下でのみ行います
# （provision_web_server.sh・harden_server.shの--executeテストと同じ方針）。
if [[ $(id -u) -eq 0 ]]; then
  printf 'mutated-content\n' >"$tmp_dir/change_target/index.html"
  assert_status 'restore execute succeeds' 0 bash "$ROOT_DIR/scripts/restore_config.sh" --config "$tmp_dir/change.conf" --snapshot "$snapshot_path" --execute
  if [[ $(cat "$tmp_dir/change_target/index.html") == 'before-change' ]]; then
    ok 'restore actually restores pre-change content'
  else
    not_ok 'restore actually restores pre-change content'
  fi
  assert_contains 'restore verifies checksum against snapshot' 'すべて一致しました'

  # change_deploy: 成功する検証ゲート（VERIFY_CMD=true）で変更が確定すること
  printf 'before-change\n' >"$tmp_dir/change_target/index.html"
  assert_status 'change_deploy execute with passing gate succeeds' 0 bash "$ROOT_DIR/scripts/change_deploy.sh" --config "$tmp_dir/change.conf" --source "$tmp_dir/change_source" --execute
  if [[ $(cat "$tmp_dir/change_target/index.html") == 'after-change' ]]; then
    ok 'change_deploy applies change on passing gate'
  else
    not_ok 'change_deploy applies change on passing gate'
  fi

  # change_deploy: 失敗する検証ゲート（終了コード2）で自動的に切戻ること
  printf 'before-change\n' >"$tmp_dir/change_target/index.html"
  cat >"$tmp_dir/change_fail.conf" <<EOF
SNAPSHOT_DIR=$tmp_dir/change_snapshots
SNAPSHOT_TARGETS="$tmp_dir/change_target"
CHANGE_TARGET=$tmp_dir/change_target
VERIFY_CMD="exit 2"
EOF
  chmod 600 "$tmp_dir/change_fail.conf"
  assert_status 'change_deploy execute with failing gate returns error' 2 bash "$ROOT_DIR/scripts/change_deploy.sh" --config "$tmp_dir/change_fail.conf" --source "$tmp_dir/change_source" --execute
  assert_contains 'change_deploy failing gate triggers auto-rollback message' '自動的にスナップショットへ切戻します'
  if [[ $(cat "$tmp_dir/change_target/index.html") == 'before-change' ]]; then
    ok 'change_deploy auto-rollback actually restores pre-change content'
  else
    not_ok 'change_deploy auto-rollback actually restores pre-change content'
  fi

  # change_deploy: 警告(終了コード1)は自動切戻しせず、人の判断を促すこと
  printf 'before-change\n' >"$tmp_dir/change_target/index.html"
  cat >"$tmp_dir/change_warn.conf" <<EOF
SNAPSHOT_DIR=$tmp_dir/change_snapshots
SNAPSHOT_TARGETS="$tmp_dir/change_target"
CHANGE_TARGET=$tmp_dir/change_target
VERIFY_CMD="exit 1"
EOF
  chmod 600 "$tmp_dir/change_warn.conf"
  assert_status 'change_deploy execute with warning gate returns warning' 1 bash "$ROOT_DIR/scripts/change_deploy.sh" --config "$tmp_dir/change_warn.conf" --source "$tmp_dir/change_source" --execute
  if [[ $(cat "$tmp_dir/change_target/index.html") == 'after-change' ]]; then
    ok 'change_deploy warning gate keeps the change (no auto-rollback)'
  else
    not_ok 'change_deploy warning gate keeps the change (no auto-rollback)'
  fi
else
  ok 'restore execute checks skipped (running as non-root)'
  ok 'change_deploy execute checks skipped (running as non-root)'
fi

cat >"$tmp_dir/change_missing.conf" <<EOF
SNAPSHOT_TARGETS="$tmp_dir/change_target"
EOF
chmod 600 "$tmp_dir/change_missing.conf"
assert_status 'snapshot rejects missing SNAPSHOT_DIR' 2 bash "$ROOT_DIR/scripts/snapshot_config.sh" --config "$tmp_dir/change_missing.conf"
assert_contains 'missing SNAPSHOT_DIR explains cause' 'SNAPSHOT_DIR は必須'

cat >"$tmp_dir/change_danger.conf" <<EOF
SNAPSHOT_DIR=/etc
SNAPSHOT_TARGETS="$tmp_dir/change_target"
EOF
chmod 600 "$tmp_dir/change_danger.conf"
assert_status 'snapshot rejects dangerous SNAPSHOT_DIR' 2 bash "$ROOT_DIR/scripts/snapshot_config.sh" --config "$tmp_dir/change_danger.conf"
assert_contains 'dangerous SNAPSHOT_DIR explains cause' '重要なシステムディレクトリ'

cat >"$tmp_dir/change_no_target.conf" <<EOF
SNAPSHOT_DIR=$tmp_dir/change_snapshots
SNAPSHOT_TARGETS="$tmp_dir/other_dir"
CHANGE_TARGET=$tmp_dir/change_target
VERIFY_CMD="true"
EOF
chmod 600 "$tmp_dir/change_no_target.conf"
assert_status 'change_deploy rejects CHANGE_TARGET missing from SNAPSHOT_TARGETS' 2 bash "$ROOT_DIR/scripts/change_deploy.sh" --config "$tmp_dir/change_no_target.conf" --source "$tmp_dir/change_source"
assert_contains 'CHANGE_TARGET omission explains cause' 'SNAPSHOT_TARGETS に CHANGE_TARGET を含めてください'

if [[ $(id -u) -ne 0 ]]; then
  assert_status 'restore --execute without root is rejected' 2 bash "$ROOT_DIR/scripts/restore_config.sh" --config "$tmp_dir/change.conf" --snapshot "$snapshot_path" --execute
  assert_contains 'restore root requirement message explains cause' 'root権限が必要です'
else
  ok 'restore root requirement check skipped (running as root)'
fi

printf '1..%d\n' "$((pass + fail))"
printf '# pass=%d fail=%d\n' "$pass" "$fail"
(( fail == 0 ))
