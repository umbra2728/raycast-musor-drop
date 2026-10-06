import { getPreferenceValues } from "@raycast/api";
import { launchPlayer } from "./lib/player";

const DEFAULT_COUNT = 20;
const MAX_COUNT = 60;

function parseCount(value: string | undefined) {
  const count = Number.parseInt(value ?? "", 10);
  if (!Number.isFinite(count) || count < 1) return DEFAULT_COUNT;
  return Math.min(count, MAX_COUNT);
}

export default async function Command() {
  const { count } = getPreferenceValues<Preferences.MusorSwarm>();
  await launchPlayer(["--swarm", String(parseCount(count))]);
}
