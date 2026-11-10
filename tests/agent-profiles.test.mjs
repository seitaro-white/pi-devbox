import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { it } from "node:test";
import { readJson, root } from "./helpers/files.mjs";

const { dependencies } = readJson(join(root, "container/package.json"));
const models = {
  orchestrator: "anthropic/claude-opus-5-5:medium",
  worker: "openai-codex/gpt-6.1-sol:medium",
};
const builtins = new Set([
  "builtin:mcp", "builtin:llama.cpp", "builtin:codemode", "builtin:tool-search",
]);

for (const [role, model] of Object.entries(models)) {
  it(`${role} profile contains unquoted arguments and installed extension dependencies`, () => {
    const text = readFileSync(join(root, `container/agent-profiles/${role}.args`), "utf8");
    assert.ok(text.endsWith("\n"), "profile must end with a newline for mapfile");
    const args = text.slice(0, -1).split("\n");
    for (const arg of args) {
      assert.match(arg, /^[^\s'"#]+$/, `invalid argument: ${JSON.stringify(arg)}`);
    }
    assert.deepEqual(args.slice(0, 3), ["--model", model, "--no-extensions"]);
    assert.ok(args.length > 3, "profile must include extensions");
    for (let index = 3; index < args.length; index += 2) {
      assert.equal(args[index], "-e");
      const extension = args[index + 1];
      assert.ok(extension && !extension.startsWith("-"), "-e must have a value");
      if (builtins.has(extension)) continue;
      const match = extension.match(/^\/opt\/pi\/node_modules\/(@[^/]+\/[^/]+|[^/]+)\/(.+)$/);
      assert.ok(match, `extension must be a package entry path: ${extension}`);
      assert.ok(Object.hasOwn(dependencies, match[1]), `extension dependency is missing: ${match[1]}`);
      assert.ok(!match[2].split("/").some((part) => part === ".." || part === "."),
        `extension must stay inside its package: ${extension}`);
    }
  });
}
