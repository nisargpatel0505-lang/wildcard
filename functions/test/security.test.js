"use strict";

const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const test = require("node:test");
const {__test} = require("../index.js");

test("submission validation pins the UTC date and field set", () => {
  const now = new Date("2026-07-19T12:00:00Z");
  const valid = {
    name: "n1s",
    score: 1234,
    idempotencyKey: "request_0000000001",
  };
  assert.deepEqual(__test.validateSubmission(valid, now), {
    ...valid,
    date: "2026-07-19",
    name: "N1S",
  });
  assert.throws(() => __test.validateSubmission({...valid, date: "2026-07-18"}, now));
  assert.throws(() => __test.validateSubmission(
    {...valid, admin: true}, now,
  ));
  assert.throws(() => __test.validateSubmission(
    {...valid, score: 10_000_001}, now,
  ));
});

test("account hashes are stable and do not expose Firebase UIDs", () => {
  const result = __test.uidHash("firebase-user-alice");
  assert.match(result, /^[a-f0-9]{64}$/);
  assert.equal(result, __test.uidHash("firebase-user-alice"));
  assert.notEqual(result, __test.uidHash("firebase-user-bob"));
  assert(!result.includes("alice"));
});

test("Pi forwarding signs the exact body and timestamp", async () => {
  const secret = "test-secret-" + "x".repeat(32);
  let captured;
  const fakeFetch = async (url, options) => {
    captured = {url, options};
    return {
      ok: true,
      status: 200,
      json: async () => ({ok: true}),
    };
  };
  await __test.signedPiRequest("/daily", {
    date: "2026-07-19",
    name: "ALICE",
    score: 50,
    uidHash: "a".repeat(64),
    idempotencyKey: "request_0000000001",
  }, secret, fakeFetch);
  const timestamp = captured.options.headers["X-Wildcard-Timestamp"];
  const expected = crypto
    .createHmac("sha256", secret)
    .update(`${timestamp}.${captured.options.body}`, "utf8")
    .digest("hex");
  assert.equal(captured.options.headers["X-Wildcard-Signature"], expected);
  const body = JSON.parse(captured.options.body);
  assert.equal(body.issuedAt, Number(timestamp) * 1000);
  assert.equal(captured.url.endsWith("/api/internal/daily"), true);
});
