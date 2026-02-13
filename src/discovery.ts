import type { V1App } from "./types";

const DEFAULT_PORTS: Record<V1App, number[]> = {
  radarr: [7878],
  sonarr: [8989],
  lidarr: [8686],
  readarr: [8787],
  prowlarr: [9696],
  bazarr: [6767],
  overseerr: [5055],
  plex: [32400],
  tautulli: [8181],
  sabnzbd: [8080],
};

export type ProbeResult = {
  app: V1App;
  baseUrl: string;
  ok: boolean;
  status?: number;
  hint?: string;
};

async function fetchWithTimeout(url: string, timeoutMs: number): Promise<Response> {
  const controller = new AbortController();
  const t = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, { signal: controller.signal, redirect: "manual" });
  } finally {
    clearTimeout(t);
  }
}

async function probeBaseUrl(baseUrl: string, timeoutMs: number): Promise<{ ok: boolean; status?: number; hint?: string }> {
  // Most Arr apps respond on /api/v3/system/status only when authenticated.
  // For discovery, just see if root returns HTML.
  try {
    const r = await fetchWithTimeout(baseUrl, timeoutMs);
    const ct = r.headers.get("content-type") || "";
    if (r.ok && ct.includes("text/html")) return { ok: true, status: r.status };
    // Some may redirect to /login etc.
    if (r.status && r.status >= 300 && r.status < 400) return { ok: true, status: r.status, hint: "redirect" };
    // Still might be there.
    return { ok: r.status !== 0, status: r.status };
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return { ok: false, hint: msg };
  }
}

export async function autodiscover(params: {
  hosts: string[];
  timeoutMs: number;
  apps?: V1App[];
}): Promise<ProbeResult[]> {
  const apps = params.apps ?? (Object.keys(DEFAULT_PORTS) as V1App[]);
  const out: ProbeResult[] = [];

  const tasks: Array<Promise<void>> = [];
  for (const host of params.hosts) {
    for (const app of apps) {
      for (const port of DEFAULT_PORTS[app]) {
        const baseUrl = `http://${host}:${port}`;
        tasks.push(
          (async () => {
            const res = await probeBaseUrl(baseUrl, params.timeoutMs);
            out.push({ app, baseUrl, ...res });
          })()
        );
      }
    }
  }

  await Promise.all(tasks);
  // Prefer ok results first.
  return out.sort((a, b) => Number(b.ok) - Number(a.ok));
}
