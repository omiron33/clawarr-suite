import type { ClawARRConfig } from "./types";

export function defaultConfig(): ClawARRConfig {
  return {
    enabled: true,
    discovery: {
      hosts: ["localhost"],
      timeoutMs: 1200,
    },
    instances: {},
  };
}
