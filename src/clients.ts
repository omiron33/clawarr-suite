import type { InstanceConfig } from "./types";

function joinUrl(baseUrl: string, path: string): string {
  return `${baseUrl.replace(/\/$/, "")}${path.startsWith("/") ? "" : "/"}${path}`;
}

async function jsonFetch<T>(url: string, init: RequestInit & { timeoutMs?: number } = {}): Promise<{ ok: boolean; status: number; data?: T; error?: string }> {
  const { timeoutMs, ...rest } = init;
  const controller = new AbortController();
  const t = timeoutMs ? setTimeout(() => controller.abort(), timeoutMs) : null;
  try {
    const r = await fetch(url, { ...rest, signal: controller.signal });
    const status = r.status;
    const text = await r.text();
    if (!r.ok) return { ok: false, status, error: text.slice(0, 800) };
    try {
      return { ok: true, status, data: JSON.parse(text) as T };
    } catch {
      return { ok: false, status, error: "Non-JSON response" };
    }
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return { ok: false, status: 0, error: msg };
  } finally {
    if (t) clearTimeout(t);
  }
}

export async function testArrConnection(instance: InstanceConfig, timeoutMs = 2500) {
  if (!instance.baseUrl) return { ok: false, message: "No baseUrl configured" };
  if (!instance.apiKey) return { ok: false, message: "No apiKey configured" };
  const url = joinUrl(instance.baseUrl, "/api/v3/system/status");
  const r = await jsonFetch<any>(url, {
    method: "GET",
    headers: { "X-Api-Key": instance.apiKey },
    timeoutMs,
  });
  if (!r.ok) return { ok: false, message: `HTTP ${r.status}: ${r.error ?? "error"}` };
  return { ok: true, message: `OK: ${r.data?.appName ?? "Arr"} ${r.data?.version ?? ""}`.trim(), data: r.data };
}

export async function testOverseerrConnection(instance: InstanceConfig, timeoutMs = 2500) {
  if (!instance.baseUrl) return { ok: false, message: "No baseUrl configured" };
  if (!instance.apiKey) return { ok: false, message: "No apiKey configured" };
  const url = joinUrl(instance.baseUrl, "/api/v1/status");
  const r = await jsonFetch<any>(url, {
    method: "GET",
    headers: { "X-Api-Key": instance.apiKey },
    timeoutMs,
  });
  if (!r.ok) return { ok: false, message: `HTTP ${r.status}: ${r.error ?? "error"}` };
  return { ok: true, message: `OK: Overseerr ${r.data?.version ?? ""}`.trim(), data: r.data };
}

// Plex: validate by hitting identity endpoint.
// Token can be provided via X-Plex-Token query param.
export async function testPlexConnection(instance: InstanceConfig, timeoutMs = 2500) {
  if (!instance.baseUrl) return { ok: false, message: "No baseUrl configured" };
  if (!instance.apiKey) return { ok: false, message: "No token configured" };
  const u = new URL(joinUrl(instance.baseUrl, "/identity"));
  u.searchParams.set("X-Plex-Token", instance.apiKey);
  const r = await jsonFetch<any>(u.toString(), { method: "GET", timeoutMs });
  if (!r.ok) {
    // Plex may return XML; jsonFetch will call it Non-JSON.
    if (r.error === "Non-JSON response" && r.status >= 200 && r.status < 300) return { ok: true, message: "OK: Plex (non-JSON)" };
    return { ok: false, message: `HTTP ${r.status}: ${r.error ?? "error"}` };
  }
  return { ok: true, message: "OK: Plex", data: r.data };
}

// Tautulli: /api/v2?cmd=status&apikey=...
export async function testTautulliConnection(instance: InstanceConfig, timeoutMs = 2500) {
  if (!instance.baseUrl) return { ok: false, message: "No baseUrl configured" };
  if (!instance.apiKey) return { ok: false, message: "No apiKey configured" };
  const u = new URL(joinUrl(instance.baseUrl, "/api/v2"));
  u.searchParams.set("cmd", "status");
  u.searchParams.set("apikey", instance.apiKey);
  const r = await jsonFetch<any>(u.toString(), { method: "GET", timeoutMs });
  if (!r.ok) return { ok: false, message: `HTTP ${r.status}: ${r.error ?? "error"}` };
  const ok = (r.data?.response?.result ?? "success") === "success";
  return { ok, message: r.data?.response?.message ?? "OK: Tautulli", data: r.data };
}

// SABnzbd: /api?mode=version&output=json&apikey=...
export async function testSabnzbdConnection(instance: InstanceConfig, timeoutMs = 2500) {
  if (!instance.baseUrl) return { ok: false, message: "No baseUrl configured" };
  if (!instance.apiKey) return { ok: false, message: "No apiKey configured" };
  const u = new URL(joinUrl(instance.baseUrl, "/api"));
  u.searchParams.set("mode", "version");
  u.searchParams.set("output", "json");
  u.searchParams.set("apikey", instance.apiKey);
  const r = await jsonFetch<any>(u.toString(), { method: "GET", timeoutMs });
  if (!r.ok) return { ok: false, message: `HTTP ${r.status}: ${r.error ?? "error"}` };
  return { ok: true, message: `OK: SABnzbd ${r.data?.version ?? ""}`.trim(), data: r.data };
}
