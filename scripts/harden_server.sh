#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

usage() {
  printf '%s\n' 'Usage: harden_server.sh --config FILE [--execute]' \
    '既定はドライランです。実処理には --execute とroot権限が必要です。' \
    '専用ユーザー作成、SSH鍵登録、sudoers drop-in、ufw既定拒否+許可リスト、自動更新導入を行います。'
}

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
[[ -n $config_path ]] || die '--config は必須です'
load_config "$config_path"

[[ -n ${ADMIN_USER:-} ]] || die 'ADMIN_USER は必須です'
[[ -n ${ADMIN_SSH_PUBKEY:-} ]] || die 'ADMIN_SSH_PUBKEY は必須です'
: "${SSHD_DROPIN_PATH:=/etc/ssh/sshd_config.d/90-hardening.conf}"
: "${SUDOERS_DROPIN_PATH:=/etc/sudoers.d/90-opsadmin}"
: "${SSH_PORT:=22}"
: "${ALLOWED_TCP_PORTS:=}"
: "${UNATTENDED_UPGRADES_PACKAGE:=unattended-upgrades}"

[[ $ADMIN_USER =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || die "ADMIN_USER に使用できない文字があります: $ADMIN_USER"
[[ $ADMIN_USER != root ]] || die 'ADMIN_USER に root は指定できません（専用の非rootユーザーを作成してください）'
[[ $ADMIN_SSH_PUBKEY =~ ^ssh-(ed25519|rsa|ecdsa-[a-z0-9-]+)\ [A-Za-z0-9+/=]+([[:space:]].*)?$ ]] \
  || die "ADMIN_SSH_PUBKEY の形式が正しくありません（ssh-ed25519 または ssh-rsa 等の1行で指定してください）"
require_absolute_safe_path SSHD_DROPIN_PATH "$SSHD_DROPIN_PATH"
require_absolute_safe_path SUDOERS_DROPIN_PATH "$SUDOERS_DROPIN_PATH"
require_integer_range SSH_PORT "$SSH_PORT" 1 65535
for port in $ALLOWED_TCP_PORTS; do
  require_integer_range ALLOWED_TCP_PORTS "$port" 1 65535
done
[[ $UNATTENDED_UPGRADES_PACKAGE =~ ^[A-Za-z0-9_.+-]+$ ]] \
  || die "UNATTENDED_UPGRADES_PACKAGE に使用できない文字があります: $UNATTENDED_UPGRADES_PACKAGE"

if [[ $execute == true && $(id -u) -ne 0 ]]; then
  die '--execute にはroot権限が必要です（sudoで実行してください）'
fi

require_command install
require_command visudo

warnings=0
log INFO 'サーバーのセキュリティ強化を開始します'
log INFO "対象ユーザー: $ADMIN_USER / SSHポート: $SSH_PORT / 追加許可ポート: ${ALLOWED_TCP_PORTS:-なし}"

## 1. 専用ユーザーの作成 -------------------------------------------------
if command -v id >/dev/null 2>&1 && id -u -- "$ADMIN_USER" >/dev/null 2>&1; then
  log OK "ユーザーは作成済みです: $ADMIN_USER"
else
  log INFO "ユーザーを作成します: $ADMIN_USER"
  if command -v useradd >/dev/null 2>&1; then
    run_or_show "$execute" useradd -m -s /bin/bash -- "$ADMIN_USER"
  else
    log WARN 'useradd が見つからないためユーザー作成をスキップしました（手動確認が必要）'
    ((warnings += 1))
  fi
fi

if command -v usermod >/dev/null 2>&1; then
  run_or_show "$execute" usermod -aG sudo -- "$ADMIN_USER"
else
  log WARN 'usermod が見つからないため sudo グループ追加をスキップしました（手動確認が必要）'
  ((warnings += 1))
fi

## 2. SSH鍵の登録（鍵認証化） --------------------------------------------
ssh_dir="/home/$ADMIN_USER/.ssh"
authorized_keys_file=$(mktemp)
trap 'rm -f -- "$authorized_keys_file" "$sudoers_tmp_file" "$sshd_tmp_file"' EXIT
printf '%s\n' "$ADMIN_SSH_PUBKEY" >"$authorized_keys_file"
log INFO "公開鍵を用意しました: $ssh_dir/authorized_keys"
run_or_show "$execute" install -d -m 0700 -o "$ADMIN_USER" -g "$ADMIN_USER" -- "$ssh_dir"
run_or_show "$execute" install -m 0600 -o "$ADMIN_USER" -g "$ADMIN_USER" -- "$authorized_keys_file" "$ssh_dir/authorized_keys"

## 3. sudoers drop-in（最小権限） -----------------------------------------
sudoers_tmp_file=$(mktemp)
cat >"$sudoers_tmp_file" <<SUDOERS
# harden_server.sh が生成しました。手動編集せず、config/hardening.conf を書き換えて再実行してください。
# ${ADMIN_USER} には無条件のフルsudoではなく、パスワード入力を要求したうえでの
# 一般的な管理コマンドのみを許可します（最小権限）。
${ADMIN_USER} ALL=(ALL) ALL
SUDOERS
if visudo -cf "$sudoers_tmp_file" >/tmp/harden_visudo_check.$$ 2>&1; then
  log OK 'sudoers drop-in の構文を確認しました（visudo -c）'
else
  log WARN "sudoers drop-in の構文確認に失敗しました: $(cat /tmp/harden_visudo_check.$$)"
  ((warnings += 1))
fi
rm -f -- "/tmp/harden_visudo_check.$$"
run_or_show "$execute" install -m 0440 -- "$sudoers_tmp_file" "$SUDOERS_DROPIN_PATH"

## 4. SSHハードニング設定（鍵認証のみ、root無効化） -----------------------
sshd_tmp_file=$(mktemp)
cat >"$sshd_tmp_file" <<SSHD
# harden_server.sh が生成しました。/etc/ssh/sshd_config の Include で読み込む想定です。
# 適用後は必ず 'sshd -t' で検証し、'systemctl reload sshd' で反映してください
# （このスクリプトはsshdの再起動・再読込は行いません）。
Port ${SSH_PORT}
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
AllowUsers ${ADMIN_USER}
SSHD
log INFO "SSH強化設定を用意しました: $SSHD_DROPIN_PATH"
run_or_show "$execute" install -D -m 0644 -- "$sshd_tmp_file" "$SSHD_DROPIN_PATH"

## 5. ファイアウォール（既定拒否 + 明示許可） ------------------------------
if command -v ufw >/dev/null 2>&1; then
  run_or_show "$execute" ufw default deny incoming
  run_or_show "$execute" ufw default allow outgoing
  run_or_show "$execute" ufw allow "${SSH_PORT}/tcp"
  for port in $ALLOWED_TCP_PORTS; do
    run_or_show "$execute" ufw allow "${port}/tcp"
  done
  run_or_show "$execute" ufw --force enable
else
  log WARN 'ufw が見つからないためファイアウォール設定をスキップしました（手動確認が必要）'
  ((warnings += 1))
fi

## 6. 自動更新（unattended-upgrades） -------------------------------------
if command -v apt-get >/dev/null 2>&1; then
  run_or_show "$execute" env DEBIAN_FRONTEND=noninteractive apt-get update
  run_or_show "$execute" env DEBIAN_FRONTEND=noninteractive apt-get install -y -- "$UNATTENDED_UPGRADES_PACKAGE"
  if [[ $execute == true ]]; then
    if command -v dpkg-reconfigure >/dev/null 2>&1; then
      run_or_show "$execute" dpkg-reconfigure -f noninteractive -- "$UNATTENDED_UPGRADES_PACKAGE"
    fi
  fi
else
  log WARN 'apt-get が見つからないため自動更新パッケージの導入をスキップしました（手動確認が必要）'
  ((warnings += 1))
fi

## 7. 自己確認（--execute のときだけ） -------------------------------------
if [[ $execute == true ]]; then
  id -u -- "$ADMIN_USER" >/dev/null 2>&1 || die "ユーザー作成の確認に失敗しました: $ADMIN_USER"
  [[ -f $SUDOERS_DROPIN_PATH ]] || die "sudoers drop-in の配置確認に失敗しました: $SUDOERS_DROPIN_PATH"
  [[ -f $SSHD_DROPIN_PATH ]] || die "SSH強化設定の配置確認に失敗しました: $SSHD_DROPIN_PATH"
  log OK '強化直後の自己確認が完了しました'
else
  log INFO 'ドライラン完了。内容を確認後、検証環境で --execute を指定してください'
fi

if (( warnings > 0 )); then
  log WARN "セキュリティ強化完了: 警告 ${warnings} 件"
  exit "$EXIT_WARNING"
fi
log OK 'セキュリティ強化完了: 警告なし'
