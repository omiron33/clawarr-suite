import { execSync } from "node:child_process";

export function hasDocker(): boolean {
  try {
    execSync("docker --version", { stdio: "ignore" });
    return true;
  } catch {
    return false;
  }
}

export function composeUp(composePath: string, projectName: string): { ok: boolean; message: string } {
  try {
    execSync(`docker compose -p ${projectName} -f ${composePath} up -d`, { stdio: "inherit" });
    return { ok: true, message: "docker compose up -d completed" };
  } catch (e) {
    return { ok: false, message: e instanceof Error ? e.message : String(e) };
  }
}
