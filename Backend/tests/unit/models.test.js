// Schema rules, checked with validateSync: no database needed.
require("../env");
const { test, describe } = require("node:test");
const assert = require("node:assert/strict");
const mongoose = require("mongoose");
const User = require("../../models/User");
const Report = require("../../models/Report");
const Surgery = require("../../models/Surgery");
const Allergy = require("../../models/Allergy");
const EmergencyContact = require("../../models/EmergencyContact");
const { populateRecord } = require("../../services/record");

const errorsOf = (doc) => Object.keys(doc.validateSync()?.errors || {}).sort();
const userId = new mongoose.Types.ObjectId();

describe("User", () => {
  test("requires email, password and alias", () => {
    assert.deepEqual(errorsOf(new User({})), ["alias", "email", "password"]);
  });

  test("never selects the password by default", () => {
    assert.equal(User.schema.path("password").options.select, false);
  });

  test("rejects impossible ages and negative sizes", () => {
    const base = { email: "a@b.c", password: "x", alias: "abc" };
    assert.deepEqual(errorsOf(new User({ ...base, age: 151 })), ["age"]);
    assert.deepEqual(errorsOf(new User({ ...base, height: -1, weight: -1 })), [
      "height",
      "weight",
    ]);
    assert.deepEqual(errorsOf(new User({ ...base, age: 0 })), []);
  });

  test("card_Id is unique but optional", () => {
    const options = User.schema.path("card_Id").options;
    assert.equal(options.unique, true);
    assert.equal(options.sparse, true);
  });
});

describe("Report", () => {
  test("requires a title and an owner, defaults the category", () => {
    assert.deepEqual(errorsOf(new Report({})), ["title", "user"]);
    const report = new Report({ user: userId, title: "  CBC  " });
    assert.equal(report.title, "CBC");
    assert.equal(report.category, "other");
    assert.ok(report.date instanceof Date);
  });

  test("only accepts known categories", () => {
    for (const category of Report.CATEGORIES) {
      assert.deepEqual(errorsOf(new Report({ user: userId, title: "x", category })), []);
    }
    assert.deepEqual(
      errorsOf(new Report({ user: userId, title: "x", category: "selfie" })),
      ["category"]
    );
  });

  test("the on-disk file name is never sent to clients", () => {
    const report = new Report({
      user: userId,
      title: "x",
      files: [{ storedName: "abc123.jpg", originalName: "scan.jpg", mimeType: "image/jpeg", size: 10 }],
    });
    const json = JSON.parse(JSON.stringify(report));
    assert.equal(json.files[0].storedName, undefined);
    assert.equal(json.files[0].originalName, "scan.jpg");
    assert.ok(json.files[0]._id);
  });

  test("limits title and description length", () => {
    const doc = new Report({
      user: userId,
      title: "t".repeat(201),
      description: "d".repeat(5001),
    });
    assert.deepEqual(errorsOf(doc), ["description", "title"]);
  });
});

describe("Surgery", () => {
  test("requires type and date, generates a record number", () => {
    assert.deepEqual(errorsOf(new Surgery({})), ["surgeryDate", "surgeryType"]);
    const a = new Surgery({ surgeryType: "Appendectomy", surgeryDate: "2020-01-02" });
    const b = new Surgery({ surgeryType: "Appendectomy", surgeryDate: "2020-01-02" });
    assert.match(a.recordNumber, /^MR-[0-9A-F]{12}$/);
    assert.notEqual(a.recordNumber, b.recordNumber);
  });
});

test("record list entries have their required fields", () => {
  assert.deepEqual(errorsOf(new Allergy({})), ["allergens", "reactions", "severity"]);
  assert.deepEqual(errorsOf(new EmergencyContact({})), ["name", "phone_number"]);
});

test("populateRecord populates every linked list, including legacy ones", () => {
  const paths = [];
  const query = { populate: (p) => (paths.push(p), query) };
  assert.equal(populateRecord(query), query);
  assert.deepEqual(paths.sort(), [
    "allergies",
    "emergency_contact",
    "family_history",
    "heart.medications",
    "heart.surgeries",
    "medical_history",
    "medications",
    "mental_health.medications",
    "surgeries",
  ]);
});
