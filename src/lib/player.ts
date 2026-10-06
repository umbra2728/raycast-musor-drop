import { closeMainWindow, environment, showHUD } from "@raycast/api";
import { spawn } from "node:child_process";
import { chmodSync } from "node:fs";
import { join } from "node:path";

export async function launchPlayer(extraArgs: string[] = []) {
  const player = join(environment.assetsPath, "musor-drop-player");
  const video = join(environment.assetsPath, "musor-drop.mp4");

  await closeMainWindow();

  try {
    chmodSync(player, 0o755);
    const child = spawn(player, [...extraArgs, video], { detached: true, stdio: "ignore" });
    child.unref();
  } catch (error) {
    await showHUD(`Musor Drop failed: ${String(error)}`);
  }
}
