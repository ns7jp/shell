#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

usage() { printf '%s\n' 'Usage: verify_hardening.sh --config FILE [--output FILE]' '終了コード: 0=正常、1=警告あり、2=実行エラー'; }
config_path=''
output_path=''
while (($#)); do
  case "$1" in
    --config) [[ $# -ge 2 ]] || die '--config に値が必要です'; config_path=$2; shift 2 ;;
    --output) [[ $# -ge 2 ]] || die '--output に値が必要です'; output_path=$2; shift 2 ;;
    -h|--help) usage; exit "$EXIT_OK" ;;
    *) die "不明な引数です: $1" ;;
  esac
done
[[ -n $config_path ]] || die '--config は必須です'
load_config "$config_path"
[[ -n ${ADMIN_USER:-} ]] || die 'ADMIN_USER は必須です'
: "${SSHD_DROPIN_PATH:=/etc/ssh/sshd_config.d/90-hardening.conf}"
: "${SUDOERS_DROPIN_PATH:=/etc/sudoers.d/90-opsadmin}"
: "${SSH_PORT:=22}"
: "${ALLOWED_TCP_PORTS:=}"
require_absolute_safe_path SSHD_DROPIN_PATH "$SSHD_DROPIN_PATH"
require_absolute_safe_path SUDOERS_DROPIN_PATH "$SUDOERS_DROPIN_PATH"
require_integer_range SSH_PORT "$SSH_PORT" 1 65535

if [[ -n $output_path ]]; then
  require_absolute_safe_path OUTPUT_PATH "$output_path"
  mkdir -p "$(dirname "$output_path")"
  exec > >(tee -a "$output_path") 2>&1
fi

warnings=0
log INFO 'セキュリティ強化の受け入れ試験を開始します'
log INFO "対象ユーザー: $ADMIN_USER / SSHポート: $SSH_PORT"

## 1. 専用ユーザーの存在とグループ -----------------------------------------
if command -v id >/dev/null 2>&1 && id -u -- "$ADMIN_USER" >/dev/null 2>&1; then
  log OK "専用ユーザーを確認しました: $ADMIN_USER"
  groups_out=$(id -nG -- "$ADMIN_USER" 2>/dev/null || true)
  if [[ $groups_out == *root* ]]; then
    log WARN "対象ユーザーが root グループに所属しています（想定外の権限）: $ADMIN_USER"
    ((warnings += 1))
  else
    log OK "対象ユーザーに root グループの所属はありません: $ADMIN_USER"
  fi
else
  log WARN "専用ユーザーが見つかりません: $ADMIN_USER"
  ((warnings += 1))
fi

## 2. SSH root無効化・パスワード認証無効化 ---------------------------------
sshd_check_source=''
if command -v sshd >/dev/null 2>&1 && sshd -T >/tmp/verify_sshd_effective.$$ 2>/dev/null; then
  sshd_check_source=/tmp/verify_sshd_effective.$$
elif [[ -f $SSHD_DROPIN_PATH ]]; then
  sshd_check_source=$SSHD_DROPIN_PATH
fi

if [[ -n $sshd_check_source ]]; then
  if grep -Eiq '^[[:space:]]*permitrootlogin[[:space:]]+no' "$sshd_check_source"; then
    log OK 'SSHのroot直接ログインが無効化されていることを確認しました'
  else
    log WARN 'SSHのroot直接ログイン無効化を確認できません（PermitRootLogin no が見つかりません）'
    ((warnings += 1))
  fi
  if grep -Eiq '^[[:space:]]*passwordauthentication[[:space:]]+no' "$sshd_check_source"; then
    log OK 'SSHのパスワード認証が無効化されていることを確認しました'
  else
    log WARN 'SSHのパスワード認証無効化を確認できません（PasswordAuthentication no が見つかりません）'
    ((warnings += 1))
  fi
else
  log WARN "sshd も設定ファイルも見つからないためSSH設定を確認できません: $SSHD_DROPIN_PATH"
  ((warnings += 1))
fi
rm -f -- "/tmp/verify_sshd_effective.$$" 2>/dev/null || true

## 3. sudoers drop-inの構文 -------------------------------------------------
if [[ -f $SUDOERS_DROPIN_PATH ]]; then
  if command -v visudo >/dev/null 2>&1; then
    if visudo -cf "$SUDOERS_DROPIN_PATH" >/dev/null 2>&1; then
      log OK "sudoers drop-in の構文を確認しました: $SUDOERS_DROPIN_PATH"
    else
      log WARN "sudoers drop-in の構文が不正です: $SUDOERS_DROPIN_PATH"
      ((warnings += 1))
    fi
  else
    log WARN 'visudo が見つからないため sudoers drop-in の構文を確認できません'
    ((warnings += 1))
  fi
else
  log WARN "sudoers drop-in が見つかりません: $SUDOERS_DROPIN_PATH"
  ((warnings += 1))
fi

## 4. ufw既定拒否 + 許可リスト ----------------------------------------------
if command -v ufw >/dev/null 2>&1; then
  ufw_status=$(ufw status verbose 2>/dev/null || true)
  if grep -Fq 'Default: deny (incoming)' <<<"$ufw_status"; then
    log OK 'ufwが既定拒否(deny incoming)であることを確認しました'
  else
    log WARN 'ufwの既定拒否(deny incoming)を確認できません'
    ((warnings += 1))
  fi
  if grep -Fq "${SSH_PORT}/tcp" <<<"$ufw_status"; then
    log OK "SSHポートの許可を確認しました: ${SSH_PORT}/tcp"
  else
    log WARN "SSHポートの許可を確認できません: ${SSH_PORT}/tcp"
    ((warnings += 1))
  fi
  for port in $ALLOWED_TCP_PORTS; do
    if grep -Fq "${port}/tcp" <<<"$ufw_status"; then
      log OK "許可ポートを確認しました: ${port}/tcp"
    else
      log WARN "許可ポートを確認できません: ${port}/tcp"
      ((warnings += 1))
    fi
  done
else
  log WARN 'ufw が見つからないためファイアウォール設定を確認できません'
  ((warnings += 1))
fi

if (( warnings > 0 )); then
  log WARN "受け入れ試験完了: 警告 ${warnings} 件"
  exit "$EXIT_WARNING"
fi
log OK '受け入れ試験完了: 警告なし'
