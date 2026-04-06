#!/usr/bin/env bash
# discover.sh - Auto-discover *arr services on common ports
# Usage: discover.sh <host>

set -euo pipefail

HOST="${1:-}"

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

if [[ -z "$HOST" ]]; then
  echo "Usage: $0 <host-ip-or-hostname>"
  echo ""
  echo "Scans for common *arr services and reports what's running."
  echo ""
  echo "Example:"
  echo "  $0 192.168.1.100"
  echo "  $0 media-server.local"
  exit 1
fi

# Service definitions: name:port:path
SERVICES=(
  "Sonarr:${SONARR_PORT}:/api/v3/system/status"
  "Radarr:${RADARR_PORT}:/api/v3/system/status"
  "Lidarr:${LIDARR_PORT}:/api/v1/system/status"
  "Readarr:${READARR_PORT}:/api/v1/system/status"
  "Prowlarr:${PROWLARR_PORT}:/api/v1/system/status"
  "Bazarr:${BAZARR_PORT}:/api/system/status"
  "Overseerr:${OVERSEERR_PORT}:/api/v1/status"
  "Plex:${PLEX_PORT}:/identity"
  "Tautulli:${TAUTULLI_PORT}:/api/v2?cmd=get_tautulli_info"
)

echo "🔍 Scanning $HOST for *arr services..."
echo ""

FOUND=0

for service in "${SERVICES[@]}"; do
  IFS=: read -r name port path <<< "$service"
  
  # Try HTTP connection with timeout — 200 or 401 both mean the service is running
  http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 "http://${HOST}:${port}${path}" 2>/dev/null || echo "000")
  
  if [[ "$http_code" == "200" ]]; then
    echo "✅ $name - http://${HOST}:${port}"
    FOUND=$((FOUND + 1))
  elif [[ "$http_code" =~ ^(301|302|303|400|401|403)$ ]]; then
    echo "✅ $name - http://${HOST}:${port} (needs API key)"
    FOUND=$((FOUND + 1))
  else
    echo "❌ $name - not detected on port $port"
  fi
done

echo ""
if [[ $FOUND -eq 0 ]]; then
  echo "❌ No services found. Check:"
  echo "  - Host IP/hostname is correct"
  echo "  - Services are running"
  echo "  - Firewall allows connections"
  echo "  - Non-standard ports (if using different ports)"
  exit 1
else
  echo "✅ Found $FOUND service(s)"
  echo ""
  echo "Next steps:"
  echo "  1. Get API keys (see SKILL.md - API Key Discovery)"
  echo "  2. Run status.sh to verify connectivity"
fi
