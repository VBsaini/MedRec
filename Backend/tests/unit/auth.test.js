require("../env");
const { test, describe } = require("node:test");
const assert = require("node:assert/strict");
const jwt = require("jsonwebtoken");
const { signToken, requireAuth } = require("../../middleware/auth");

// Runs requireAuth with an Authorization header and reports what happened.
function run(authorization) {
  const req = { headers: authorization ? { authorization } : {} };
  const result = { nextCalled: false, status: null, body: null, req };
  const res = {
    status(code) {
      result.status = code;
      return this;
    },
    json(body) {
      result.body = body;
    },
  };
  requireAuth(req, res, () => {
    result.nextCalled = true;
  });
  return result;
}

describe("requireAuth", () => {
  test("accepts a token from signToken and sets req.userId", () => {
    const result = run(`Bearer ${signToken("64b000000000000000000001")}`);
    assert.equal(result.nextCalled, true);
    assert.equal(result.req.userId, "64b000000000000000000001");
  });

  test("tokens expire after 30 days", () => {
    const { iat, exp } = jwt.decode(signToken("u1"));
    assert.equal(exp - iat, 30 * 24 * 60 * 60);
  });

  test("rejects a missing header or a non-Bearer scheme", () => {
    for (const header of [undefined, "", "Basic abc", "Bearer", "bearer abc"]) {
      const result = run(header);
      assert.equal(result.nextCalled, false, `header ${header}`);
      assert.equal(result.status, 401);
      assert.equal(result.body.message, "Authentication required.");
    }
  });

  test("rejects tampered, foreign and expired tokens", () => {
    const good = signToken("u1");
    const tampered = good.slice(0, -2) + (good.endsWith("AA") ? "BB" : "AA");
    const foreign = jwt.sign({ userId: "u1" }, "some-other-secret");
    const expired = jwt.sign(
      { userId: "u1", exp: Math.floor(Date.now() / 1000) - 60 },
      process.env.JWT_SECRET
    );
    for (const token of [tampered, foreign, expired, "not-a-jwt"]) {
      const result = run(`Bearer ${token}`);
      assert.equal(result.nextCalled, false);
      assert.equal(result.status, 401);
      assert.equal(result.body.message, "Session expired. Please log in again.");
    }
  });
});
