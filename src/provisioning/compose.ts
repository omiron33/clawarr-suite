import type { V1App } from "../types";

export type ProvisionPlan = {
  projectName: string;
  dataDir: string;
  timezone: string;
  ports: Partial<Record<V1App, number>>;
};

export function generateDockerComposeYaml(plan: ProvisionPlan): string {
  const p = plan.ports;
  const tz = plan.timezone;
  const data = plan.dataDir.replace(/\/$/, "");

  // linuxserver images for most; hotio for bazarr; plexinc for plex; tautulli official; sabnzbd linuxserver.
  // This is a starter compose intended for onboarding; users can customize.
  return `name: ${plan.projectName}
services:
  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    container_name: ${plan.projectName}-sonarr
    environment:
      - TZ=${tz}
      - PUID=1000
      - PGID=1000
    volumes:
      - ${data}/sonarr:/config
      - ${data}/media:/media
      - ${data}/downloads:/downloads
    ports:
      - "${p.sonarr ?? 8989}:8989"
    restart: unless-stopped

  radarr:
    image: lscr.io/linuxserver/radarr:latest
    container_name: ${plan.projectName}-radarr
    environment:
      - TZ=${tz}
      - PUID=1000
      - PGID=1000
    volumes:
      - ${data}/radarr:/config
      - ${data}/media:/media
      - ${data}/downloads:/downloads
    ports:
      - "${p.radarr ?? 7878}:7878"
    restart: unless-stopped

  lidarr:
    image: lscr.io/linuxserver/lidarr:latest
    container_name: ${plan.projectName}-lidarr
    environment:
      - TZ=${tz}
      - PUID=1000
      - PGID=1000
    volumes:
      - ${data}/lidarr:/config
      - ${data}/media:/media
      - ${data}/downloads:/downloads
    ports:
      - "${p.lidarr ?? 8686}:8686"
    restart: unless-stopped

  readarr:
    image: lscr.io/linuxserver/readarr:develop
    container_name: ${plan.projectName}-readarr
    environment:
      - TZ=${tz}
      - PUID=1000
      - PGID=1000
    volumes:
      - ${data}/readarr:/config
      - ${data}/media:/media
      - ${data}/downloads:/downloads
    ports:
      - "${p.readarr ?? 8787}:8787"
    restart: unless-stopped

  prowlarr:
    image: lscr.io/linuxserver/prowlarr:latest
    container_name: ${plan.projectName}-prowlarr
    environment:
      - TZ=${tz}
      - PUID=1000
      - PGID=1000
    volumes:
      - ${data}/prowlarr:/config
    ports:
      - "${p.prowlarr ?? 9696}:9696"
    restart: unless-stopped

  bazarr:
    image: lscr.io/linuxserver/bazarr:latest
    container_name: ${plan.projectName}-bazarr
    environment:
      - TZ=${tz}
      - PUID=1000
      - PGID=1000
    volumes:
      - ${data}/bazarr:/config
      - ${data}/media:/media
    ports:
      - "${p.bazarr ?? 6767}:6767"
    restart: unless-stopped

  overseerr:
    image: lscr.io/linuxserver/overseerr:latest
    container_name: ${plan.projectName}-overseerr
    environment:
      - TZ=${tz}
      - PUID=1000
      - PGID=1000
    volumes:
      - ${data}/overseerr:/config
    ports:
      - "${p.overseerr ?? 5055}:5055"
    restart: unless-stopped

  sabnzbd:
    image: lscr.io/linuxserver/sabnzbd:latest
    container_name: ${plan.projectName}-sabnzbd
    environment:
      - TZ=${tz}
      - PUID=1000
      - PGID=1000
    volumes:
      - ${data}/sabnzbd:/config
      - ${data}/downloads:/downloads
    ports:
      - "${p.sabnzbd ?? 8080}:8080"
    restart: unless-stopped

  plex:
    image: plexinc/pms-docker:latest
    container_name: ${plan.projectName}-plex
    environment:
      - TZ=${tz}
      - PLEX_CLAIM=
    volumes:
      - ${data}/plex:/config
      - ${data}/media:/media
    ports:
      - "${p.plex ?? 32400}:32400"
    restart: unless-stopped

  tautulli:
    image: lscr.io/linuxserver/tautulli:latest
    container_name: ${plan.projectName}-tautulli
    environment:
      - TZ=${tz}
      - PUID=1000
      - PGID=1000
    volumes:
      - ${data}/tautulli:/config
    ports:
      - "${p.tautulli ?? 8181}:8181"
    restart: unless-stopped
`;
}
