import { describe, expect, it } from "vitest";

import { serializeRemoteConfigVersion, serializeUser } from "../src/serializers.js";
import { firebaseUserLookupKind } from "../src/validation.js";

describe("Firebase Authentication user lookup", () => {
  it.each([
    ["admin@example.com", "email"],
    ["+84900000001", "phone"],
    ["firebase-user-uid", "uid"],
    ["0900000001", "uid"],
  ] as const)("classifies %s as %s", (query, expected) => {
    expect(firebaseUserLookupKind(query)).toBe(expected);
  });

  it("serializes the phone number and creation timestamp", () => {
    const result = serializeUser({
      uid: "uid-1",
      email: undefined,
      phoneNumber: "+84900000001",
      displayName: undefined,
      photoURL: undefined,
      disabled: false,
      emailVerified: false,
      customClaims: undefined,
      providerData: [{ providerId: "phone" }],
      metadata: {
        creationTime: "2026-07-14T00:00:00.000Z",
        lastSignInTime: undefined,
        lastRefreshTime: undefined,
      },
    } as never);

    expect(result).toMatchObject({
      uid: "uid-1",
      phoneNumber: "+84900000001",
      createdAt: "2026-07-14T00:00:00.000Z",
    });
  });
});

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
