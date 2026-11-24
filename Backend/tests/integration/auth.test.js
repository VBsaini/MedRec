const { test, describe, before, after } = require("node:test");
const assert = require("node:assert/strict");
const { startServer, stopServer, api, newPatient } = require("./helpers");
const User = require("../../models/User");

before(startServer);
after(stopServer);

describe("POST /api/auth/signup", () => {
  test("creates the account and returns a token and the record", async () => {
    const res = await api("POST", "/api/auth/signup", {
      json: {
        name: " Asha Rao ",
        alias: "asha_rao",
        email: " Asha@Example.TEST ",
        password: "long-enough",
      },
    });
    assert.equal(res.status, 201);
    assert.ok(res.body.token);
    assert.equal(res.body.user.name, "Asha Rao");
    assert.equal(res.body.user.email, "asha@example.test");
    assert.equal(res.body.user.password, undefined);
    assert.deepEqual(res.body.user.allergies, []);

    // Stored as a bcrypt hash, never in plain text.
    const stored = await User.findOne({ alias: "asha_rao" }).select("+password");
    assert.match(stored.password, /^\$2[aby]\$12\$/);
  });

  test("checks every field", async () => {
    const ok = { name: "A", alias: "valid_alias", email: "v@example.test", password: "12345678" };
    const cases = [
      [{ ...ok, name: "  " }, "Email, password, name, and alias are required."],
      [{ ...ok, email: undefined }, "Email, password, name, and alias are required."],
      [{ ...ok, email: "not-an-email" }, "Enter a valid email."],
      [{ ...ok, alias: "ab" }, /Alias must be 3-30 characters/],
      [{ ...ok, alias: "has space" }, /Alias must be/],
      [{ ...ok, password: "1234567" }, "Password must be at least 8 characters."],
      [{ ...ok, password: 12345678 }, "Email, password, name, and alias are required."],
      [{ ...ok, email: { $gt: "" } }, "Email, password, name, and alias are required."],
    ];
    for (const [json, message] of cases) {
      const res = await api("POST", "/api/auth/signup", { json });
      assert.equal(res.status, 400, JSON.stringify(json));
      if (message instanceof RegExp) assert.match(res.body.message, message);
      else assert.equal(res.body.message, message);
    }
    assert.equal(await User.countDocuments({ alias: "valid_alias" }), 0);
  });

  test("refuses a used email or alias", async () => {
    const existing = await newPatient();
    const email = await api("POST", "/api/auth/signup", {
      json: { name: "B", alias: "another_one", email: existing.email.toUpperCase(), password: "12345678" },
    });
    assert.equal(email.status, 409);
    assert.equal(email.body.message, "An account with this email already exists.");

    const alias = await api("POST", "/api/auth/signup", {
      json: { name: "B", alias: existing.alias, email: "fresh@example.test", password: "12345678" },
    });
    assert.equal(alias.status, 409);
    assert.equal(alias.body.message, "That alias is taken.");
  });
});

describe("POST /api/auth/login", () => {
  test("logs in with any capitalisation of the email", async () => {
    const patient = await newPatient();
    const res = await api("POST", "/api/auth/login", {
      json: { email: patient.email.toUpperCase(), password: patient.password },
    });
    assert.equal(res.status, 200);
    assert.ok(res.body.token);
    assert.equal(res.body.user._id, patient.user._id);
    assert.equal(res.body.user.password, undefined);
  });

  test("gives the same answer for a wrong password and an unknown email", async () => {
    const patient = await newPatient();
    const wrong = await api("POST", "/api/auth/login", {
      json: { email: patient.email, password: "wrong-password" },
    });
    const unknown = await api("POST", "/api/auth/login", {
      json: { email: "nobody@example.test", password: "whatever1" },
    });
    for (const res of [wrong, unknown]) {
      assert.equal(res.status, 401);
      assert.equal(res.body.message, "Invalid email or password.");
    }
  });

  test("requires both fields", async () => {
    const res = await api("POST", "/api/auth/login", { json: { email: "a@b.c" } });
    assert.equal(res.status, 400);
  });
});

describe("GET /api/auth/me", () => {
  test("returns the logged-in patient", async () => {
    const patient = await newPatient();
    const res = await api("GET", "/api/auth/me", { token: patient.token });
    assert.equal(res.status, 200);
    assert.equal(res.body.email, patient.email);
  });

  test("needs a valid token", async () => {
    assert.equal((await api("GET", "/api/auth/me")).status, 401);
    assert.equal((await api("GET", "/api/auth/me", { token: "junk" })).status, 401);
  });

  test("a token for a deleted account stops working", async () => {
    const patient = await newPatient();
    await User.deleteOne({ _id: patient.user._id });
    const res = await api("GET", "/api/auth/me", { token: patient.token });
    assert.equal(res.status, 401);
    assert.equal(res.body.message, "Account no longer exists.");
  });
});
