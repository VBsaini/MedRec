// App-wide behaviour: health check, unknown routes, malformed requests, CORS.
const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");
const { startServer, stopServer, api, newPatient } = require("./helpers");

before(startServer);
after(stopServer);

test("health check", async () => {
  const res = await api("GET", "/api/health");
  assert.equal(res.status, 200);
  assert.equal(res.body.status, "ok");
});

test("unknown API routes are JSON 404s", async () => {
  const res = await api("GET", "/api/does-not-exist");
  assert.equal(res.status, 404);
  assert.deepEqual(res.body, { message: "Not found" });
});

test("malformed JSON is a 400", async () => {
  const res = await api("POST", "/api/auth/login", {
    raw: "{not json",
    headers: { "Content-Type": "application/json" },
  });
  assert.equal(res.status, 400);
  assert.deepEqual(res.body, { message: "Invalid JSON body." });
});

test("an oversized JSON body is a 413, not a server error", async () => {
  const p = await newPatient();
  const res = await api("PATCH", "/api/me/profile", {
    token: p.token,
    json: { name: "x".repeat(200 * 1024) },
  });
  assert.equal(res.status, 413);
  assert.ok(res.body.message);
});

test("the record viewer's origin may call the API, others may not", async () => {
  const allowed = await api("GET", "/api/health", { headers: { Origin: "http://localhost:5173" } });
  assert.equal(allowed.headers.get("access-control-allow-origin"), "http://localhost:5173");

  const other = await api("GET", "/api/health", { headers: { Origin: "https://evil.example" } });
  assert.equal(other.headers.get("access-control-allow-origin"), null);
});
