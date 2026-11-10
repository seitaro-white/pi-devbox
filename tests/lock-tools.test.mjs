import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { it } from "node:test";
import { root } from "./helpers/files.mjs";

const script = join(root, "scripts/lock-tools.sh");
const dockerfile = readFileSync(join(root, "Dockerfile"), "utf8");

it("pins the lock refresh to the build's mise version", () => {
  const version = readFileSync(script, "utf8").match(/^version=(.+)$/m)?.[1];
  const imageVersion = dockerfile.match(/--from=ghcr\.io\/jdx\/mise:([^@]+)@sha256:/)?.[1];
  assert.ok(imageVersion);
  assert.equal(version, imageVersion);
});

it("copies mise only into the tools build stage", () => {
  const stages = dockerfile.split(/^FROM /m);
  const miseStages = stages.filter((stage) => stage.includes("/usr/local/bin/mise"));
  assert.equal(miseStages.length, 1);
  assert.match(miseStages[0], /^system AS tools\n/);
});

for (const arch of ["x86_64", "aarch64"]) {
  it(`rejects a corrupt ${arch} download and cleans up before executing it`, () => {
    const directory = mkdtempSync(join(tmpdir(), "lock-tools-test-"));
    try {
      const bin = join(directory, "bin");
      const temporary = join(directory, "tmp");
      mkdirSync(bin);
      mkdirSync(temporary);
      writeFileSync(join(bin, "uname"), `#!/bin/sh\ncase "$1" in -s) echo Linux;; -m) echo ${arch};; esac\n`, { mode: 0o755 });
      writeFileSync(join(bin, "curl"), '#!/bin/sh\nprintf "#!/bin/sh\\nexit 99\\n" > "$4"\n', { mode: 0o755 });
      const result = spawnSync("sh", [script], {
        cwd: tmpdir(),
        env: { ...process.env, PATH: `${bin}:${process.env.PATH}`, TMPDIR: temporary },
        encoding: "utf8",
      });
      assert.equal(result.status, 1, result.stderr);
      assert.match(result.stdout, /FAILED/);
      assert.deepEqual(readdirSync(temporary), []);
    } finally {
      rmSync(directory, { recursive: true, force: true });
    }
  });
}
