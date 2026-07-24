import { describe, expect, it } from "vitest";

import { ApiError } from "../src/errors.js";
import { assertRemoteConfigEtag } from "../src/remote-config-service.js";

describe("Remote Config optimistic concurrency", () => {
  it("accepts the ETag loaded by the administrator", () => {
    expect(() => assertRemoteConfigEtag("etag-7", "etag-7")).not.toThrow();
  });

  it("returns a conflict when another administrator has published", () => {
    expect(() => assertRemoteConfigEtag("etag-8", "etag-7")).toThrowError(ApiError);
    try {
      assertRemoteConfigEtag("etag-8", "etag-7");
    } catch (error) {
      expect(error).toMatchObject({
        status: 409,
        code: "remote_config_conflict",
      });
    }
  });
});
