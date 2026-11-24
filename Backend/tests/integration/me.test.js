const { test, describe, before, after } = require("node:test");
const assert = require("node:assert/strict");
const { startServer, stopServer, api, newPatient } = require("./helpers");
const User = require("../../models/User");
const Allergy = require("../../models/Allergy");

before(startServer);
after(stopServer);

describe("PATCH /api/me/profile", () => {
  test("saves profile fields and condition sections", async () => {
    const p = await newPatient();
    const res = await api("PATCH", "/api/me/profile", {
      token: p.token,
      json: {
        name: "Asha Rao",
        age: 34,
        gender: "Female",
        blood_group: "B+",
        height: 162,
        weight: 58.5,
        diabetic: { status: true, type: "Type 1", since: "2015-07-01" },
        heart: { status: false },
        mental_health: { status: true, details: "Anxiety" },
      },
    });
    assert.equal(res.status, 200);
    const u = res.body;
    assert.equal(u.name, "Asha Rao");
    assert.equal(u.age, 34);
    assert.equal(u.weight, 58.5);
    assert.equal(u.diabetic.type, "Type 1");
    assert.equal(u.diabetic.since, "2015-07-01T00:00:00.000Z");
    assert.equal(u.mental_health.details, "Anxiety");
    assert.equal(u.password, undefined);
  });

  test("ignores fields a patient may not set this way", async () => {
    const p = await newPatient();
    const res = await api("PATCH", "/api/me/profile", {
      token: p.token,
      json: { email: "hijack@example.test", card_Id: "STOLEN01", alias: "x", password: "p", _id: "abc" },
    });
    assert.equal(res.status, 200);
    const stored = await User.findById(p.user._id).select("+password");
    assert.equal(stored.email, p.email);
    assert.equal(stored.card_Id, undefined);
    assert.equal(stored.alias, p.alias);
    assert.notEqual(stored.password, "p");
  });

  test("an empty value clears a field, but the name cannot be blank", async () => {
    const p = await newPatient();
    await api("PATCH", "/api/me/profile", { token: p.token, json: { blood_group: "O+" } });
    const cleared = await api("PATCH", "/api/me/profile", { token: p.token, json: { blood_group: "" } });
    assert.equal(cleared.body.blood_group, undefined);

    const blank = await api("PATCH", "/api/me/profile", { token: p.token, json: { name: "   " } });
    assert.equal(blank.status, 400);
    assert.equal(blank.body.message, "Name cannot be empty.");
  });

  test("rejects bad values with a 400, not a server error", async () => {
    const p = await newPatient();
    for (const json of [{ age: 200 }, { age: "old" }, { height: -5 }, { name: { $ne: "" } }, { diabetic: { since: "someday" } }]) {
      const res = await api("PATCH", "/api/me/profile", { token: p.token, json });
      assert.equal(res.status, 400, JSON.stringify(json));
      assert.ok(res.body.message);
    }
  });
});

// Every record list: URL segment, a valid entry, the field it requires,
// and the key it appears under on the user document.
const LISTS = [
  ["allergies", { allergens: "Penicillin", reactions: "Rash", severity: "Severe" }, "allergens", "allergies"],
  ["medications", { name: "Metformin", dosage: "500mg", startDate: "2023-02-01" }, "name", "medications"],
  ["surgeries", { surgeryType: "Appendectomy", surgeryDate: "2019-08-14", hospitalName: "AIIMS" }, "surgeryDate", "surgeries"],
  ["emergency-contacts", { name: "Ravi", phone_number: "+91 98765 43210", relationship: "Brother" }, "phone_number", "emergency_contact"],
  ["family-history", { relationship: "Father", conditions: "Hypertension" }, "conditions", "family_history"],
  ["medical-history", { past_illnesses: "Childhood asthma" }, "past_illnesses", "medical_history"],
];

for (const [slug, entry, requiredField, userKey] of LISTS) {
  describe(`/api/me/${slug}`, () => {
    test("add, list, edit and delete an entry", async () => {
      const p = await newPatient();
      const created = await api("POST", `/api/me/${slug}`, { token: p.token, json: entry });
      assert.equal(created.status, 201);
      const id = created.body._id;

      const list = await api("GET", `/api/me/${slug}`, { token: p.token });
      assert.deepEqual(list.body.map((i) => i._id), [id]);

      const record = await api("GET", "/api/me", { token: p.token });
      assert.equal(record.body[userKey][0]._id, id, "shows in the whole record");

      const firstKey = Object.keys(entry)[0];
      const edited = await api("PUT", `/api/me/${slug}/${id}`, {
        token: p.token,
        json: { [firstKey]: "Edited value" },
      });
      assert.equal(edited.status, 200);
      assert.equal(edited.body[firstKey], "Edited value");

      const deleted = await api("DELETE", `/api/me/${slug}/${id}`, { token: p.token });
      assert.equal(deleted.status, 200);
      assert.deepEqual((await api("GET", `/api/me/${slug}`, { token: p.token })).body, []);
    });

    test(`requires ${requiredField}`, async () => {
      const p = await newPatient();
      const res = await api("POST", `/api/me/${slug}`, {
        token: p.token,
        json: { ...entry, [requiredField]: "" },
      });
      assert.equal(res.status, 400);
      assert.match(res.body.message, new RegExp(requiredField));
      assert.deepEqual((await api("GET", `/api/me/${slug}`, { token: p.token })).body, []);
    });
  });
}

describe("record lists belong to one patient", () => {
  test("another patient cannot read, edit or delete my entries", async () => {
    const owner = await newPatient();
    const other = await newPatient();
    const { body } = await api("POST", "/api/me/allergies", {
      token: owner.token,
      json: { allergens: "Peanuts", reactions: "Hives", severity: "Mild" },
    });

    assert.deepEqual((await api("GET", "/api/me/allergies", { token: other.token })).body, []);
    const edit = await api("PUT", `/api/me/allergies/${body._id}`, {
      token: other.token,
      json: { allergens: "Changed" },
    });
    assert.equal(edit.status, 404);
    const del = await api("DELETE", `/api/me/allergies/${body._id}`, { token: other.token });
    assert.equal(del.status, 404);

    assert.equal((await Allergy.findById(body._id)).allergens, "Peanuts");
  });

  test("surgeries are labelled with the patient's name", async () => {
    const p = await newPatient({ name: "Meera Iyer" });
    const res = await api("POST", "/api/me/surgeries", {
      token: p.token,
      json: { surgeryType: "Tonsillectomy", surgeryDate: "2001-01-01" },
    });
    assert.equal(res.body.patientName, "Meera Iyer");
    assert.match(res.body.recordNumber, /^MR-/);
  });

  test("an entry shared by older seed data survives one patient deleting it", async () => {
    const a = await newPatient();
    const b = await newPatient();
    const { body } = await api("POST", "/api/me/allergies", {
      token: a.token,
      json: { allergens: "Dust", reactions: "Sneezing", severity: "Mild" },
    });
    await User.updateOne({ _id: b.user._id }, { $push: { allergies: body._id } });

    await api("DELETE", `/api/me/allergies/${body._id}`, { token: a.token });
    assert.ok(await Allergy.findById(body._id), "still there for patient b");
    await api("DELETE", `/api/me/allergies/${body._id}`, { token: b.token });
    assert.equal(await Allergy.findById(body._id), null, "gone once unlinked");
  });

  test("unknown lists and malformed ids are 404s", async () => {
    const p = await newPatient();
    assert.equal((await api("GET", "/api/me/passwords", { token: p.token })).status, 404);
    assert.equal((await api("GET", "/api/me/__proto__", { token: p.token })).status, 404);
    assert.equal((await api("PUT", "/api/me/allergies/not-an-id", { token: p.token, json: {} })).status, 404);
  });

  test("every /api/me route needs a login", async () => {
    for (const [method, path] of [["GET", "/api/me"], ["PATCH", "/api/me/profile"], ["GET", "/api/me/allergies"], ["PUT", "/api/me/card"], ["GET", "/api/me/visitors"]]) {
      const json = method === "GET" ? undefined : {};
      assert.equal((await api(method, path, { json })).status, 401, `${method} ${path}`);
    }
  });
});
