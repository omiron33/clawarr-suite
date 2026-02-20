#!/usr/bin/env bash
# status.sh - Check health status of all *arr services
# Usage: status.sh [host] [sonarr_key] [radarr_key] ...
#        Or set environment variables: RADARR_URL, SONARR_URL, etc.

set -euo pipefail

# Service URLs (can be overridden via environment variables)
RADARR_URL="${RADARR_URL:-http://localhost:7878}"
SONARR_URL="${SONARR_URL:-http://localhost:8989}"
LIDARR_URL="${LIDARR_URL:-http://localhost:8686}"
READARR_URL="${READARR_URL:-http://localhost:8787}"
PROWLARR_URL="${PROWLARR_URL:-http://localhost:9696}"
BAZARR_URL="${BAZARR_URL:-http://localhost:6767}"
OVERSEERR_URL="${OVERSEERR_URL:-http://localhost:5055}"
PLEX_URL="${PLEX_URL:-http://localhost:32400}"
TAUTULLI_URL="${TAUTULLI_URL:-http://localhost:8181}"
SABNZBD_URL="${SABNZBD_URL:-http://localhost:38080}"
NOTIFIARR_URL="${NOTIFIARR_URL:-http://localhost:5454}"
KOMETA_URL="${KOMETA_URL:-http://localhost:7575}"
FLARESOLVERR_URL="${FLARESOLVERR_URL:-http://localhost:8191}"
MAINTAINERR_URL="${MAINTAINERR_URL:-http://localhost:6246}"
HOMARR_URL="${HOMARR_URL:-http://localhost:7575}"

# Accept args or use environment variables for API keys
SONARR_KEY="${1:-${SONARR_KEY:-}}"
RADARR_KEY="${2:-${RADARR_KEY:-}}"
LIDARR_KEY="${3:-${LIDARR_KEY:-}}"
READARR_KEY="${4:-${READARR_KEY:-}}"
PROWLARR_KEY="${5:-${PROWLARR_KEY:-}}"
BAZARR_KEY="${6:-${BAZARR_KEY:-}}"
OVERSEERR_KEY="${7:-${OVERSEERR_KEY:-}}"
PLEX_TOKEN="${8:-${PLEX_TOKEN:-}}"
TAUTULLI_KEY="${9:-${TAUTULLI_KEY:-}}"
SABNZBD_KEY="${10:-${SABNZBD_KEY:-}}"
NOTIFIARR_KEY="${11:-${NOTIFIARR_KEY:-}}"

# Check if jq is available
if ! command -v jq &> /dev/null; then
  echo "❌ Error: jq is required but not installed"
  echo "Install: brew install jq (macOS) or apt install jq (Linux)"
  exit 1
fi

echo "📊 Checking health status of services..."
echo ""

check_service() {
  local name=$1
  local url=$2
  local api_key=$3
  local api_path=$4
  local key_header=${5:-X-Api-Key}
  
  if [[ -z "$api_key" ]]; then
    echo "⚠️  $name - No API key provided (skipping)"
    return
  fi
  
  local full_url="${url}${api_path}"
  local response
  
  if ! response=$(curl -sf -H "${key_header}: ${api_key}" "$full_url" 2>&1); then
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
[[ -n "$SONARR_KEY" ]] && check_service "Sonarr" "$SONARR_URL" "$SONARR_KEY" "/api/v3/health"
[[ -n "$RADARR_KEY" ]] && check_service "Radarr" "$RADARR_URL" "$RADARR_KEY" "/api/v3/health"
[[ -n "$LIDARR_KEY" ]] && check_service "Lidarr" "$LIDARR_URL" "$LIDARR_KEY" "/api/v1/health"
[[ -n "$READARR_KEY" ]] && check_service "Readarr" "$READARR_URL" "$READARR_KEY" "/api/v1/health"
[[ -n "$PROWLARR_KEY" ]] && check_service "Prowlarr" "$PROWLARR_URL" "$PROWLARR_KEY" "/api/v1/health"
[[ -n "$BAZARR_KEY" ]] && check_service "Bazarr" "$BAZARR_URL" "$BAZARR_KEY" "/api/system/health"

# Overseerr uses different header
if [[ -n "$OVERSEERR_KEY" ]]; then
  if response=$(curl -sf -H "X-Api-Key: ${OVERSEERR_KEY}" "${OVERSEERR_URL}/api/v1/status" 2>&1); then
    echo "✅ Overseerr - Running"
  else
    echo "❌ Overseerr - Connection failed"
  fi
fi

# Plex uses token
if [[ -n "$PLEX_TOKEN" ]]; then
  if curl -sf -H "X-Plex-Token: ${PLEX_TOKEN}" "${PLEX_URL}/identity" &>/dev/null; then
    echo "✅ Plex - Running"
  else
    echo "❌ Plex - Connection failed"
  fi
fi

# Tautulli
if [[ -n "$TAUTULLI_KEY" ]]; then
  if response=$(curl -sf "${TAUTULLI_URL}/api/v2?apikey=${TAUTULLI_KEY}&cmd=status" 2>&1); then
    echo "✅ Tautulli - Running"
  else
    echo "❌ Tautulli - Connection failed"
  fi
fi

# SABnzbd
if [[ -n "$SABNZBD_KEY" ]]; then
  if curl -sf "${SABNZBD_URL}/api?mode=version&apikey=${SABNZBD_KEY}" &>/dev/null; then
    echo "✅ SABnzbd - Running"
  else
    echo "❌ SABnzbd - Connection failed"
  fi
fi

# Auto-detect companion services (no API key needed)
echo ""
echo "🔧 Companion Services:"

# FlareSolverr
if curl -sf -o /dev/null --connect-timeout 3 "${FLARESOLVERR_URL}" 2>/dev/null; then
  echo "✅ FlareSolverr - Running"
fi

# Maintainerr
if curl -sf -o /dev/null --connect-timeout 3 "${MAINTAINERR_URL}" 2>/dev/null; then
  echo "✅ Maintainerr - Running"
fi

# Notifiarr
if curl -sf -o /dev/null --connect-timeout 3 "${NOTIFIARR_URL}" 2>/dev/null; then
  echo "✅ Notifiarr - Running"
fi

# Homarr
if curl -sf -o /dev/null --connect-timeout 3 "${HOMARR_URL}" 2>/dev/null; then
  echo "✅ Homarr - Running"
fi

echo ""
echo "✅ Health check complete"
