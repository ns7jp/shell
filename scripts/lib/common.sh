#!/usr/bin/env bash

readonly EXIT_OK=0
readonly EXIT_WARNING=1
readonly EXIT_ERROR=2

timestamp() { date '+%Y-%m-%dT%H:%M:%S%z'; }
log() { local level=$1; shift; printf '%s [%s] %s\n' "$(timestamp)" "$level" "$*"; }
die() { log ERROR "$*" >&2; exit "$EXIT_ERROR"; }
require_command() { command -v "$1" >/dev/null 2>&1 || die "必要なコマンドがありません: $1"; }
require_file() { [[ -f $1 ]] || die "設定ファイルが見つかりません: $1"; }

load_config() {
  local config_path=$1
  require_file "$config_path"
  if command -v stat >/dev/null 2>&1; then
    local owner mode current_uid
    owner=$(stat -c '%u' "$config_path") || die '設定ファイルの所有者を確認できません'
    mode=$(stat -c '%a' "$config_path") || die '設定ファイルの権限を確認できません'
    current_uid=$(id -u)
    [[ $owner == "$current_uid" || $owner == 0 ]] || die '設定ファイルの所有者が安全ではありません'
    (( (8#$mode & 0022) == 0 )) || die "設定ファイルが他ユーザーから書き込み可能です: chmod go-w $config_path"
  fi
  # shellcheck disable=SC1090
  source "$config_path"
}

require_integer_range() {
  local name=$1 value=$2 min=$3 max=$4
  [[ $value =~ ^[0-9]+$ ]] || die "$name は整数で指定してください"
  (( value >= min && value <= max )) || die "$name は $min から $max の範囲で指定してください"
}

require_absolute_safe_path() {
  local name=$1 value=$2
  [[ -n $value && $value == /* ]] || die "$name は空でない絶対パスにしてください"
  case "$value" in
    /|/bin|/boot|/dev|/etc|/home|/lib|/lib64|/proc|/root|/run|/sbin|/sys|/tmp|/usr|/var)
      die "$name に重要なシステムディレクトリそのものは指定できません: $value" ;;
  esac
  [[ $value != *'/../'* && $value != */.. ]] || die "$name に .. は使用できません"
}

run_or_show() {
  local execute=$1
  shift
  if [[ $execute == true ]]; then
    log INFO "実行: $(printf '%q ' "$@")"
    "$@"
  else
    printf '[DRY-RUN] '
    printf '%q ' "$@"
    printf '\n'
  fi
}
