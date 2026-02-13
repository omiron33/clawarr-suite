export type ArrApp =
  | "radarr"
  | "sonarr"
  | "lidarr"
  | "readarr"
  | "prowlarr"
  | "bazarr"
  | "overseerr";

export type V1App = ArrApp | "plex" | "tautulli" | "sabnzbd";

export type InstanceConfig = {
  baseUrl: string; // e.g. http://localhost:7878
  apiKey?: string; // Arr apps + Overseerr key (or token)
};

export type ClawARRConfig = {
  enabled: boolean;
  discovery: {
    hosts: string[]; // hostnames or IPs to probe, e.g. ["localhost", "192.168.4.31"]
    timeoutMs: number;
  };

  instances: Partial<Record<V1App, InstanceConfig>>;
};
