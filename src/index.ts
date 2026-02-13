import type { ClawARRConfig, ArrApp } from "./types";
import { defaultConfig } from "./defaults";
import { autodiscover } from "./discovery";
import { testArrConnection, testOverseerrConnection, testPlexConnection, testSabnzbdConnection, testTautulliConnection } from "./clients";
import { ARR_APPS } from "./apps";
import { cmdSetup, cmdStatus, cmdTest } from "./commands";

interface PluginApi {
  pluginConfig: unknown;
  config: unknown;
  logger: {
    info(msg: string): void;
    warn(msg: string): void;
    error(msg: string): void;
    debug?(msg: string): void;
  };
  registerService(service: { id: string; start: () => Promise<void> | void; stop: () => Promise<void> | void }): void;
  // Optional CLI command registration
  registerCli?: (fn: (ctx: { program: unknown }) => void, opts?: { commands: string[] }) => void;
  // Optional OpenClaw secrets support (preferred). If unavailable, we fall back to pluginConfig.
  secrets?: {
    get(key: string): Promise<string | undefined> | string | undefined;
    set(key: string, value: string): Promise<void> | void;
    delete?(key: string): Promise<void> | void;
  };
  // Optional UI route registration (dashboard/plugin page)
  registerUi?: (ui: { id: string; title: string; route: string; staticDir: string }) => void;
  registerHttpRoute?: (route: { method: string; path: string; handler: (req: any, res: any) => void }) => void;
}

function parseConfig(value: unknown): ClawARRConfig {
  const v = (value ?? {}) as Partial<ClawARRConfig>;
  const d = defaultConfig();
  return {
    enabled: v.enabled ?? d.enabled,
    discovery: {
      hosts: Array.isArray(v.discovery?.hosts) && v.discovery?.hosts.length ? (v.discovery!.hosts as string[]) : d.discovery.hosts,
      timeoutMs: typeof v.discovery?.timeoutMs === "number" ? v.discovery!.timeoutMs : d.discovery.timeoutMs,
    },
    instances: (v.instances ?? {}) as any,
  };
}

// ARR_APPS imported from ./apps

async function getApiKey(api: PluginApi, app: string): Promise<string | undefined> {
  const newKey = `clawarr.${app}.apiKey`;
  const oldKey = `mediaarr.${app}.apiKey`;

  const get = api.secrets?.get;
  if (!get) return undefined;

  const v1 = get(newKey);
  const val1 = v1 instanceof Promise ? await v1 : v1;
  if (val1) return val1;

  // Back-compat: read legacy secret name if present.
  const v0 = get(oldKey);
  const val0 = v0 instanceof Promise ? await v0 : v0;
  return val0;
}

async function setApiKey(api: PluginApi, app: string, value: string): Promise<void> {
  const secretKey = `clawarr.${app}.apiKey`;
  const r = api.secrets?.set?.(secretKey, value);
  if (r instanceof Promise) await r;
}

async function buildStatus(api: PluginApi, cfg: ClawARRConfig) {
  const lines: string[] = [];
  lines.push(`enabled=${cfg.enabled}`);

  const appsToCheck = [...ARR_APPS, "overseerr", "plex", "tautulli", "sabnzbd"] as const;

  for (const app of appsToCheck) {
    const inst = (cfg.instances as any)[app] as any;
    if (!inst?.baseUrl) {
      lines.push(`${app}: not configured`);
      continue;
    }
    const apiKey = inst.apiKey ?? (await getApiKey(api, app));

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

  return lines.join("\n");
}

const mediaArrSuitePlugin = {
  id: "clawarr-suite",
  name: "ClawARR Suite",
  description: "Unified control surface for Radarr/Sonarr/etc with onboarding wizard",

  configSchema: {
    parse(value: unknown): ClawARRConfig {
      return parseConfig(value);
    },
  },

  register(api: PluginApi) {
    const cfg = parseConfig(api.pluginConfig);

    if (api.registerUi) {
      api.registerUi({
        id: "clawarr-suite",
        title: "ClawARR Suite",
        route: "/plugins/clawarr-suite",
        staticDir: new URL("../ui", import.meta.url).pathname,
      });
    }

    if (api.registerHttpRoute) {
      // Minimal API for the wizard UI.
      api.registerHttpRoute({
        method: "GET",
        path: "/api/clawarr/discover",
        handler: async (_req: any, res: any) => {
          const results = await autodiscover({ hosts: cfg.discovery.hosts, timeoutMs: cfg.discovery.timeoutMs });
          res.setHeader("content-type", "application/json");
          res.end(JSON.stringify({ ok: true, results }));
        },
      });

      // Back-compat route (MediaArr → ClawARR)
      api.registerHttpRoute({
        method: "GET",
        path: "/api/mediaarr/discover",
        handler: async (_req: any, res: any) => {
          const results = await autodiscover({ hosts: cfg.discovery.hosts, timeoutMs: cfg.discovery.timeoutMs });
          res.setHeader("content-type", "application/json");
          res.end(JSON.stringify({ ok: true, results }));
        },
      });

      api.registerHttpRoute({
        method: "POST",
        path: "/api/clawarr/secret",
        handler: async (req: any, res: any) => {
          let body = "";
          req.on("data", (d: any) => (body += d.toString("utf8")));
          req.on("end", async () => {
            try {
              const parsed = JSON.parse(body || "{}");
              const app = String(parsed.app || "");
              const apiKey = String(parsed.apiKey || "");
              if (!app || !apiKey) throw new Error("Missing app/apiKey");
              await setApiKey(api, app, apiKey);
              res.setHeader("content-type", "application/json");
              res.end(JSON.stringify({ ok: true }));
            } catch (e) {
              res.statusCode = 400;
              res.setHeader("content-type", "application/json");
              res.end(JSON.stringify({ ok: false, error: e instanceof Error ? e.message : String(e) }));
            }
          });
        },
      });

      // Back-compat route
      api.registerHttpRoute({
        method: "POST",
        path: "/api/mediaarr/secret",
        handler: async (req: any, res: any) => {
          let body = "";
          req.on("data", (d: any) => (body += d.toString("utf8")));
          req.on("end", async () => {
            try {
              const parsed = JSON.parse(body || "{}");
              const app = String(parsed.app || "");
              const apiKey = String(parsed.apiKey || "");
              if (!app || !apiKey) throw new Error("Missing app/apiKey");
              await setApiKey(api, app, apiKey);
              res.setHeader("content-type", "application/json");
              res.end(JSON.stringify({ ok: true }));
            } catch (e) {
              res.statusCode = 400;
              res.setHeader("content-type", "application/json");
              res.end(JSON.stringify({ ok: false, error: e instanceof Error ? e.message : String(e) }));
            }
          });
        },
      });

      api.registerHttpRoute({
        method: "GET",
        path: "/api/clawarr/status",
        handler: async (_req: any, res: any) => {
          const text = await buildStatus(api, cfg);
          res.setHeader("content-type", "application/json");
          res.end(JSON.stringify({ ok: true, status: text }));
        },
      });

      // Back-compat route
      api.registerHttpRoute({
        method: "GET",
        path: "/api/mediaarr/status",
        handler: async (_req: any, res: any) => {
          const text = await buildStatus(api, cfg);
          res.setHeader("content-type", "application/json");
          res.end(JSON.stringify({ ok: true, status: text }));
        },
      });
    }

    // CLI commands: clawarr setup/status/test
    api.registerCli?.(
      ({ program }) => {
        const prog = program as any;
        const claw = prog.command("clawarr").description("ClawARR Suite commands");

        claw
          .command("setup")
          .description("Discover Arr apps and report endpoints")
          .option("--hosts <hosts...>", "Override discovery hosts")
          .action(async (opts: { hosts?: string[] }) => {
            const res = await cmdSetup(api as any, cfg, { hosts: opts.hosts });
            console.log(res.message);
            if (res.data?.results) console.log(JSON.stringify(res.data.results, null, 2));
          });

        claw
          .command("status")
          .description("Show current ClawARR config status")
          .action(async () => {
            const res = await cmdStatus(api as any, cfg);
            console.log(res.message);
          });

        claw
          .command("test")
          .description("Test connections to configured services")
          .action(async () => {
            const res = await cmdTest(api as any, cfg);
            console.log(res.message);
          });
      },
      { commands: ["clawarr"] }
    );

    let running = false;

    api.registerService({
      id: "clawarr-suite",
      start: async () => {
        if (running) return;
        running = true;
        api.logger.info("[clawarr-suite] Service started");
      },
      stop: async () => {
        running = false;
        api.logger.info("[clawarr-suite] Service stopped");
      },
    });
  },
};

export default mediaArrSuitePlugin;
