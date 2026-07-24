import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

const scriptPath = fileURLToPath(new URL("../scripts/set-admin.mjs", import.meta.url));

describe("trusted admin bootstrap script", () => {
  it("fails before credential access when --project is omitted", () => {
    const result = spawnSync(process.execPath, [scriptPath, "--uid", "firebase-user"], {
      encoding: "utf8",
    });

    expect(result.status).toBe(2);
    expect(result.stderr).toContain("--project is required");
    expect(result.stdout).toBe("");
  });
});
