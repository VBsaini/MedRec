require("../env");
const { test, describe } = require("node:test");
const assert = require("node:assert/strict");
const { readPath, applyFields, normalizeCardId } = require("../../services/fields");
const { HttpError } = require("../../middleware/errors");
const User = require("../../models/User");

describe("readPath", () => {
  test("reads top-level and nested keys", () => {
    const body = { name: "A", heart: { status: true } };
    assert.equal(readPath(body, "name"), "A");
    assert.equal(readPath(body, "heart.status"), true);
    assert.equal(readPath(body, "heart.details"), undefined);
    assert.equal(readPath(body, "diabetic.type"), undefined);
  });

  test("does not walk into non-objects or inherited properties", () => {
    assert.equal(readPath({ heart: "yes" }, "heart.status"), undefined);
    assert.equal(readPath({ heart: null }, "heart.status"), undefined);
    assert.equal(readPath({}, "constructor"), undefined);
    assert.equal(readPath(JSON.parse('{"__proto__": {"x": 1}}'), "x"), undefined);
  });
});

describe("applyFields", () => {
  const FIELDS = ["name", "age", "heart.status", "heart.details"];

  test("copies whitelisted values and trims strings", () => {
    const user = new User();
    applyFields(user, { name: "  Asha  ", age: 31, heart: { status: true } }, FIELDS);
    assert.equal(user.name, "Asha");
    assert.equal(user.age, 31);
    assert.equal(user.heart.status, true);
  });

  test("ignores fields that are not whitelisted", () => {
    const user = new User();
    applyFields(user, { name: "A", email: "x@y.z", card_Id: "ABCD", password: "p" }, FIELDS);
    assert.equal(user.email, undefined);
    assert.equal(user.card_Id, undefined);
    assert.equal(user.password, undefined);
  });

  test('"" and null clear a field, a missing key leaves it alone', () => {
    const user = new User({ name: "A", age: 30, heart: { details: "x" } });
    applyFields(user, { name: "", age: null }, FIELDS);
    assert.equal(user.name, undefined);
    assert.equal(user.age, undefined);
    assert.equal(user.heart.details, "x");
  });

  test("rejects objects and arrays (no query operators)", () => {
    for (const value of [{ $gt: "" }, ["a"], { nested: 1 }]) {
      assert.throws(
        () => applyFields(new User(), { name: value }, FIELDS),
        (err) => err instanceof HttpError && err.status === 400 && /name/.test(err.message)
      );
    }
  });
});

describe("normalizeCardId", () => {
  test("strips separators and upper-cases reader output", () => {
    assert.equal(normalizeCardId("04:a1:b2:c3"), "04A1B2C3");
    assert.equal(normalizeCardId(" 04 a1-b2 c3 "), "04A1B2C3");
    assert.equal(normalizeCardId("med001"), "MED001");
  });

  test("rejects values that cannot be a card UID", () => {
    for (const bad of ["", "abc", "04A1/../x", "ü1234", "A".repeat(33), 1234, null, {}]) {
      assert.throws(
        () => normalizeCardId(bad),
        (err) => err instanceof HttpError && err.status === 400,
        `value ${JSON.stringify(bad)}`
      );
    }
  });
});
