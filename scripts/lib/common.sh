#!/usr/bin/env bash

# 共通ライブラリの利用側スクリプトから参照する定数です。
# shellcheck disable=SC2034
readonly EXIT_OK=0 EXIT_WARNING=1 EXIT_ERROR=2

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

# パスの書き方を1つの形へそろえます（正規化）。ファイルの存在やシンボリックリンクは見ません。
#   ・'//etc'、'///etc' のような連続した / を1つにする
#   ・'/./etc' のような「.」の区切りを取り除く
#   ・'/etc/' のような末尾の / を取り除く（ルートそのものは '/' のまま）
# PowerShell版の Assert-OpsSafePath が [System.IO.Path]::GetFullPath で行っている正規化と同じ考え方です。
# realpath -m はシンボリックリンクをたどるため（Ubuntuでは /lib が /usr/lib になる）、使っていません。
# '..' はここでは解釈せず、呼び出し側で拒否します。
normalize_path() {
  local value=$1 part normalized=''
  local -a parts=()
  IFS=/ read -r -a parts <<<"$value"
  for part in "${parts[@]}"; do
    [[ -z $part || $part == . ]] && continue
    normalized+="/$part"
  done
  printf '%s\n' "${normalized:-/}"
}

require_absolute_safe_path() {
  local name=$1 value=$2 normalized
  [[ -n $value && $value == /* ]] || die "$name は空でない絶対パスにしてください"
  [[ $value != *'/../'* && $value != */.. ]] || die "$name に .. は使用できません"
  # 文字列をそのまま比べると、'//etc'、'/./etc'、'/etc/' のように同じ場所を指す
  # 別の書き方で検査をすり抜けるため、正規化してから判定します。
  normalized=$(normalize_path "$value")
  case "$normalized" in
    /|/bin|/boot|/dev|/etc|/home|/lib|/lib64|/proc|/root|/run|/sbin|/sys|/tmp|/usr|/var)
      die "$name に重要なシステムディレクトリそのものは指定できません: $value" ;;
  esac
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
