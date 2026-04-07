#!/usr/bin/env bash
# status.sh - Check health status of all *arr services
# Usage: status.sh [host] [sonarr_key] [radarr_key] ...
#        Or set environment variables: CLAWARR_HOST, SONARR_KEY, etc.

set -euo pipefail

# Default ports (override via environment)
SONARR_PORT="${SONARR_PORT:-8989}"
RADARR_PORT="${RADARR_PORT:-7878}"
LIDARR_PORT="${LIDARR_PORT:-8686}"
READARR_PORT="${READARR_PORT:-8787}"
PROWLARR_PORT="${PROWLARR_PORT:-9696}"
BAZARR_PORT="${BAZARR_PORT:-6767}"
OVERSEERR_PORT="${OVERSEERR_PORT:-5055}"
PLEX_PORT="${PLEX_PORT:-32400}"
TAUTULLI_PORT="${TAUTULLI_PORT:-8181}"
SABNZBD_PORT="${SABNZBD_PORT:-8080}"
FLARESOLVERR_PORT="${FLARESOLVERR_PORT:-8191}"
MAINTAINERR_PORT="${MAINTAINERR_PORT:-6246}"
NOTIFIARR_PORT="${NOTIFIARR_PORT:-5454}"
HOMARR_PORT="${HOMARR_PORT:-7575}"

# Accept args or use environment variables
HOST="${1:-${CLAWARR_HOST:-}}"
SONARR_KEY="${2:-${SONARR_KEY:-}}"
RADARR_KEY="${3:-${RADARR_KEY:-}}"
LIDARR_KEY="${4:-${LIDARR_KEY:-}}"
READARR_KEY="${5:-${READARR_KEY:-}}"
PROWLARR_KEY="${6:-${PROWLARR_KEY:-}}"
BAZARR_KEY="${7:-${BAZARR_KEY:-}}"
OVERSEERR_KEY="${8:-${OVERSEERR_KEY:-}}"
PLEX_TOKEN="${9:-${PLEX_TOKEN:-}}"
TAUTULLI_KEY="${10:-${TAUTULLI_KEY:-}}"

if [[ -z "$HOST" ]]; then
  echo "Usage: $0 <host> [sonarr_key] [radarr_key] ..."
  echo ""
  echo "Or set environment variables:"
  echo "  export CLAWARR_HOST=192.168.1.100"
  echo "  export SONARR_KEY=abc123..."
  echo "  export RADARR_KEY=def456..."
  echo "  $0"
  exit 1
fi

# Check if jq is available
if ! command -v jq &> /dev/null; then
  echo "❌ Error: jq is required but not installed"
  echo "Install: brew install jq (macOS) or apt install jq (Linux)"
  exit 1
fi

echo "📊 Checking health status for $HOST..."
echo ""

check_service() {
  local name=$1
  local port=$2
  local api_key=$3
  local api_path=$4
  local key_header=${5:-X-Api-Key}
  
  if [[ -z "$api_key" ]]; then
    echo "⚠️  $name - No API key provided (skipping)"
    return
  fi
  
  local url="http://${HOST}:${port}${api_path}"
  local response
  
  if ! response=$(curl -sf -H "${key_header}: ${api_key}" "$url" 2>&1); then
    echo "❌ $name - Connection failed"
    return
  fi
  
  # Parse health issues
  local issues
  if issues=$(echo "$response" | jq -r '.[] | select(.type != "info") | "\(.type): \(.message)"' 2>/dev/null); then
    if [[ -z "$issues" ]]; then
      echo "✅ $name - Healthy"
    else
      echo "⚠️  $name - Issues detected:"
      echo "$issues" | while read -r line; do
        echo "    $line"
      done
    fi
  else
    echo "✅ $name - Running"
  fi
}

# Check each service
[[ -n "$SONARR_KEY" ]] && check_service "Sonarr" "$SONARR_PORT" "$SONARR_KEY" "/api/v3/health"
[[ -n "$RADARR_KEY" ]] && check_service "Radarr" "$RADARR_PORT" "$RADARR_KEY" "/api/v3/health"
[[ -n "$LIDARR_KEY" ]] && check_service "Lidarr" "$LIDARR_PORT" "$LIDARR_KEY" "/api/v1/health"
[[ -n "$READARR_KEY" ]] && check_service "Readarr" "$READARR_PORT" "$READARR_KEY" "/api/v1/health"
[[ -n "$PROWLARR_KEY" ]] && check_service "Prowlarr" "$PROWLARR_PORT" "$PROWLARR_KEY" "/api/v1/health"
[[ -n "$BAZARR_KEY" ]] && check_service "Bazarr" "$BAZARR_PORT" "$BAZARR_KEY" "/api/system/health"

# Overseerr uses different header
if [[ -n "$OVERSEERR_KEY" ]]; then
  if response=$(curl -sf -H "X-Api-Key: ${OVERSEERR_KEY}" "http://${HOST}:${OVERSEERR_PORT}/api/v1/status" 2>&1); then
    echo "✅ Overseerr - Running"
  else
    echo "❌ Overseerr - Connection failed"
  fi
fi

# Plex uses token
if [[ -n "$PLEX_TOKEN" ]]; then
  if curl -sf -H "X-Plex-Token: ${PLEX_TOKEN}" "http://${HOST}:${PLEX_PORT}/identity" &>/dev/null; then
    echo "✅ Plex - Running"
  else
    echo "❌ Plex - Connection failed"
  fi
fi

# Tautulli
if [[ -n "$TAUTULLI_KEY" ]]; then
  if response=$(curl -sf "http://${HOST}:${TAUTULLI_PORT}/api/v2?apikey=${TAUTULLI_KEY}&cmd=status" 2>&1); then
    echo "✅ Tautulli - Running"
  else
    echo "❌ Tautulli - Connection failed"
  fi
fi

# SABnzbd
SABNZBD_KEY="${SABNZBD_KEY:-}"
if [[ -n "$SABNZBD_KEY" ]]; then
  if curl -sf "http://${HOST}:${SABNZBD_PORT}/api?mode=version&apikey=${SABNZBD_KEY}" &>/dev/null; then
    echo "✅ SABnzbd - Running"
  else
    echo "❌ SABnzbd - Connection failed"
  fi
fi

# Auto-detect companion services (no API key needed)
echo ""
echo "🔧 Companion Services:"

# FlareSolverr
if curl -sf -o /dev/null --connect-timeout 3 "http://${HOST}:${FLARESOLVERR_PORT}" 2>/dev/null; then
  echo "✅ FlareSolverr - Running"
fi

# Maintainerr
if curl -sf -o /dev/null --connect-timeout 3 "http://${HOST}:${MAINTAINERR_PORT}" 2>/dev/null; then
  echo "✅ Maintainerr - Running"
fi

# Notifiarr
NOTIFIARR_KEY="${NOTIFIARR_KEY:-}"
if curl -sf -o /dev/null --connect-timeout 3 "http://${HOST}:${NOTIFIARR_PORT}" 2>/dev/null; then
  echo "✅ Notifiarr - Running"
fi

# Homarr
if curl -sf -o /dev/null --connect-timeout 3 "http://${HOST}:${HOMARR_PORT}" 2>/dev/null; then
  echo "✅ Homarr - Running"
fi

echo ""
echo "✅ Health check complete"
