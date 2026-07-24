import { describe, expect, it } from "vitest";

import { serializeRemoteConfigVersion } from "../src/serializers.js";

describe("Remote Config version serialization", () => {
  it("exposes the update user's email for the admin history UI", () => {
    expect(serializeRemoteConfigVersion({
      versionNumber: "8",
      updateUser: { email: "admin@example.com", name: "Admin User" },
    })).toMatchObject({
      versionNumber: "8",
      updatedBy: "admin@example.com",
    });
  });

  it("falls back safely to a display name when an API response has no email", () => {
    expect(serializeRemoteConfigVersion({
      versionNumber: "7",
      updateUser: { name: "Firebase service agent" },
    } as never)).toMatchObject({
      updatedBy: "Firebase service agent",
    });
  });
});
