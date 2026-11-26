#!/usr/bin/env bash
# lib.sh - shared helpers for ClawArr scripts.
#
# All authenticated HTTP calls go through arr_api so that:
#   1. API keys/tokens are only ever sent to hosts the user configured
#      (CLAWARR_HOST, CLAWARR_ALLOWED_HOSTS) or to loopback/private addresses.
#   2. Secrets are handed to curl via a config on stdin (-K -), never on the
#      command line, so they don't show up in `ps`, shell history or logs.
#   3. Redirects are never followed, so a server can't bounce the key elsewhere.
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
#   arr_api header X-Api-Key "$RADARR_KEY" -sf "http://${HOST}:7878/api/v3/queue"
#   arr_api query  apikey    "$TAUTULLI_KEY" -sf "http://${HOST}:8181/api/v2?cmd=status"
#
# Exactly one http(s) URL must appear among the curl arguments.
#
# Config:
#   CLAWARR_HOST           primary host (always allowed)
#   CLAWARR_ALLOWED_HOSTS  extra hosts allowed to receive keys (comma/space separated)
#                          e.g. "nas.lan, seedbox.example.com"

# Guard against double-sourcing.
[[ -n "${_CLAWARR_LIB_LOADED:-}" ]] && return 0
_CLAWARR_LIB_LOADED=1

_clawarr_lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# Strip an optional scheme, path and port from a configured host value.
_clawarr_norm_host() {
  local h
  h=$(_clawarr_lower "$1")
  h="${h#*://}"
  h="${h%%/*}"
  if [[ "$h" == \[* ]]; then
    h="${h#[}"; h="${h%%]*}"
  elif [[ "$h" == *:*:* ]]; then
    : # bare IPv6 literal, leave as-is
  else
    h="${h%%:*}"
  fi
  printf '%s' "$h"
}

# Return 0 if $1 is an IPv4 literal in a loopback/private/link-local/CGNAT range.
_clawarr_is_private_ipv4() {
  local ip=$1 a b c d
  [[ "$ip" =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]] || return 1
  a=${BASH_REMATCH[1]}; b=${BASH_REMATCH[2]}; c=${BASH_REMATCH[3]}; d=${BASH_REMATCH[4]}
  local o
  for o in "$a" "$b" "$c" "$d"; do
    (( 10#$o <= 255 )) || return 1
  done
  a=$((10#$a)); b=$((10#$b))
  (( a == 10 )) && return 0                          # 10.0.0.0/8
  (( a == 127 )) && return 0                         # loopback
  (( a == 192 && b == 168 )) && return 0             # 192.168.0.0/16
  (( a == 172 && b >= 16 && b <= 31 )) && return 0   # 172.16.0.0/12
  (( a == 169 && b == 254 )) && return 0             # link-local
  (( a == 100 && b >= 64 && b <= 127 )) && return 0  # CGNAT / Tailscale
  return 1
}

_clawarr_is_private_ipv6() {
  local ip
  ip=$(_clawarr_lower "$1")
  [[ "$ip" == "::1" ]] && return 0
  [[ "$ip" =~ ^f[cd][0-9a-f]{0,2}: ]] && return 0    # fc00::/7 unique local
  [[ "$ip" =~ ^fe[89ab][0-9a-f]?: ]] && return 0     # fe80::/10 link-local
  return 1
}

# clawarr_host_allowed HOST -> 0 if keys may be sent to HOST.
clawarr_host_allowed() {
  local host
  host=$(_clawarr_lower "$1")
  [[ -z "$host" ]] && return 1
  [[ "$host" == "localhost" ]] && return 0
  _clawarr_is_private_ipv4 "$host" && return 0
  _clawarr_is_private_ipv6 "$host" && return 0

  local entry
  if [[ -n "${CLAWARR_HOST:-}" ]] && [[ "$host" == "$(_clawarr_norm_host "$CLAWARR_HOST")" ]]; then
    return 0
  fi
  for entry in ${CLAWARR_ALLOWED_HOSTS:+${CLAWARR_ALLOWED_HOSTS//,/ }}; do
    [[ "$host" == "$(_clawarr_norm_host "$entry")" ]] && return 0
  done
  return 1
}

# Extract the host from an http(s) URL. Fails on anything unusual.
_clawarr_url_host() {
  local url=$1 rest authority
  [[ "$url" =~ ^[Hh][Tt][Tt][Pp][Ss]?:// ]] || return 1
  # No whitespace or control characters anywhere in the URL.
  [[ "$url" =~ [[:space:][:cntrl:]] ]] && return 1
  rest="${url#*://}"
  authority="${rest%%[/?#]*}"
  # Userinfo (user@host) is a classic way to disguise the real host.
  [[ "$authority" == *@* ]] && return 1
  if [[ "$authority" == \[* ]]; then
    authority="${authority#[}"
    [[ "$authority" == *\]* ]] || return 1
    printf '%s' "${authority%%]*}"
  else
    printf '%s' "${authority%%:*}"
  fi
}

# Escape a value for a double-quoted curl config string.
_clawarr_cfg_escape() {
  local v=$1
  v=${v//\\/\\\\}
  v=${v//\"/\\\"}
  printf '%s' "$v"
}

_clawarr_urlencode() {
  local s=$1 out="" c i
  for (( i = 0; i < ${#s}; i++ )); do
    c=${s:i:1}
    case "$c" in
      [a-zA-Z0-9.~_-]) out+="$c" ;;
      *) out+=$(printf '%%%02X' "'$c") ;;
    esac
  done
  printf '%s' "$out"
}

# arr_api MODE NAME SECRET [curl args...]
#   MODE   header -> send "NAME: SECRET" as an HTTP header
#          query  -> append NAME=SECRET to the URL query string
#   Remaining args are passed to curl; exactly one must be the http(s) URL.
arr_api() (
  set -u
  local mode=${1:-} name=${2:-} secret=${3:-}
  if [[ $# -lt 4 ]]; then
    echo "arr_api: usage: arr_api header|query NAME SECRET [curl args...] URL" >&2
    return 2
  fi
  shift 3

  if [[ "$mode" != "header" && "$mode" != "query" ]]; then
    echo "arr_api: unknown auth mode '$mode'" >&2
    return 2
  fi
  if [[ -z "$secret" ]]; then
    echo "arr_api: empty credential for $name" >&2
    return 2
  fi
  if [[ "$name$secret" =~ [[:cntrl:]] ]]; then
    echo "arr_api: credential contains control characters; refusing" >&2
    return 2
  fi

  local url="" arg
  local -a args=()
  for arg in "$@"; do
    case "$arg" in
      -L|--location|--location-trusted|-K|--config|--next|-:)
        echo "arr_api: curl option '$arg' is not allowed" >&2
        return 2 ;;
      -[a-zA-Z]*L*)
        # Combined short flags such as -sfL
        if [[ "$arg" != -*[!a-zA-Z]* ]]; then
          echo "arr_api: following redirects (-L) is not allowed" >&2
          return 2
        fi
        args+=("$arg") ;;
      [Hh][Tt][Tt][Pp]://*|[Hh][Tt][Tt][Pp][Ss]://*)
        if [[ -n "$url" ]]; then
          echo "arr_api: more than one URL given; refusing" >&2
          return 2
        fi
        url=$arg ;;
      *) args+=("$arg") ;;
    esac
  done

  if [[ -z "$url" ]]; then
    echo "arr_api: no http(s) URL given" >&2
    return 2
  fi

  local host
  if ! host=$(_clawarr_url_host "$url"); then
    echo "arr_api: malformed or suspicious URL; refusing to send credentials" >&2
    return 3
  fi
  if ! clawarr_host_allowed "$host"; then
    echo "arr_api: refusing to send $name to '$host' (not CLAWARR_HOST, not in CLAWARR_ALLOWED_HOSTS, not a private address)" >&2
    return 3
  fi

  local cfg_header=""
  if [[ "$mode" == "query" ]]; then
    local sep='?'
    [[ "$url" == *\?* ]] && sep='&'
    # Keep any #fragment at the end.
    local frag=""
    if [[ "$url" == *#* ]]; then frag="#${url#*#}"; url="${url%%#*}"; fi
    url="${url}${sep}${name}=$(_clawarr_urlencode "$secret")${frag}"
  else
    cfg_header="header = \"$(_clawarr_cfg_escape "$name: $secret")\""
  fi

  command curl --proto '=http,https' --max-redirs 0 "${args[@]+"${args[@]}"}" -K - <<EOF
url = "$(_clawarr_cfg_escape "$url")"
$cfg_header
EOF
)
