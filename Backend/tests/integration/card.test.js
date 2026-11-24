// Linking an RFID card, the public lookup a card tap triggers, and the
// visitor log the patient sees.
const { test, describe, before, after } = require("node:test");
const assert = require("node:assert/strict");
const { startServer, stopServer, api, newPatient, formOf, PNG } = require("./helpers");

before(startServer);
after(stopServer);

describe("PUT /api/me/card", () => {
  test("links a card in the form the reader prints", async () => {
    const p = await newPatient();
    const res = await api("PUT", "/api/me/card", { token: p.token, json: { card_Id: "04:a1:b2:c3" } });
    assert.equal(res.status, 200);
    assert.deepEqual(res.body, { card_Id: "04A1B2C3" });
  });

  test("a card can only belong to one patient", async () => {
    const a = await newPatient();
    const b = await newPatient();
    await api("PUT", "/api/me/card", { token: a.token, json: { card_Id: "CAFE0001" } });
    const res = await api("PUT", "/api/me/card", { token: b.token, json: { card_Id: "cafe-0001" } });
    assert.equal(res.status, 409);
    assert.equal(res.body.message, "That card is already linked to another account.");

    // Re-saving your own card is fine.
    const again = await api("PUT", "/api/me/card", { token: a.token, json: { card_Id: "CAFE0001" } });
    assert.equal(again.status, 200);
  });

  test("rejects values that are not card UIDs", async () => {
    const p = await newPatient();
    for (const card_Id of ["abc", "04A1/../x", 1234, ["04A1B2C3"]]) {
      const res = await api("PUT", "/api/me/card", { token: p.token, json: { card_Id } });
      assert.equal(res.status, 400, JSON.stringify(card_Id));
    }
  });

  test("unlinking frees the card for someone else", async () => {
    const a = await newPatient();
    const b = await newPatient();
    await api("PUT", "/api/me/card", { token: a.token, json: { card_Id: "BEEF0002" } });
    const unlink = await api("PUT", "/api/me/card", { token: a.token, json: { card_Id: "" } });
    assert.deepEqual(unlink.body, { card_Id: null });
    assert.equal((await api("GET", "/api/records/user/card/BEEF0002")).status, 404);

    const relink = await api("PUT", "/api/me/card", { token: b.token, json: { card_Id: "BEEF0002" } });
    assert.equal(relink.status, 200);
  });
});

describe("GET /api/records/user/card/:cardId (public)", () => {
  test("shows the emergency record without private details", async () => {
    const p = await newPatient({ name: "Kabir Shah" });
    await api("PATCH", "/api/me/profile", { token: p.token, json: { blood_group: "AB-", age: 52 } });
    await api("POST", "/api/me/allergies", {
      token: p.token,
      json: { allergens: "Sulfa drugs", reactions: "Anaphylaxis", severity: "Severe" },
    });
    await api("POST", "/api/me/emergency-contacts", {
      token: p.token,
      json: { name: "Nisha Shah", phone_number: "+91 90000 00001" },
    });
    await api("POST", "/api/reports", {
      token: p.token,
      form: formOf({ title: "Private scan" }, [["scan.png", "image/png", PNG]]),
    });
    await api("PUT", "/api/me/card", { token: p.token, json: { card_Id: "D00D0003" } });

    const res = await api("GET", "/api/records/user/card/D00D0003");
    assert.equal(res.status, 200);
    assert.equal(res.body.name, "Kabir Shah");
    assert.equal(res.body.blood_group, "AB-");
    assert.equal(res.body.allergies[0].allergens, "Sulfa drugs");
    assert.equal(res.body.emergency_contact[0].phone_number, "+91 90000 00001");

    const text = JSON.stringify(res.body);
    assert.equal(res.body.email, undefined);
    assert.equal(res.body.password, undefined);
    assert.ok(!text.includes(p.email), "no email anywhere");
    assert.ok(!text.includes("Private scan"), "no uploaded reports");
  });

  test("an unknown card is a 404", async () => {
    const res = await api("GET", "/api/records/user/card/NOSUCHCARD");
    assert.equal(res.status, 404);
    assert.equal(res.body.message, "User not found");
  });
});

describe("visitor log", () => {
  test("a logged visit shows only in the card owner's history", async () => {
    const owner = await newPatient();
    const other = await newPatient();
    await api("PUT", "/api/me/card", { token: owner.token, json: { card_Id: "F00D0004" } });

    const visit = await api("POST", "/api/records/visitor", {
      json: { name: " Dr Mehta ", purpose: "Emergency room", card_Id: "F00D0004" },
    });
    assert.equal(visit.status, 201);

    const history = await api("GET", "/api/me/visitors", { token: owner.token });
    assert.equal(history.body.length, 1);
    assert.equal(history.body[0].name, "Dr Mehta");
    assert.equal(history.body[0].purpose, "Emergency room");
    assert.ok(history.body[0].visitDate);

    assert.deepEqual((await api("GET", "/api/me/visitors", { token: other.token })).body, []);
  });

  test("needs a name and a known card", async () => {
    const missing = await api("POST", "/api/records/visitor", { json: { card_Id: "F00D0004" } });
    assert.equal(missing.status, 400);
    const unknown = await api("POST", "/api/records/visitor", { json: { name: "X", card_Id: "NOPE0000" } });
    assert.equal(unknown.status, 404);
    const injected = await api("POST", "/api/records/visitor", { json: { name: "X", card_Id: { $ne: "" } } });
    assert.equal(injected.status, 400);
  });
});
