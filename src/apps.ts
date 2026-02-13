import type { ArrApp } from "./types";

export const V1_APPS = [
  "sonarr",
  "radarr",
  "lidarr",
  "readarr",
  "prowlarr",
  "bazarr",
  "overseerr",
  "plex",
  "tautulli",
  "sabnzbd",
] as const;

export type V1App = (typeof V1_APPS)[number];

export const ARR_APPS: ArrApp[] = ["radarr", "sonarr", "lidarr", "readarr", "prowlarr", "bazarr"];
