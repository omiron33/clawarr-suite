#!/usr/bin/env bash
# api.sh - make one authenticated API call to a configured *arr/media service.
#
# Usage: api.sh <service> [METHOD] <path> [json-body]
#   api.sh radarr /api/v3/queue | jq
#   api.sh sonarr POST /api/v3/command '{"name":"RefreshSeries"}'
#   api.sh tautulli '/api/v2?cmd=get_activity'
#
# Keys come from the usual env vars (RADARR_KEY, SONARR_KEY, ...). Ports can be
# overridden with <SERVICE>_PORT (e.g. RADARR_PORT=7879). Requests only go to
# CLAWARR_HOST (see lib.sh for the destination allowlist).

set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
  echo "Services: sonarr radarr lidarr readarr prowlarr bazarr overseerr plex tautulli sabnzbd"
  exit 1
}

[[ $# -lt 2 ]] && usage

HOST="${CLAWARR_HOST:-}"
[[ -z "$HOST" ]] && { echo "Error: CLAWARR_HOST not set" >&2; exit 1; }

service=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
shift
method=GET
case "${1:-}" in
  GET|POST|PUT|DELETE|PATCH) method=$1; shift ;;
esac
path=${1:-}
body=${2:-}
[[ -z "$path" ]] && usage
[[ "$path" == /* ]] || { echo "Error: path must start with /" >&2; exit 1; }

# service -> default port, auth mode, auth name, key variable
case "$service" in
  sonarr)    port=8989;  mode=header; name=X-Api-Key;    keyvar=SONARR_KEY ;;
  radarr)    port=7878;  mode=header; name=X-Api-Key;    keyvar=RADARR_KEY ;;
  lidarr)    port=8686;  mode=header; name=X-Api-Key;    keyvar=LIDARR_KEY ;;
  readarr)   port=8787;  mode=header; name=X-Api-Key;    keyvar=READARR_KEY ;;
  prowlarr)  port=9696;  mode=header; name=X-Api-Key;    keyvar=PROWLARR_KEY ;;
  bazarr)    port=6767;  mode=header; name=X-API-KEY;    keyvar=BAZARR_KEY ;;
  overseerr) port=5055;  mode=header; name=X-Api-Key;    keyvar=OVERSEERR_KEY ;;
  plex)      port=32400; mode=header; name=X-Plex-Token; keyvar=PLEX_TOKEN ;;
  tautulli)  port=8181;  mode=query;  name=apikey;       keyvar=TAUTULLI_KEY ;;
  sabnzbd)   port=38080; mode=query;  name=apikey;       keyvar=SABNZBD_KEY ;;
  *) echo "Error: unknown service '$service'" >&2; usage ;;
esac

portvar="$(printf '%s' "$service" | tr '[:lower:]' '[:upper:]')_PORT"
port="${!portvar:-$port}"
[[ "$port" =~ ^[0-9]+$ ]] || { echo "Error: $portvar must be numeric" >&2; exit 1; }

secret="${!keyvar:-}"
[[ -z "$secret" ]] && { echo "Error: $keyvar not set" >&2; exit 1; }

args=(-sf -X "$method" -H "Accept: application/json")
if [[ -n "$body" ]]; then
  args+=(-H "Content-Type: application/json" -d "$body")
fi

arr_api "$mode" "$name" "$secret" "${args[@]}" "http://${HOST}:${port}${path}"
