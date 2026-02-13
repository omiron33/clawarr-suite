import type { ClawARRConfig } from "./types";
import { autodiscover } from "./discovery";
import { testArrConnection, testOverseerrConnection, testPlexConnection, testSabnzbdConnection, testTautulliConnection } from "./clients";
import { ARR_APPS } from "./apps";

export type CommandResult = { ok: boolean; message: string; data?: any };

export async function cmdSetup(api: any, cfg: ClawARRConfig, args: any = {}): Promise<CommandResult> {
  // Default mode is connect: discovery + store base URLs (user can edit config) + store secrets if provided.
  // Provisioning is separate (plan/apply).
  const hosts = Array.isArray(args.hosts) && args.hosts.length ? args.hosts : cfg.discovery.hosts;
  const results = await autodiscover({ hosts, timeoutMs: cfg.discovery.timeoutMs });
  return { ok: true, message: `discovered ${results.filter((r) => r.ok).length} endpoints`, data: { results } };
}

export async function cmdTest(api: any, cfg: ClawARRConfig): Promise<CommandResult> {
  const lines: string[] = [];
  for (const app of [...ARR_APPS, "overseerr", "plex", "tautulli", "sabnzbd"] as const) {
    const inst = (cfg.instances as any)[app];
    if (!inst?.baseUrl) {
      lines.push(`${app}: not configured`);
      continue;
    }
    const secret = api.secrets?.get ? await api.secrets.get(`clawarr.${app}.apiKey`) : undefined;
    const apiKey = inst.apiKey ?? secret;
    const test =
      app === "overseerr"
        ? await testOverseerrConnection({ ...inst, apiKey }, 2500)
        : app === "plex"
          ? await testPlexConnection({ ...inst, apiKey }, 2500)
          : app === "tautulli"
            ? await testTautulliConnection({ ...inst, apiKey }, 2500)
            : app === "sabnzbd"
              ? await testSabnzbdConnection({ ...inst, apiKey }, 2500)
              : await testArrConnection({ ...inst, apiKey }, 2500);
    lines.push(`${app}: ${test.ok ? "ok" : "fail"} - ${test.message}`);
  }
  return { ok: true, message: lines.join("\n") };
}

// Placeholders for v1 command surface; wired later to OpenClaw command registration.
export async function cmdStatus(_api: any, cfg: ClawARRConfig): Promise<CommandResult> {
  return { ok: true, message: `enabled=${cfg.enabled}` };
}
export async function cmdSearch(): Promise<CommandResult> {
  return { ok: false, message: "not implemented" };
}
export async function cmdAdd(): Promise<CommandResult> {
  return { ok: false, message: "not implemented" };
}
export async function cmdRequests(): Promise<CommandResult> {
  return { ok: false, message: "not implemented" };
}
export async function cmdApprove(): Promise<CommandResult> {
  return { ok: false, message: "not implemented" };
}
export async function cmdDeny(): Promise<CommandResult> {
  return { ok: false, message: "not implemented" };
}
export async function cmdPlexScan(): Promise<CommandResult> {
  return { ok: false, message: "not implemented" };
}
export async function cmdTautulliStats(): Promise<CommandResult> {
  return { ok: false, message: "not implemented" };
}
