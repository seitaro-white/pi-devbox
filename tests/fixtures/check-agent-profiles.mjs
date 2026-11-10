import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

assert.equal(process.env.PI_AGENT_PROFILES, "/opt/pi/agent-profiles");
for (const role of ["orchestrator", "worker"]) {
  const args = readFileSync(join(process.env.PI_AGENT_PROFILES, `${role}.args`), "utf8")
    .trimEnd().split("\n");
  for (let index = 0; index < args.length; index++) {
    if (args[index] !== "-e") continue;
    const extension = args[++index];
    if (!extension.startsWith("builtin:")) {
      assert.ok(existsSync(extension), `${role} extension is missing: ${extension}`);
    }
  }
}
